import 'package:permission_handler/permission_handler.dart';

/// Gestiona los permisos en tiempo de ejecución de la app.
class PermisosService {
  /// Pide permiso de cámara. Devuelve true si fue concedido.
  static Future<bool> pedirCamara() async {
    final estado = await Permission.camera.request();
    return estado.isGranted;
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
