import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../api/client.dart';
import '../../api/permisos.dart';
import '../../api/camara_helper.dart';
import '../../api/recuperacion_guardia.dart';
import '../../theme/app_theme.dart';

/// Flujo del guardia: escanear → revisar → registrar.
/// Resistente a reinicios de Android (largeHeap + retrieveLostData).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum _Paso { scan, review, done }

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  final _codigoCtrl = TextEditingController();
  final _placaCtrl  = TextEditingController(); // placa que el guardia digita

  _Paso _paso = _Paso.scan;
  bool _procesando = false;
  String? _error;

  Map<String, dynamic>? _visita;
  String _direccion = 'entrada';
  bool _cuentaBloqueada = false;
  bool _estaAdentro = false;
  String? _mensajeValidacion;

  // Fotos como archivos (no base64)
  File? _fotoId;
  File? _fotoPlaca;
  File? _fotoNumero;


  String _resultado = '';

  @override
  void initState() {
    super.initState();
    _pedirPermisosCamara();
    // Si Android mató el proceso mientras se tomaba una foto, restaurar todo
    _restaurarSiHuboReinicio();
  }

  /// Restaura el flujo del guardia si Android mató el proceso al abrir la cámara.
  /// Recupera el estado del registro (visita, paso, dirección) Y la foto perdida.
  Future<void> _restaurarSiHuboReinicio() async {
    final estado = await RecuperacionGuardia.leerEstado();
    if (estado == null) return; // no había registro en curso

    // Recuperar la foto que Android perdió
    final rutaFoto = await RecuperacionGuardia.recuperarFotoPerdida();
    final cual = await RecuperacionGuardia.leerFotoEnCurso();

    if (!mounted) return;
    setState(() {
      // Restaurar el paso 2 con los datos de la visita
      _visita = (estado['visita'] as Map?)?.cast<String, dynamic>();
      _direccion = estado['direccion']?.toString() ?? 'entrada';
      _cuentaBloqueada = estado['cuenta_bloqueada'] == true;
      _estaAdentro = estado['esta_adentro'] == true;
      _mensajeValidacion = estado['mensaje']?.toString();
      // Restaurar fotos ya tomadas antes del reinicio
      if (estado['foto_id'] != null) _fotoId = File(estado['foto_id']);
      if (estado['foto_placa'] != null) _fotoPlaca = File(estado['foto_placa']);
      if (estado['foto_numero'] != null) _fotoNumero = File(estado['foto_numero']);
      // Asignar la foto recién recuperada
      if (rutaFoto != null && cual != null) {
        switch (cual) {
          case 'id':     _fotoId = File(rutaFoto); break;
          case 'placa':  _fotoPlaca = File(rutaFoto); break;
          case 'numero': _fotoNumero = File(rutaFoto); break;
        }
      }
      _paso = _Paso.review;
    });
    // Detener el escáner porque ya estamos en review
    await _ctrl.stop();
  }

  /// Persiste el estado actual del registro para sobrevivir un reinicio.
  Future<void> _persistirEstado() async {
    if (_visita == null) return;
    await RecuperacionGuardia.guardarEstado({
      'visita': _visita,
      'direccion': _direccion,
      'cuenta_bloqueada': _cuentaBloqueada,
      'esta_adentro': _estaAdentro,
      'mensaje': _mensajeValidacion,
      'foto_id': _fotoId?.path,
      'foto_placa': _fotoPlaca?.path,
      'foto_numero': _fotoNumero?.path,
    });
  }

  Future<void> _pedirPermisosCamara() async {
    final concedido = await PermisosService.pedirCamara();
    if (!concedido && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Permiso de cámara requerido'),
          content: const Text(
            'El escáner necesita acceso a la cámara para leer los códigos QR '
            'de los visitantes. Por favor habilitalo en Ajustes.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); PermisosService.abrirConfiguracion(); },
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  // ─── Paso 1: Validar QR ───────────────────────────────────────────────────
  Future<void> _onDeteccion(BarcodeCapture capture) async {
    if (_procesando || _paso != _Paso.scan) return;
    final qrData = capture.barcodes.firstOrNull?.rawValue;
    if (qrData == null) return;
    await _ctrl.stop();
    await _validar(qrData);
  }

  Future<void> _validar(String token) async {
    setState(() { _procesando = true; _error = null; });
    try {
      final res = await ApiClient.post('/visitas/qr/validar', {'token': token.trim()});
      final data = res as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _visita = data['visita'] as Map<String, dynamic>;
        _direccion = data['direccion_sugerida']?.toString() ?? 'entrada';
        _cuentaBloqueada = data['cuenta_bloqueada'] == true;
        _estaAdentro = data['adentro'] == true;
        _mensajeValidacion = data['mensaje']?.toString();
        _fotoId = null; _fotoPlaca = null; _fotoNumero = null;
        _paso = _Paso.review;
      });
      await _ctrl.stop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _ctrl.start();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo validar el código');
      _ctrl.start();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ─── Paso 2: Tomar fotos ──────────────────────────────────────────────────
  Future<void> _tomarFoto(String cual) async {
    // ANTES de abrir la cámara, persistir el estado completo en disco.
    // Si Android mata el proceso, al reabrir la app se restaura todo.
    await _persistirEstado();
    await RecuperacionGuardia.marcarFotoEnCurso(cual);

    final archivo = await CamaraHelper.capturar(
      fuente: ImageSource.camera,
      quality: 50,
      maxSize: 1024,
    );

    if (archivo == null || !mounted) return;

    setState(() {
      switch (cual) {
        case 'id':     _fotoId = archivo; break;
        case 'placa':  _fotoPlaca = archivo; break;
        case 'numero': _fotoNumero = archivo; break;
      }
    });
    // Actualizar el estado guardado con la foto recién tomada
    await _persistirEstado();
  }

  // ─── Paso 3: Registrar acceso ─────────────────────────────────────────────
  bool get _puedeRegistrar {
    if (_direccion == 'salida') return true;
    if (_fotoId == null) return false;
    if (_visita?['en_vehiculo'] == true) {
      if (_fotoPlaca == null) return false;
      if (_placaCtrl.text.trim().isEmpty) return false; // placa obligatoria
    }
    return true;
  }

  Future<void> _registrar() async {
    setState(() { _procesando = true; _error = null; });
    try {
      await ApiClient.registrarAcceso(
        visita_id: _visita?['uuid_publico'] ?? _visita?['id'].toString(),
        direccion: _direccion,
        placaVehiculo: _placaCtrl.text.trim(),
        fotoId: _fotoId,
        fotoPlaca: _fotoPlaca,
        fotoNumero: _fotoNumero,
      );
      await RecuperacionGuardia.limpiar();
      if (!mounted) return;
      setState(() {
        _resultado = _direccion == 'entrada' ? 'Entrada registrada' : 'Salida registrada';
        _paso = _Paso.done;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo registrar el acceso');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _reiniciar() {
    RecuperacionGuardia.limpiar(); // descartar registro en curso
    setState(() {
      _paso = _Paso.scan;
      _visita = null; _error = null;
      _fotoId = null; _fotoPlaca = null; _fotoNumero = null;
      _codigoCtrl.clear();
      _placaCtrl.clear();
    });
    _ctrl.start();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    switch (_paso) {
      case _Paso.scan:   return _buildScan();
      case _Paso.review: return _buildReview();
      case _Paso.done:   return _buildDone();
    }
  }

  Widget _buildScan() {
    return Stack(children: [
      MobileScanner(controller: _ctrl, onDetect: _onDeteccion),
      Center(child: Container(
        width: 240, height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.naranja, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      )),
      if (_procesando)
        Container(color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: AppColors.naranja))),
      if (_error != null)
        Positioned(top: 20, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          )),
      Positioned(bottom: 24, left: 16, right: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _codigoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Código de delivery (manual)',
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            )),
            ElevatedButton(
              onPressed: _procesando ? null : () => _validar(_codigoCtrl.text),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Validar'),
            ),
          ]),
        )),
    ]);
  }

  Widget _buildReview() {
    final v = _visita!;
    final nombre   = v['nombre_visitante']?.toString() ?? '';
    final tipo     = v['tipo']?.toString() ?? '';
    final docId    = v['documento_id']?.toString();
    final empresa  = v['empresa']?.toString();
    final placa    = v['placa_vehiculo']?.toString();
    final enVehiculo = v['en_vehiculo'] == true;
    final generadaPor = v['generada_por']?.toString();

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_estaAdentro && _mensajeValidacion != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.azul.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.azul.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.azul, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_mensajeValidacion!, style: const TextStyle(color: AppColors.azul, fontSize: 13))),
          ]),
        ),
      if (_cuentaBloqueada)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.warning_amber, color: AppColors.rojo, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(
              'CUENTA BLOQUEADA POR MORA. Verificá con administración antes de dar acceso.',
              style: TextStyle(color: AppColors.rojo, fontSize: 13, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: AppColors.azul.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(tipo == 'repartidor' ? Icons.delivery_dining : Icons.person, color: AppColors.azul, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
              Text('Tipo: $tipo', style: const TextStyle(fontSize: 13, color: AppColors.gris)),
            ])),
          ]),
          const Divider(height: 24),
          if (docId != null && docId.isNotEmpty) _DatoFila('Identidad', docId),
          if (empresa != null && empresa.isNotEmpty) _DatoFila('Empresa', empresa),
          if (enVehiculo) _DatoFila('Placa', placa ?? 'No registrada'),
          if (generadaPor != null && generadaPor.isNotEmpty) _DatoFila('Autorizado por', generadaPor),
        ]),
      )),
      const SizedBox(height: 14),
      Row(children: [
        for (final d in [('entrada', 'Entrada', Icons.login), ('salida', 'Salida', Icons.logout)])
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _direccion = d.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _direccion == d.$1 ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _direccion == d.$1 ? AppColors.azul : AppColors.borde),
                ),
                child: Column(children: [
                  Icon(d.$3, color: _direccion == d.$1 ? Colors.white : AppColors.gris),
                  const SizedBox(height: 4),
                  Text(d.$2, style: TextStyle(fontWeight: FontWeight.w700, color: _direccion == d.$1 ? Colors.white : AppColors.gris)),
                ]),
              ),
            ),
          )),
      ]),
      const SizedBox(height: 14),
      if (_direccion == 'entrada') ...[
        const Text('Fotos de registro', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
        const SizedBox(height: 8),
        _FotoBoton(label: 'Foto de identidad *', tomada: _fotoId != null, onTap: () => _tomarFoto('id')),
        if (_visita?['en_vehiculo'] == true) ...[
          _FotoBoton(label: 'Foto de la placa *', tomada: _fotoPlaca != null, onTap: () => _tomarFoto('placa')),
          const SizedBox(height: 8),
          TextField(
            controller: _placaCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}), // rebuild para actualizar _puedeRegistrar
            decoration: const InputDecoration(
              labelText: 'Número de placa del vehículo *',
              prefixIcon: Icon(Icons.directions_car_outlined),
              hintText: 'Ej. AAA-1234',
            ),
          ),
        ],
        _FotoBoton(label: 'Foto del número asignado (opcional)', tomada: _fotoNumero != null, onTap: () => _tomarFoto('numero')),
        const SizedBox(height: 6),
        const Text('* obligatorias para dar acceso', style: TextStyle(fontSize: 11, color: AppColors.gris)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _procesando ? null : _reiniciar,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Cancelar'),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: (_procesando || !_puedeRegistrar) ? null : _registrar,
          style: ElevatedButton.styleFrom(backgroundColor: _direccion == 'entrada' ? AppColors.verde : AppColors.azul),
          child: _procesando
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_direccion == 'entrada' ? 'Registrar ENTRADA' : 'Registrar SALIDA'),
        )),
      ]),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildDone() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.verde, size: 72),
        ),
        const SizedBox(height: 20),
        Text(_resultado, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.verde)),
        const SizedBox(height: 6),
        Text(_visita?['nombre_visitante']?.toString() ?? '', style: const TextStyle(fontSize: 16, color: AppColors.azul)),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _reiniciar,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear otro'),
        )),
      ]),
    ));
  }
}

class _DatoFila extends StatelessWidget {
  final String label;
  final String valor;
  const _DatoFila(this.label, this.valor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.gris))),
      Expanded(child: Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul))),
    ]),
  );
}

class _FotoBoton extends StatelessWidget {
  final String label;
  final bool tomada;
  final VoidCallback onTap;
  const _FotoBoton({required this.label, required this.tomada, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: (tomada ? AppColors.verde : AppColors.naranja).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(tomada ? Icons.check : Icons.camera_alt,
            color: tomada ? AppColors.verde : AppColors.naranja, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.azul)),
      trailing: Text(tomada ? 'Tomada ✓' : 'Tomar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tomada ? AppColors.verde : AppColors.naranja)),
      onTap: onTap,
    ),
  );
}
