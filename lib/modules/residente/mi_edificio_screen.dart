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
      setState(() {
        _edificios = edifs as List<dynamic>;
        _codigos = cods as List<dynamic>;
        if (_edificios.isNotEmpty && _edificioSel == null) {
          _edificioSel = _edificios.first['id']?.toString()
              ?? _edificios.first['uuid_publico']?.toString();
        }
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
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
                            onChanged: (v) => setState(() => _edificioSel = v),
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

                  // ── Códigos existentes ──
                  const Text('Códigos generados',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                  const SizedBox(height: 8),
                  if (_codigos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aún no generaste códigos',
                          style: TextStyle(color: AppColors.gris))),
                    )
                  else
                    ..._codigos.map((c) => _CodigoCard(codigo: c, onBorrado: _cargar)),
                ],
              ),
            ),
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
