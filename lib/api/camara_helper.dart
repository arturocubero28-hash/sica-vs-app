import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Captura o selecciona una imagen de forma resistente al "proceso matado por Android",
/// y la comprime automáticamente a WebP antes de devolverla.
///
/// En teléfonos con poca RAM (como el Moto E15), Android puede matar el proceso
/// de la app mientras la cámara está abierta, para liberar memoria. Cuando el
/// usuario termina de tomar la foto y vuelve, la app se relanza desde cero y la
/// foto se "pierde". `ImagePicker.retrieveLostData()` es la API oficial de Flutter
/// para recuperar esa foto después del reinicio.
///
/// Todas las fotos (identidad, placa, número de casa, comprobantes) pasan por
/// `_comprimirWebp()` antes de subirse: WebP pesa 25-35% menos que JPEG con la
/// misma calidad visual, lo que ahorra datos móviles y espacio en el servidor.
///
/// USO:
///   final archivo = await CamaraHelper.capturar(context, fuente: ImageSource.camera);
///   if (archivo != null) { /* usar el archivo — ya viene en .webp */ }
class CamaraHelper {
  static final _picker = ImagePicker();

  /// Captura desde cámara o galería con calidad optimizada para teléfonos de gama baja.
  /// Maneja automáticamente la recuperación de datos perdidos por reinicio de Android.
  /// Devuelve el archivo ya comprimido a formato WebP.
  static Future<File?> capturar({
    ImageSource fuente = ImageSource.camera,
    int quality = 50,
    int maxSize = 1024,
  }) async {
    File? archivo;
    try {
      final picked = await _picker.pickImage(
        source: fuente,
        imageQuality: quality,
        maxWidth: maxSize.toDouble(),
        maxHeight: maxSize.toDouble(),
        requestFullMetadata: false,  // no carga EXIF completo → menos memoria
      );
      if (picked != null) archivo = File(picked.path);
    } catch (e) {
      // Si el picker lanzó excepción (ej. proceso reiniciado), intenta recuperar
    }

    archivo ??= await _recuperar();
    if (archivo == null) return null;

    return await _comprimirWebp(archivo, quality: quality, maxSize: maxSize);
  }

  /// Recupera una imagen que Android perdió cuando mató el proceso.
  /// Llama esto en el initState de pantallas que usan cámara.
  /// La imagen recuperada también se comprime a WebP.
  static Future<File?> recuperarPerdida() async {
    final archivo = await _recuperar();
    if (archivo == null) return null;
    return await _comprimirWebp(archivo);
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

  /// Comprime una imagen a formato WebP. Si falla la compresión (formato no
  /// soportado, error de plugin, etc.), devuelve el archivo original sin tocar
  /// — nunca bloquea el flujo del guardia/residente por un problema de compresión.
  static Future<File> _comprimirWebp(File original, {int quality = 70, int maxSize = 1024}) async {
    try {
      final dir = await getTemporaryDirectory();
      final nombreDestino =
          '${dir.path}/sicavs_${DateTime.now().millisecondsSinceEpoch}.webp';

      final resultado = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        nombreDestino,
        format: CompressFormat.webp,
        quality: quality.clamp(35, 85), // piso de 35 para no degradar demasiado
        minWidth: maxSize,
        minHeight: maxSize,
        keepExif: false,
      );

      if (resultado == null) return original;
      return File(resultado.path);
    } catch (_) {
      // Compresión falló (ej. dispositivo sin soporte) → usar el original
      return original;
    }
  }
}
