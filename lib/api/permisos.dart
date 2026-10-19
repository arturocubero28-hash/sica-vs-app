import 'package:permission_handler/permission_handler.dart';

/// Día 69 — resultado detallado de pedir un permiso.
///
/// Hace falta distinguir dos situaciones que ANTES se trataban igual y que
/// requieren mensajes distintos:
///   - [negado]: el usuario dijo que no esta vez. Se le puede volver a pedir
///     y Android mostrará su diálogo otra vez.
///   - [negadoPermanente]: el usuario lo bloqueó (o tocó "no volver a
///     preguntar"). A partir de acá `request()` devuelve negado de inmediato
///     SIN mostrar ningún diálogo del sistema, así que la única salida real es
///     mandarlo a Ajustes. Esto es lo que hacía que el escáner del guardia
///     quedara en negro sin explicación cuando el permiso se había negado
///     antes desde otra pantalla de la app (por ejemplo, al subir un
///     comprobante como residente): el permiso es por instalación, no por
///     usuario, así que una negativa anterior lo deja bloqueado para todos.
enum ResultadoPermiso { concedido, negado, negadoPermanente }

/// Gestiona los permisos en tiempo de ejecución de la app.
class PermisosService {
  /// Pide permiso de cámara. Devuelve true si fue concedido.
  static Future<bool> pedirCamara() async {
    final estado = await Permission.camera.request();
    return estado.isGranted;
  }

  /// Pide la cámara distinguiendo negado de negado-permanente.
  static Future<ResultadoPermiso> pedirCamaraDetallado() async {
    final estado = await Permission.camera.request();
    return _mapear(estado);
  }

  /// Consulta el estado SIN pedirlo. Se usa al volver de Ajustes.
  ///
  /// Ojo: en Android `status` no distingue de forma confiable el negado
  /// permanente (eso solo se sabe después de un `request()`), así que acá
  /// únicamente interesa si quedó concedido o no.
  static Future<bool> camaraConcedida() async {
    final estado = await Permission.camera.status;
    return estado.isGranted || estado.isLimited;
  }

  static ResultadoPermiso _mapear(PermissionStatus estado) {
    if (estado.isGranted || estado.isLimited) return ResultadoPermiso.concedido;
    if (estado.isPermanentlyDenied || estado.isRestricted) {
      return ResultadoPermiso.negadoPermanente;
    }
    return ResultadoPermiso.negado;
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
