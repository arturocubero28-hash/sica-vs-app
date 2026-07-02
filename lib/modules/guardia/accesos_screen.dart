import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

final _fmtHora = DateFormat('HH:mm');
final _fmtFecha = DateFormat('dd/MM');

class AccesosScreen extends StatefulWidget {
  const AccesosScreen({super.key});

  @override
  State<AccesosScreen> createState() => _AccesosScreenState();
}

class _AccesosScreenState extends State<AccesosScreen> {
  List<dynamic> _accesos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await GuardiaApi.historialAccesos();
      setState(() => _accesos = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, size: 56, color: AppColors.gris),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.gris)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _cargar,
            icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ],
    ));

    return RefreshIndicator(
      onRefresh: _cargar,
      child: _accesos.isEmpty
          ? const Center(child: Text('Sin accesos registrados hoy',
              style: TextStyle(color: AppColors.gris)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accesos.length,
              itemBuilder: (_, i) => _AccesoCard(acceso: _accesos[i]),
            ),
    );
  }
}

class _AccesoCard extends StatelessWidget {
  final dynamic acceso;
  const _AccesoCard({required this.acceso});

  @override
  Widget build(BuildContext context) {
    final nombre    = acceso['nombre_visitante'] ?? 'Desconocido';
    final resultado = acceso['resultado'] ?? '';
    final hora      = DateTime.tryParse(acceso['creado_en'] ?? '');
    final tipo      = acceso['tipo_qr'] ?? '';
    final unidad    = acceso['unidad'] ?? '';
    final permitido = resultado == 'permitido';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (permitido ? AppColors.verde : AppColors.rojo).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              permitido ? Icons.check : Icons.close,
              color: permitido ? AppColors.verde : AppColors.rojo,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 14)),
            Text(unidad.isNotEmpty ? '$unidad · $tipo' : tipo,
                style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          ])),
          if (hora != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtHora.format(hora),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
              Text(_fmtFecha.format(hora),
                  style: const TextStyle(fontSize: 11, color: AppColors.gris)),
            ]),
        ]),
      ),
    );
  }
}
