import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../api/client.dart';
import '../../api/config.dart';
import '../../theme/app_theme.dart';

final _fmtCom = DateFormat('dd/MM/yyyy');

/// Carga una imagen del backend que requiere autenticación (header Bearer).
/// Se usa para las imágenes de comunicados, que están protegidas por token.
class _ImagenAutenticada extends StatefulWidget {
  final String nombreArchivo;
  final double? alto;
  final BoxFit fit;
  const _ImagenAutenticada(this.nombreArchivo, {this.alto, this.fit = BoxFit.cover});

  @override
  State<_ImagenAutenticada> createState() => _ImagenAutenticadaState();
}

class _ImagenAutenticadaState extends State<_ImagenAutenticada> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/comunicados/imagenes/${widget.nombreArchivo}'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200 && mounted) {
        setState(() => _bytes = res.bodyBytes);
      } else if (mounted) {
        setState(() => _error = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const SizedBox.shrink();
    if (_bytes == null) {
      return Container(
        height: widget.alto ?? 160,
        color: AppColors.grisCl,
        child: const Center(
          child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return Image.memory(_bytes!, height: widget.alto, width: double.infinity, fit: widget.fit);
  }
}

/// Inicio del residente: comunicados de la administración (igual que la web).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _comunicados = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await ApiClient.get('/comunicados');
      setState(() => _comunicados = res as List<dynamic>);
    } catch (_) {
      // Silencioso: sin comunicados
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado
          Row(children: [
            const Icon(Icons.campaign_rounded, color: AppColors.naranja, size: 20),
            const SizedBox(width: 8),
            const Text('Comunicados',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.azul)),
          ]),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.only(left: 28),
            child: Text('Anuncios de la administración',
                style: TextStyle(fontSize: 12.5, color: AppColors.gris)),
          ),
          const SizedBox(height: 16),

          if (_comunicados.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(Icons.campaign_outlined, size: 64, color: AppColors.gris.withOpacity(0.3)),
                const SizedBox(height: 12),
                const Text('No hay comunicados por ahora',
                    style: TextStyle(color: AppColors.gris)),
              ]),
            )
          else
            ..._comunicados.map((c) => _ComunicadoCard(
                com: c, onTap: () => _abrirComunicado(c))),
        ],
      ),
    );
  }

  void _abrirComunicado(dynamic com) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borde, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(com['titulo']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.azul)),
            const SizedBox(height: 6),
            if ((com['created_at'] ?? com['creado_en']) != null)
              Text(_fmtCom.format(DateTime.parse((com['created_at'] ?? com['creado_en']).toString())),
                  style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            const SizedBox(height: 14),
            if (com['imagen'] != null && com['imagen'].toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _ImagenAutenticada(com['imagen'].toString(), fit: BoxFit.fitWidth),
              ),
              const SizedBox(height: 14),
            ],
            Text(com['cuerpo']?.toString() ?? '',
                style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF2B3440))),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _ComunicadoCard extends StatelessWidget {
  final dynamic com;
  final VoidCallback onTap;
  const _ComunicadoCard({required this.com, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final titulo = com['titulo']?.toString() ?? '';
    final cuerpo = com['cuerpo']?.toString() ?? '';
    final imagen = com['imagen']?.toString() ?? '';
    final fecha = (com['created_at'] ?? com['creado_en']) != null
        ? DateTime.tryParse((com['created_at'] ?? com['creado_en']).toString())
        : null;
    final tieneImagen = imagen.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Imagen del comunicado (si tiene), a lo ancho de la tarjeta
          if (tieneImagen)
            _ImagenAutenticada(imagen, alto: 150, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!tieneImagen) ...[
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.naranja.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign, color: AppColors.naranja, size: 24),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                const SizedBox(height: 4),
                Text(cuerpo, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.gris, height: 1.4)),
                if (fecha != null) ...[
                  const SizedBox(height: 6),
                  Text(_fmtCom.format(fecha),
                      style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                ],
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}
