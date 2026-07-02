import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  List<dynamic> _visitas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ResidenteApi.misVisitas();
      setState(() => _visitas = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _abrirCrear() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalCrearQr(onCreado: _cargar),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisCl,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorWidget(error: _error!, onRetry: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _visitas.isEmpty
                      ? _Vacio(onCrear: _abrirCrear)
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ..._visitas.map((v) => _VisitaCard(visita: v)),
                            const SizedBox(height: 80),
                          ],
                        ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrear,
        backgroundColor: AppColors.naranja,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _VisitaCard extends StatelessWidget {
  final dynamic visita;
  const _VisitaCard({required this.visita});

  @override
  Widget build(BuildContext context) {
    final tipo = visita['tipo'] ?? 'unica';
    final nombre = visita['nombre_visitante'] ?? 'Visita';
    final activa = visita['activa'] == true;
    final qrData = visita['uuid_publico'] ?? visita['id'].toString();

    Color chipColor;
    String chipLabel;
    switch (tipo) {
      case 'recurrente': chipColor = AppColors.azul2; chipLabel = 'Recurrente'; break;
      case 'repartidor': chipColor = AppColors.amber; chipLabel = 'Repartidor'; break;
      default:           chipColor = AppColors.verde; chipLabel = 'Única';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarQr(context, nombre, qrData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // QR miniatura
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 56,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.azul),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.azul),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(chipLabel, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (activa ? AppColors.verde : AppColors.gris).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(activa ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          color: activa ? AppColors.verde : AppColors.gris,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            )),
            const Icon(Icons.chevron_right, color: AppColors.gris),
          ]),
        ),
      ),
    );
  }

  void _mostrarQr(BuildContext context, String nombre, String qrData) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(nombre, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azul)),
            const SizedBox(height: 20),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: AppColors.azul),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square, color: AppColors.azul),
            ),
            const SizedBox(height: 16),
            Text('Mostrá este código al guardia',
                style: TextStyle(color: AppColors.gris, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar')),
          ]),
        ),
      ),
    );
  }
}

class _ModalCrearQr extends StatefulWidget {
  final VoidCallback onCreado;
  const _ModalCrearQr({required this.onCreado});

  @override
  State<_ModalCrearQr> createState() => _ModalCrearQrState();
}

class _ModalCrearQrState extends State<_ModalCrearQr> {
  String _tipo = 'unica';
  final _nombreCtrl = TextEditingController();
  bool _creando = false;
  String? _error;

  @override
  void dispose() { _nombreCtrl.dispose(); super.dispose(); }

  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre del visitante');
      return;
    }
    setState(() { _creando = true; _error = null; });
    try {
      final body = {'nombre_visitante': _nombreCtrl.text.trim(), 'tipo': _tipo};
      switch (_tipo) {
        case 'unica': await ResidenteApi.crearVisitaUnica(body); break;
        case 'recurrente': await ResidenteApi.crearVisitaRecurrente(body); break;
        case 'repartidor': await ResidenteApi.crearRepartidor(body); break;
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreado();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Nuevo código QR', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azul)),
        const SizedBox(height: 20),

        // Tipo
        Row(children: [
          for (final t in [
            ('unica', 'Única', AppColors.verde),
            ('recurrente', 'Recurrente', AppColors.azul2),
            ('repartidor', 'Repartidor', AppColors.amber),
          ])
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(t.$2, style: TextStyle(
                  color: _tipo == t.$1 ? Colors.white : AppColors.gris,
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
                selected: _tipo == t.$1,
                selectedColor: t.$3,
                backgroundColor: AppColors.grisCl,
                onSelected: (_) => setState(() => _tipo = t.$1),
              ),
            )),
        ]),
        const SizedBox(height: 14),

        // Nombre
        TextField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del visitante',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
        ],
        const SizedBox(height: 20),

        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _creando ? null : _crear,
            child: _creando
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Crear QR'),
          ),
        ),
      ]),
    );
  }
}

class _Vacio extends StatelessWidget {
  final VoidCallback onCrear;
  const _Vacio({required this.onCrear});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.qr_code_2, size: 80, color: AppColors.gris.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('No tenés QR activos', style: TextStyle(color: AppColors.gris, fontSize: 16)),
      const SizedBox(height: 8),
      TextButton.icon(onPressed: onCrear, icon: const Icon(Icons.add),
          label: const Text('Crear el primero')),
    ],
  ));
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.wifi_off, size: 56, color: AppColors.gris),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gris)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
          label: const Text('Reintentar')),
    ],
  ));
}
