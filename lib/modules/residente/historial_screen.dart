import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

final _fmt = NumberFormat.currency(locale: 'es_HN', symbol: 'L ');
final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<dynamic> _pagos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ResidenteApi.misCuotas();
      setState(() => _pagos = (res['historial'] as List<dynamic>?) ?? []);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, size: 56, color: AppColors.gris),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.gris)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _cargar,
            icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ]),
    );

    if (_pagos.isEmpty) return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, size: 64, color: AppColors.gris),
        SizedBox(height: 16),
        Text('Sin pagos registrados aún', style: TextStyle(color: AppColors.gris)),
      ]),
    );

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pagos.length,
        itemBuilder: (_, i) => _PagoCard(pago: _pagos[i]),
      ),
    );
  }
}

class _PagoCard extends StatelessWidget {
  final dynamic pago;
  const _PagoCard({required this.pago});

  @override
  Widget build(BuildContext context) {
    final etiqueta = pago['etiqueta'] as String? ?? (pago['abono_id'] != null ? 'Abono de arreglo' : 'Cuota mensual');
    final monto  = (pago['monto'] as num).toDouble();
    final estado = pago['estado'] as String? ?? 'aprobado';
    final metodo = pago['metodo'] as String? ?? '';
    final fecha  = DateTime.tryParse(pago['fecha'] ?? pago['creado_en'] ?? '');
    final recibo = pago['numero_recibo'] as String?;

    final aprobado = estado == 'aprobado';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (aprobado ? AppColors.verde : AppColors.amber).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              recibo != null ? Icons.receipt_long_outlined : Icons.hourglass_empty_outlined,
              color: AppColors.verde,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
            if (fecha != null)
              Text(_fmtFecha.format(fecha),
                  style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            if (metodo.isNotEmpty)
              Text(metodo, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(monto),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.azul, fontSize: 15)),
            if (recibo != null)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _abrirRecibo(context, pago['uuid_publico'] ?? pago['id'].toString()),
                child: const Text('Ver recibo', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _abrirRecibo(BuildContext context, String pagoId) async {
    // TODO: abrir el PDF del recibo cuando tengamos url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente: abrir recibo PDF')));
  }
}
