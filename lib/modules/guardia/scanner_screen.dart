import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../api/client.dart';
import '../../api/permisos.dart';
import '../../theme/app_theme.dart';

/// Flujo del guardia (igual que la web): escanear → revisar → registrar.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum _Paso { scan, review, done }

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  final _codigoCtrl = TextEditingController();

  _Paso _paso = _Paso.scan;
  bool _procesando = false;
  String? _error;

  // Datos de la visita validada
  Map<String, dynamic>? _visita;
  String _direccion = 'entrada';
  bool _cuentaBloqueada = false;
  bool _estaAdentro = false;
  String? _mensajeValidacion;

  // Fotos (base64)
  String? _fotoId;
  String? _fotoPlaca;
  String? _fotoNumero;

  // Resultado final
  String _resultado = '';

  @override
  void initState() {
    super.initState();
    _pedirPermisosCamara();
  }

  Future<void> _pedirPermisosCamara() async {
    final concedido = await PermisosService.pedirCamara();
    if (!concedido && mounted) {
      // Si el usuario negó el permiso, mostrar diálogo explicativo
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                PermisosService.abrirConfiguracion();
              },
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
  // ─── Paso 1: Validar QR o código ────────────────────────────────────────────
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
      setState(() {
        _visita = data['visita'] as Map<String, dynamic>;
        _direccion = data['direccion_sugerida']?.toString() ?? 'entrada';
        _cuentaBloqueada = data['cuenta_bloqueada'] == true;
        _estaAdentro = data['adentro'] == true;
        _mensajeValidacion = data['mensaje']?.toString();
        _fotoId = null; _fotoPlaca = null; _fotoNumero = null;
        _paso = _Paso.review;
      });
      // Parar completamente el controller para liberar la cámara.
      // Sin esto, image_picker choca con MobileScanner al tomar fotos.
      await _ctrl.stop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      _ctrl.start();
    } catch (_) {
      setState(() => _error = 'No se pudo validar el código');
      _ctrl.start();
    } finally {
      setState(() => _procesando = false);
    }
  }

  // ─── Paso 2: Tomar fotos ────────────────────────────────────────────────────
  Future<void> _tomarFoto(String cual) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 40,
        maxWidth: 800,
        maxHeight: 800);
    if (picked == null || !mounted) return;
    final b64 = base64Encode(await File(picked.path).readAsBytes());
    if (!mounted) return;
    setState(() {
      switch (cual) {
        case 'id':     _fotoId = b64; break;
        case 'placa':  _fotoPlaca = b64; break;
        case 'numero': _fotoNumero = b64; break;
      }
    });
  }

  // ─── Paso 3: Registrar el acceso ────────────────────────────────────────────
  bool get _puedeRegistrar {
    if (_direccion == 'salida') return true;
    if (_fotoId == null) return false;
    if (_visita?['en_vehiculo'] == true && _fotoPlaca == null) return false;
    return true;
  }

  Future<void> _registrar() async {
    setState(() { _procesando = true; _error = null; });
    try {
      await ApiClient.post('/visitas/accesos/visita', {
        'visita_id': _visita?['uuid_publico'] ?? _visita?['id'].toString(),
        'direccion': _direccion,
        'acceso_id': 1,
        if (_fotoId != null) 'foto_identidad': _fotoId,
        if (_fotoPlaca != null) 'foto_placa': _fotoPlaca,
        if (_fotoNumero != null) 'foto_numero_asignado': _fotoNumero,
      });
      setState(() {
        _resultado = _direccion == 'entrada' ? 'Entrada registrada' : 'Salida registrada';
        _paso = _Paso.done;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo registrar el acceso');
    } finally {
      setState(() => _procesando = false);
    }
  }

  void _reiniciar() {
    setState(() {
      _paso = _Paso.scan;
      _visita = null; _error = null;
      _fotoId = null; _fotoPlaca = null; _fotoNumero = null;
      _codigoCtrl.clear();
    });
    _ctrl.start();
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────
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
      // Marco
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
      // Error
      if (_error != null)
        Positioned(top: 20, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.rojo, borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
          )),
      // Entrada manual (código de delivery)
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
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            )),
            ElevatedButton(
              onPressed: _procesando ? null : () => _validar(_codigoCtrl.text),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
      // Aviso de "está adentro"
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
            Expanded(child: Text(_mensajeValidacion!,
                style: const TextStyle(color: AppColors.azul, fontSize: 13))),
          ]),
        ),

      // Advertencia de cuenta bloqueada
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
              'La cuenta de esta casa está BLOQUEADA POR MORA. Verificá con administración antes de dar acceso.',
              style: TextStyle(color: AppColors.rojo, fontSize: 13, fontWeight: FontWeight.w600),
            )),
          ]),
        ),

      // Datos de la visita
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.azul.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                tipo == 'repartidor' ? Icons.delivery_dining : Icons.person,
                color: AppColors.azul, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
              Text('Tipo: $tipo', style: const TextStyle(fontSize: 13, color: AppColors.gris)),
            ])),
          ]),
          const Divider(height: 24),
          if (docId != null && docId.isNotEmpty) _DatoFila('Identidad', docId),
          if (empresa != null && empresa.isNotEmpty) _DatoFila('Empresa', empresa),
          if (enVehiculo) _DatoFila('Placa', placa ?? 'No registrada'),
          if (generadaPor != null && generadaPor.isNotEmpty)
            _DatoFila('Autorizado por', generadaPor),
        ]),
      )),
      const SizedBox(height: 14),

      // Dirección: entrada / salida
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
                  border: Border.all(
                      color: _direccion == d.$1 ? AppColors.azul : AppColors.borde),
                ),
                child: Column(children: [
                  Icon(d.$3, color: _direccion == d.$1 ? Colors.white : AppColors.gris),
                  const SizedBox(height: 4),
                  Text(d.$2, style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _direccion == d.$1 ? Colors.white : AppColors.gris,
                  )),
                ]),
              ),
            ),
          )),
      ]),
      const SizedBox(height: 14),

      // Fotos (solo para entrada)
      if (_direccion == 'entrada') ...[
        const Text('Fotos de registro',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
        const SizedBox(height: 8),
        _FotoBoton(
          label: 'Foto de identidad *',
          tomada: _fotoId != null,
          onTap: () => _tomarFoto('id'),
        ),
        if (_visita?['en_vehiculo'] == true)
          _FotoBoton(
            label: 'Foto de la placa *',
            tomada: _fotoPlaca != null,
            onTap: () => _tomarFoto('placa'),
          ),
        _FotoBoton(
          label: 'Foto del número asignado (opcional)',
          tomada: _fotoNumero != null,
          onTap: () => _tomarFoto('numero'),
        ),
        const SizedBox(height: 6),
        const Text('* obligatorias para dar acceso',
            style: TextStyle(fontSize: 11, color: AppColors.gris)),
      ],

      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
      ],
      const SizedBox(height: 18),

      // Botones
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _procesando ? null : _reiniciar,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancelar'),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: (_procesando || !_puedeRegistrar) ? null : _registrar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _direccion == 'entrada' ? AppColors.verde : AppColors.azul,
          ),
          child: _procesando
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.verde, size: 72),
        ),
        const SizedBox(height: 20),
        Text(_resultado, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.verde)),
        const SizedBox(height: 6),
        Text(_visita?['nombre_visitante']?.toString() ?? '',
            style: const TextStyle(fontSize: 16, color: AppColors.azul)),
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
      SizedBox(width: 120, child: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.gris))),
      Expanded(child: Text(valor, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul))),
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
          style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13,
            color: tomada ? AppColors.verde : AppColors.naranja,
          )),
      onTap: onTap,
    ),
  );
}
