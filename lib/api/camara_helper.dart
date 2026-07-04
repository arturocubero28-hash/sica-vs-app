import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Captura o selecciona una imagen de forma resistente al "proceso matado por Android".
///
/// En teléfonos con poca RAM (como el Moto E15), Android puede matar el proceso
/// de la app mientras la cámara está abierta, para liberar memoria. Cuando el
/// usuario termina de tomar la foto y vuelve, la app se relanza desde cero y la
/// foto se "pierde". `ImagePicker.retrieveLostData()` es la API oficial de Flutter
/// para recuperar esa foto después del reinicio.
///
/// USO:
///   final archivo = await CamaraHelper.capturar(context, fuente: ImageSource.camera);
///   if (archivo != null) { /* usar el archivo */ }
class CamaraHelper {
  static final _picker = ImagePicker();

  /// Captura desde cámara o galería con calidad optimizada para teléfonos de gama baja.
  /// Maneja automáticamente la recuperación de datos perdidos por reinicio de Android.
  static Future<File?> capturar({
    ImageSource fuente = ImageSource.camera,
    int quality = 50,
    int maxSize = 1024,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: fuente,
        imageQuality: quality,
        maxWidth: maxSize.toDouble(),
        maxHeight: maxSize.toDouble(),
      );
      if (picked != null) return File(picked.path);
    } catch (e) {
      // Si el picker lanzó excepción (ej. proceso reiniciado), intenta recuperar
    }

    // Intentar recuperar foto perdida por Android matando el proceso
    return await _recuperar();
  }

  /// Recupera una imagen que Android perdió cuando mató el proceso.
  /// Llama esto en el initState de pantallas que usan cámara.
  static Future<File?> recuperarPerdida() async {
    return await _recuperar();
  }

  static Future<File?> _recuperar() async {
    try {
      final perdida = await _picker.retrieveLostData();
      if (perdida.isEmpty) return null;
      if (perdida.file != null) return File(perdida.file!.path);
      if (perdida.files != null && perdida.files!.isNotEmpty) {
        return File(perdida.files!.first.path);
      }
    } catch (_) {}
    return null;
  }
}
