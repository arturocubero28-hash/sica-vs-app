import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

/// Mi Edificio (solo dueños de edificio): generar códigos de enrolamiento
/// de 6 dígitos para que los inquilinos se registren avalados.
class MiEdificioScreen extends StatefulWidget {
  const MiEdificioScreen({super.key});

  @override
  State<MiEdificioScreen> createState() => _MiEdificioScreenState();
}

class _MiEdificioScreenState extends State<MiEdificioScreen> {
  List<dynamic> _edificios = [];
  List<dynamic> _codigos = [];
  List<dynamic> _apartamentos = [];
  bool _cargando = true;
  String? _edificioSel;
  final _aptoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  bool _generando = false;

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() { _aptoCtrl.dispose(); _notaCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final edifs = await ApiClient.get('/unidades/mis-edificios');
      final cods = await ApiClient.get('/unidades/enrolamiento/mis-codigos');
      final edificiosList = edifs as List<dynamic>;
      List<dynamic> aptos = [];
      String? sel = _edificioSel;
      if (edificiosList.isNotEmpty) {
        sel ??= edificiosList.first['id']?.toString()
            ?? edificiosList.first['uuid_publico']?.toString();
        try {
          aptos = await ApiClient.get('/unidades/mis-edificios/$sel/apartamentos') as List<dynamic>;
        } catch (_) {}
      }
      setState(() {
        _edificios = edificiosList;
        _codigos = cods as List<dynamic>;
        _apartamentos = aptos;
        _edificioSel = sel;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEdificio(String? id) async {
    if (id == null) return;
    setState(() { _edificioSel = id; _apartamentos = []; });
    try {
      final aptos = await ApiClient.get('/unidades/mis-edificios/$id/apartamentos');
      if (mounted) setState(() => _apartamentos = aptos as List<dynamic>);
    } catch (_) {}
  }

  Future<void> _generar() async {
    if (_edificioSel == null) return;
    setState(() => _generando = true);
    try {
      await ApiClient.post('/unidades/enrolamiento/generar', {
        'edificio_id': _edificioSel,
        if (_aptoCtrl.text.trim().isNotEmpty) 'apartamento': _aptoCtrl.text.trim(),
        if (_notaCtrl.text.trim().isNotEmpty) 'nota': _notaCtrl.text.trim(),
      });
      _aptoCtrl.clear(); _notaCtrl.clear();
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Código generado'), backgroundColor: AppColors.verde));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Edificio')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Generar código ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Generar código para inquilino',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                        const SizedBox(height: 4),
                        const Text(
                          'El inquilino usa este código de 6 dígitos al registrarse '
                          'y queda avalado por vos.',
                          style: TextStyle(fontSize: 12, color: AppColors.gris),
                        ),
                        const SizedBox(height: 14),
                        if (_edificios.length > 1)
                          DropdownButtonFormField<String>(
                            value: _edificioSel,
                            decoration: const InputDecoration(labelText: 'Edificio'),
                            items: _edificios.map<DropdownMenuItem<String>>((e) =>
                                DropdownMenuItem(
                                    value: e['id']?.toString() ?? e['uuid_publico']?.toString(),
                                    child: Text(e['identificador']?.toString() ?? ''))).toList(),
                            onChanged: (v) => _cambiarEdificio(v),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _aptoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Apartamento sugerido (ej. 2B) — opcional'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notaCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Nota (ej. nombre del inquilino) — opcional'),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generando ? null : _generar,
                            icon: const Icon(Icons.key, size: 18),
                            label: Text(_generando ? 'Generando…' : 'Generar código'),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Códigos activos (aún no usados) ──
                  Builder(builder: (_) {
                    final activos = _codigos.where((c) => c['estado'] != 'usado').toList();
                    final usados  = _codigos.where((c) => c['estado'] == 'usado').toList();

                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Códigos activos (${activos.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                      const SizedBox(height: 8),
                      if (activos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No tenés códigos activos. Generá uno arriba.',
                              style: TextStyle(color: AppColors.gris)),
                        )
                      else
                        ...activos.map((c) => _CodigoCard(codigo: c, onBorrado: _cargar)),

                      // ── Inquilinos ya enrolados ──
                      if (usados.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Inquilinos ya enrolados (${usados.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: usados.map((c) => _InquilinoRow(codigo: c)).toList(),
                            ),
                          ),
                        ),
                      ],

                      // ── Todos los apartamentos del edificio ──
                      if (_apartamentos.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Apartamentos del edificio (${_apartamentos.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                        const SizedBox(height: 8),
                        ...(_apartamentos.map((a) {
                          final apto = a['apartamento']?.toString() ?? '—';
                          final titular = a['titular'] as Map? ?? {};
                          final nombre = titular['nombre']?.toString() ?? '—';
                          final bloqueada = a['bloqueada'] == true;
                          final tarifa = a['tarifa']?.toString();
                          final monto = a['monto'];
                          final tipoCuenta = a['tipo_cuenta']?.toString() ?? '';
                          final esAdmin = tipoCuenta == 'edificio_admin' || tipoCuenta == 'edificio_contenedor';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: (esAdmin ? AppColors.azul : AppColors.naranja).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  esAdmin ? Icons.admin_panel_settings : Icons.home,
                                  color: esAdmin ? AppColors.azul : AppColors.naranja, size: 20,
                                ),
                              ),
                              title: Row(children: [
                                Text('Apto $apto',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                if (esAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.azul, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Admin', style: TextStyle(
                                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ]),
                              subtitle: Text(nombre,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.gris)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (tarifa != null)
                                    Text('L ${monto ?? "—"}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (bloqueada ? AppColors.rojo : AppColors.verde).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4)),
                                    child: Text(bloqueada ? 'Bloqueada' : 'Al día',
                                        style: TextStyle(
                                            color: bloqueada ? AppColors.rojo : AppColors.verde,
                                            fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })),
                      ],
                    ]);
                  }),
                ],
              ),
            ),
    );
  }
}

/// Fila de un inquilino ya enrolado: apartamento, nota y fecha.
class _InquilinoRow extends StatelessWidget {
  final Map codigo;
  const _InquilinoRow({required this.codigo});

  @override
  Widget build(BuildContext context) {
    final apto = codigo['apartamento_sugerido']?.toString();
    final nota = codigo['nota']?.toString();
    final usadoEn = codigo['usado_en'] != null
        ? DateTime.tryParse(codigo['usado_en'].toString())
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        const Icon(Icons.person, size: 18, color: AppColors.verde),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(apto != null ? 'Apto $apto' : 'Sin apartamento asignado',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            if (nota != null && nota.isNotEmpty)
              Text(nota, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          ]),
        ),
        if (usadoEn != null)
          Text('${usadoEn.day}/${usadoEn.month}/${usadoEn.year}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.gris)),
      ]),
    );
  }
}

