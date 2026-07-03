import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

final _fmtHora  = DateFormat('HH:mm');
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
      final res = await ApiClient.get('/visitas/accesos/recientes');
      setState(() => _accesos = res as List<dynamic>);
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
          ? const Center(child: Text('Sin accesos registrados',
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
    final nombre    = acceso['nombre_visitante']?.toString() ?? 'Residente';
    final direccion = acceso['direccion']?.toString() ?? '';
    final hora      = DateTime.tryParse(acceso['ocurrido_en']?.toString() ?? '');
    final tipo      = acceso['tipo_qr']?.toString() ?? acceso['origen']?.toString() ?? '';
    final unidad    = acceso['unidad']?.toString() ?? '';
    final enVehiculo = acceso['en_vehiculo'] == true;
    final placa     = acceso['placa_vehiculo']?.toString();
    final guardia   = acceso['guardia']?.toString();

    final esEntrada = direccion == 'entrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (esEntrada ? AppColors.verde : AppColors.azul).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esEntrada ? Icons.login : Icons.logout,
              color: esEntrada ? AppColors.verde : AppColors.azul,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 14)),
            Row(children: [
              if (unidad.isNotEmpty) ...[
                Text(unidad, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                const Text(' · ', style: TextStyle(color: AppColors.gris)),
              ],
              Text(tipo, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              if (enVehiculo) ...[
                const Text(' · ', style: TextStyle(color: AppColors.gris)),
                const Icon(Icons.directions_car, size: 14, color: AppColors.gris),
                if (placa != null && placa.isNotEmpty)
                  Text(' $placa', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
              ],
            ]),
            if (guardia != null && guardia.isNotEmpty)
              Text('Guardia: $guardia',
                  style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (hora != null)
              Text(_fmtHora.format(hora.toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 15)),
            if (hora != null)
              Text(_fmtFecha.format(hora.toLocal()),
                  style: const TextStyle(fontSize: 11, color: AppColors.gris)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (esEntrada ? AppColors.verde : AppColors.azul).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(esEntrada ? 'Entrada' : 'Salida', style: TextStyle(
                color: esEntrada ? AppColors.verde : AppColors.azul,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
            ),
          ]),
        ]),
      ),
    );
  }
}
