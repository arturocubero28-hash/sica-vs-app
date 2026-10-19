import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/client.dart';
import '../../api/camara_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_dialog.dart';

/// Día 69 — Accesos que el guardia registra SIN escanear un QR.
///
/// Dos caminos, con la misma evidencia detrás:
///
///   Residente — llega sin batería en el teléfono. Dice su casa y su código
///   de 6 dígitos; el guardia lo busca, ve su foto y su nombre, le pide la
///   identificación, compara y abre.
///
///   Proveedor — camión de agua, gas o refrescos. Antes esto era una
///   apertura manual anónima: quedaba registrado que el guardia abrió, pero
///   no quién entró ni con autorización de quién.
///
/// Lo que estos flujos aportan NO es impedir que el guardia abra — ya puede
/// hacerlo con el botón "Abrir". Es dejar rastro: cada apertura queda atada
/// a una persona concreta, con foto de su identificación, el guardia que la
/// hizo y la tranca que se abrió.
class DarAccesoScreen extends StatefulWidget {
  const DarAccesoScreen({super.key});

  @override
  State<DarAccesoScreen> createState() => _DarAccesoScreenState();
}

class _DarAccesoScreenState extends State<DarAccesoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _trancas = [];
  bool _cargandoTrancas = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargarTrancas();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarTrancas() async {
    try {
      final r = await GuardiaAccesoApi.misTrancas();
      if (!mounted) return;
      setState(() {
        _trancas = (r['trancas'] as List?) ?? [];
        _cargandoTrancas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoTrancas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.azul,
            indicatorColor: AppColors.naranja,
            tabs: const [
              Tab(icon: Icon(Icons.badge_outlined), text: 'Residente'),
              Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Proveedor'),
            ],
          ),
        ),
        Expanded(
          child: _cargandoTrancas
              ? const Center(child: CircularProgressIndicator())
              : _trancas.isEmpty
                  ? _SinTrancas(onReintentar: _cargarTrancas)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _FormResidente(trancas: _trancas),
                        _FormProveedor(trancas: _trancas),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _SinTrancas extends StatelessWidget {
  final VoidCallback onReintentar;
  const _SinTrancas({required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off_outlined, size: 44, color: AppColors.gris),
            const SizedBox(height: 14),
            Text('No hay trancas disponibles',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
            const SizedBox(height: 8),
            Text(
              'Revisá que tengas un punto de acceso seleccionado. Podés '
              'cambiarlo con el ícono de ubicación, arriba.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.gris, height: 1.45),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );
}

// ─── Selector de tranca, compartido por los dos formularios ──────────────
class _SelectorTranca extends StatelessWidget {
  final List<dynamic> trancas;
  final int? seleccionada;
  final ValueChanged<int?> onChanged;
  const _SelectorTranca({
    required this.trancas, required this.seleccionada, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: seleccionada,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tranca a abrir',
        prefixIcon: Icon(Icons.door_sliding_outlined),
      ),
      items: trancas.map<DropdownMenuItem<int>>((t) {
        final nombre = (t['nombre'] ?? t['punto_acceso'] ?? 'Tranca').toString();
        final tipo = (t['tipo'] ?? '').toString();
        final dir = (t['direccion'] ?? '').toString();
        final detalle = [tipo, dir].where((s) => s.isNotEmpty).join(' · ');
        return DropdownMenuItem<int>(
          value: t['id'] is int ? t['id'] as int : int.tryParse('${t['id']}'),
          child: Text(detalle.isEmpty ? nombre : '$nombre  ($detalle)',
              overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Botón de foto, compartido ───────────────────────────────────────────
class _BotonFoto extends StatelessWidget {
  final File? foto;
  final String etiqueta;
  final VoidCallback onTomar;
  const _BotonFoto({required this.foto, required this.etiqueta, required this.onTomar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTomar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: foto != null ? Colors.green.shade400 : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          color: foto != null ? Colors.green.withOpacity(0.05) : null,
        ),
        child: Row(children: [
          if (foto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(foto!, width: 48, height: 48, fit: BoxFit.cover),
            )
          else
            Icon(Icons.add_a_photo_outlined, color: AppColors.gris, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              foto != null ? '$etiqueta ✓  (tocá para repetirla)' : etiqueta,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: foto != null ? FontWeight.w600 : FontWeight.w400,
                color: foto != null ? Colors.green.shade800 : AppColors.gris,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RESIDENTE
// ═══════════════════════════════════════════════════════════════════════
class _FormResidente extends StatefulWidget {
  final List<dynamic> trancas;
  const _FormResidente({required this.trancas});

  @override
  State<_FormResidente> createState() => _FormResidenteState();
}

class _FormResidenteState extends State<_FormResidente> {
  final _casaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  Map<String, dynamic>? _encontrado;
  String? _casaEncontrada;
  bool _enMora = false;
  bool _buscando = false;
  bool _registrando = false;

  int? _tranca;
  String _direccion = 'entrada';
  File? _fotoId;

  @override
  void dispose() {
    _casaCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final casa = _casaCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();
    if (casa.isEmpty || codigo.length != 6) {
      ErrorDialog.mostrar(context, 'Escribí la casa y el código de 6 dígitos');
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await GuardiaAccesoApi.buscarResidente(casa, codigo);
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _encontrado = r['residente'] as Map<String, dynamic>;
        _casaEncontrada = r['casa']?.toString();
        _enMora = r['cuenta_en_mora'] == true;
        _buscando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ErrorDialog.mostrar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ErrorDialog.mostrar(context, 'No se pudo buscar');
    }
  }

  Future<void> _tomarFoto() async {
    final f = await CamaraHelper.capturar(fuente: ImageSource.camera);
    if (f != null && mounted) setState(() => _fotoId = f);
  }

  Future<void> _registrar() async {
    if (_tranca == null) {
      ErrorDialog.mostrar(context, 'Elegí qué tranca abrir');
      return;
    }
    // La foto es obligatoria en las entradas: es la evidencia de que el
    // guardia efectivamente verificó la identificación. Sin ella, esto
    // sería una apertura manual con más pasos.
    if (_direccion == 'entrada' && _fotoId == null) {
      ErrorDialog.mostrar(context, 'Tomá la foto de la identificación antes de abrir');
      return;
    }
    setState(() => _registrando = true);
    try {
      final r = await GuardiaAccesoApi.registrarResidente(
        residenteId: _encontrado!['id'].toString(),
        direccion: _direccion,
        accesoId: _tranca!,
        fotoIdentidad: _fotoId,
      );
      if (!mounted) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['mensaje']?.toString() ?? 'Acceso registrado')),
      );
      setState(() {
        _encontrado = null; _casaEncontrada = null; _enMora = false;
        _fotoId = null; _tranca = null; _direccion = 'entrada';
        _registrando = false;
      });
      _casaCtrl.clear();
      _codigoCtrl.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _registrando = false);
      ErrorDialog.mostrar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _registrando = false);
      ErrorDialog.mostrar(context, 'No se pudo registrar el acceso');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_encontrado == null) ...[
          Text('El residente te dice su casa y su código',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 12),
          TextField(
            controller: _casaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Casa', hintText: 'Casa 24',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigoCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos', counterText: '',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            onSubmitted: (_) => _buscar(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _buscando ? null : _buscar,
              icon: _buscando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Icon(Icons.search),
              label: const Text('Buscar residente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ] else ...[
          _FichaResidente(
            residente: _encontrado!,
            casa: _casaEncontrada ?? '',
            enMora: _enMora,
            onCancelar: () => setState(() {
              _encontrado = null; _fotoId = null; _tranca = null;
            }),
          ),
          const SizedBox(height: 18),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'entrada', label: Text('Entrada'), icon: Icon(Icons.login)),
              ButtonSegment(value: 'salida', label: Text('Salida'), icon: Icon(Icons.logout)),
            ],
            selected: {_direccion},
            onSelectionChanged: (s) => setState(() => _direccion = s.first),
          ),
          const SizedBox(height: 16),

          _SelectorTranca(
            trancas: widget.trancas,
            seleccionada: _tranca,
            onChanged: (v) => setState(() => _tranca = v),
          ),
          const SizedBox(height: 14),

          _BotonFoto(
            foto: _fotoId,
            etiqueta: 'Foto de la identificación',
            onTomar: _tomarFoto,
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _registrando ? null : _registrar,
              icon: _registrando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Icon(Icons.lock_open),
              label: Text(_direccion == 'entrada' ? 'Dar acceso' : 'Registrar salida'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.naranja, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Ficha que el guardia compara contra la identificación que le entregan.
class _FichaResidente extends StatelessWidget {
  final Map<String, dynamic> residente;
  final String casa;
  final bool enMora;
  final VoidCallback onCancelar;
  const _FichaResidente({
    required this.residente, required this.casa,
    required this.enMora, required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final foto = residente['foto_url']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.azul.withOpacity(0.25), width: 1.5),
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // La foto grande es el punto de todo el flujo: el guardia tiene
          // que poder reconocer una cara, no ver un avatar decorativo.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96, height: 96,
              child: (foto == null || foto.isEmpty)
                  ? Container(
                      color: const Color(0xFFF1F3F6),
                      child: Icon(Icons.person_outline, size: 44, color: AppColors.gris))
                  : FutureBuilder<String>(
                      future: urlFotoResidente(foto),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return Container(color: const Color(0xFFF1F3F6));
                        }
                        return Image.network(
                          snap.data!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F3F6),
                            child: Icon(Icons.person_outline, size: 44, color: AppColors.gris),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(residente['nombre']?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.azul)),
              const SizedBox(height: 4),
              Text(casa, style: TextStyle(fontSize: 14, color: AppColors.gris)),
              if ((residente['dni']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Identidad ${residente['dni']}',
                    style: TextStyle(fontSize: 13, color: AppColors.gris)),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onCancelar,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('No es esta persona'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  foregroundColor: AppColors.rojo,
                ),
              ),
            ]),
          ),
        ]),
        if ((foto ?? '').isEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 17, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Esta persona no tiene foto registrada. Verificá su identificación '
                'con más cuidado y avisá a administración para que se la tomen.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.4),
              ),
            ),
          ]),
        ],
        if (enMora) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline, size: 17, color: AppColors.gris),
            const SizedBox(width: 8),
            // Informa, no bloquea: impedirle a una familia entrar a su
            // propia casa por deber la cuota es terreno legal delicado.
            // Decisión tomada con el usuario el Día 68.
            Expanded(
              child: Text('Esta cuenta tiene cuotas pendientes. Dale acceso igual.',
                  style: TextStyle(fontSize: 12, color: AppColors.gris, height: 1.4)),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVEEDOR
// ═══════════════════════════════════════════════════════════════════════
class _FormProveedor extends StatefulWidget {
  final List<dynamic> trancas;
  const _FormProveedor({required this.trancas});

  @override
  State<_FormProveedor> createState() => _FormProveedorState();
}

class _FormProveedorState extends State<_FormProveedor> {
  final _empresaCtrl = TextEditingController();
  final _conductorCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  List<dynamic> _autorizadores = [];
  String? _autorizadoPor;
  int? _tranca;
  String _direccion = 'entrada';
  File? _fotoId;
  bool _registrando = false;

  @override
  void initState() {
    super.initState();
    GuardiaAccesoApi.autorizadores().then((a) {
      if (mounted) setState(() => _autorizadores = a);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _conductorCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    final f = await CamaraHelper.capturar(fuente: ImageSource.camera);
    if (f != null && mounted) setState(() => _fotoId = f);
  }

  Future<void> _registrar() async {
    if (_empresaCtrl.text.trim().isEmpty || _conductorCtrl.text.trim().isEmpty) {
      ErrorDialog.mostrar(context, 'Escribí la empresa y el nombre del conductor');
      return;
    }
    if (_tranca == null) {
      ErrorDialog.mostrar(context, 'Elegí qué tranca abrir');
      return;
    }
    if (_direccion == 'entrada' && _autorizadoPor == null) {
      ErrorDialog.mostrar(context, 'Indicá quién autoriza la entrada');
      return;
    }
    if (_direccion == 'entrada' && _fotoId == null) {
      ErrorDialog.mostrar(context, 'Tomá la foto de la identificación del conductor');
      return;
    }

    setState(() => _registrando = true);
    try {
      final r = await GuardiaAccesoApi.registrarProveedor(
        empresa: _empresaCtrl.text.trim(),
        conductor: _conductorCtrl.text.trim(),
        direccion: _direccion,
        accesoId: _tranca!,
        placa: _placaCtrl.text.trim(),
        autorizadoPor: _autorizadoPor,
        fotoIdentidad: _fotoId,
      );
      if (!mounted) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['mensaje']?.toString() ?? 'Acceso registrado')),
      );
      setState(() {
        _fotoId = null; _tranca = null; _autorizadoPor = null;
        _direccion = 'entrada'; _registrando = false;
      });
      _empresaCtrl.clear();
      _conductorCtrl.clear();
      _placaCtrl.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _registrando = false);
      ErrorDialog.mostrar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _registrando = false);
      ErrorDialog.mostrar(context, 'No se pudo registrar el acceso');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Camión de agua, gas, refrescos…',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
        const SizedBox(height: 12),

        TextField(
          controller: _empresaCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Empresa', prefixIcon: Icon(Icons.business_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conductorCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del conductor', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _placaCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Placa del vehículo', prefixIcon: Icon(Icons.directions_car_outlined)),
        ),
        const SizedBox(height: 14),

        // Lista cerrada, nunca texto libre: un campo libre lo llenaría el
        // guardia con cualquier cosa y el dato no serviría para auditar.
        DropdownButtonFormField<String>(
          value: _autorizadoPor,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Autoriza la entrada',
            prefixIcon: Icon(Icons.verified_user_outlined),
          ),
          items: _autorizadores.map<DropdownMenuItem<String>>((a) {
            final cargo = (a['cargo'] ?? '').toString();
            return DropdownMenuItem<String>(
              value: a['id'].toString(),
              child: Text(cargo.isEmpty ? '${a['nombre']}' : '${a['nombre']} — $cargo',
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) => setState(() => _autorizadoPor = v),
        ),
        if (_autorizadores.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No hay autorizadores cargados. Pedile a administración que los '
              'registre desde el panel.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.4),
            ),
          ),
        const SizedBox(height: 16),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'entrada', label: Text('Entrada'), icon: Icon(Icons.login)),
            ButtonSegment(value: 'salida', label: Text('Salida'), icon: Icon(Icons.logout)),
          ],
          selected: {_direccion},
          onSelectionChanged: (s) => setState(() => _direccion = s.first),
        ),
        const SizedBox(height: 16),

        _SelectorTranca(
          trancas: widget.trancas,
          seleccionada: _tranca,
          onChanged: (v) => setState(() => _tranca = v),
        ),
        const SizedBox(height: 14),

        _BotonFoto(
          foto: _fotoId,
          etiqueta: 'Foto de la identificación del conductor',
          onTomar: _tomarFoto,
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _registrando ? null : _registrar,
            icon: _registrando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                : const Icon(Icons.lock_open),
            label: Text(_direccion == 'entrada' ? 'Dar acceso' : 'Registrar salida'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranja, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ]),
    );
  }
}
