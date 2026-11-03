import 'package:flutter/material.dart';

/// Día 72 — foto a pantalla completa, con zoom de pellizco.
///
/// Se abre al tocar una miniatura. Fondo negro, la foto centrada y entera
/// (sin recortar). Se cierra con la X, con "atrás" o con un toque.
class VisorFoto extends StatelessWidget {
  final String url;
  final String heroTag;
  final String? titulo;
  const VisorFoto({super.key, required this.url, required this.heroTag, this.titulo});

  static Future<void> abrir(BuildContext context,
      {required String url, required String heroTag, String? titulo}) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => VisorFoto(url: url, heroTag: heroTag, titulo: titulo),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: titulo == null
            ? null
            : Text(titulo!, style: const TextStyle(fontSize: 16, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progreso) => progreso == null
                    ? child
                    : const SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5)),
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No se pudo cargar la foto. Revisá tu conexión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