class _CodigoCard extends StatelessWidget {
  final dynamic codigo;
  final VoidCallback onBorrado;
  const _CodigoCard({required this.codigo, required this.onBorrado});

  @override
  Widget build(BuildContext context) {
    final cod = codigo['codigo']?.toString() ?? '';
    final usado = codigo['estado'] == 'usado';
    final apto = codigo['apartamento_sugerido']?.toString();
    final nota = codigo['nota']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Código grande
          Text(cod, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3,
            color: usado ? AppColors.gris : AppColors.azul,
            decoration: usado ? TextDecoration.lineThrough : null,
          )),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (apto != null && apto.isNotEmpty)
              Text('Apto $apto', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            if (nota != null && nota.isNotEmpty)
              Text(nota, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            Text(usado ? 'Usado' : 'Disponible',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: usado ? AppColors.gris : AppColors.verde)),
          ])),
          if (!usado) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 20, color: AppColors.azul),
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cod));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.rojo),
              tooltip: 'Borrar',
              onPressed: () async {
                try {
                  final id = codigo['id']?.toString() ?? codigo['uuid_publico']?.toString();
                  await ApiClient.delete('/unidades/enrolamiento/$id');
                  onBorrado();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()), backgroundColor: AppColors.rojo));
                }
              },
            ),
          ],
        ]),
      ),
    );
  }
}
