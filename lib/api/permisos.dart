import 'package:permission_handler/permission_handler.dart';

/// Gestiona los permisos en tiempo de ejecución de la app.
class PermisosService {
  /// Pide permiso de cámara. Devuelve true si fue concedido.
  static Future<bool> pedirCamara() async {
    final estado = await Permission.camera.request();
    return estado.isGranted;
  }

  /// Pide permiso de galería/fotos. En Android 13+ es Permission.photos,
  /// en versiones anteriores es storage. permission_handler lo resuelve solo.
  static Future<bool> pedirGaleria() async {
    // En Android 13+ el permiso es 'photos'; en anteriores 'storage'.
    final foto = await Permission.photos.request();
    if (foto.isGranted || foto.isLimited) return true;
    // Fallback para Android < 13
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  /// Verifica si la cámara ya tiene permiso sin volver a pedirlo.
  static Future<bool> tieneCamara() async {
    return await Permission.camera.isGranted;
  }

  /// Abre la configuración del sistema si el usuario negó el permiso
  /// permanentemente (para que lo habilite manualmente).
  static Future<void> abrirConfiguracion() async {
    await openAppSettings();
  }
}
