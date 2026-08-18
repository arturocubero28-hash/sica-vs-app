import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_dialog.dart';

/// Día 56 — visor de PDF embebido, reutilizable. Muestra un PDF ya
/// descargado (ruta local) dentro de la app, con botones para compartir y
/// descargar (guardar) en el propio dispositivo. Se usa para previsualizar
/// el recibo desde el historial de pagos, pero sirve para cualquier PDF.
class VisorPdfScreen extends StatefulWidget {
  /// Ruta del archivo PDF ya descargado (en el directorio temporal).
  final String rutaArchivo;

  /// Título que se muestra en la barra superior (ej. "Recibo REC-000001").
  final String titulo;

  /// Nombre sugerido al descargar/guardar (ej. "recibo-000001.pdf").
  final String nombreArchivo;

  const VisorPdfScreen({
    super.key,
    required this.rutaArchivo,
    required this.titulo,
    required this.nombreArchivo,
  });

  @override
  State<VisorPdfScreen> createState() => _VisorPdfScreenState();
}

class _VisorPdfScreenState extends State<VisorPdfScreen> {
  bool _cargando = true;
  String? _error;
  bool _guardando = false;

  Future<void> _compartir() async {
    await Share.shareXFiles(
      [XFile(widget.rutaArchivo, mimeType: 'application/pdf')],
      subject: widget.titulo,
    );
  }

  Future<void> _descargar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      // Copiar el PDF (que vive en el directorio temporal) a un lugar más
      // permanente. En Android, la carpeta de descargas externa si está
      // disponible; si no, el directorio de documentos de la app.
      Directory? destino;
      if (Platform.isAndroid) {
        destino = Directory('/storage/emulated/0/Download');
        if (!await destino.exists()) destino = null;
      }
      destino ??= await getApplicationDocumentsDirectory();

      final origen = File(widget.rutaArchivo);
      final rutaDestino = '${destino.path}/${widget.nombreArchivo}';
      await origen.copy(rutaDestino);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recibo guardado en ${destino.path}'),
        backgroundColor: AppColors.verde,
      ));
    } catch (e) {
      if (!mounted) return;
      // Día 63 — modal de error reutilizable en vez de un SnackBar chico
      // (pedido del usuario), y de paso el mismo criterio de ayer: mostrar
      // el tipo real del error en vez de descartarlo con catch (_).
      ErrorDialog.mostrar(context, 'No se pudo guardar el recibo. (${e.runtimeType})');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download),
            tooltip: 'Descargar',
            onPressed: _guardando ? null : _descargar,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: _compartir,
          ),
        ],
      ),
      body: Stack(children: [
        if (_error == null)
          PDFView(
            filePath: widget.rutaArchivo,
            onError: (e) => setState(() {
              _error = 'No se pudo mostrar el PDF.';
              _cargando = false;
            }),
            onRender: (_) => setState(() => _cargando = false),
          ),
        if (_cargando && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.gris),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.gris)),
            ]),
          ),
      ]),
    );
  }
}
