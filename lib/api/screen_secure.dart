import 'package:flutter/services.dart';

/// Bloqueo de captura de pantalla usando FLAG_SECURE de Android,
/// implementado con un MethodChannel nativo — sin plugins externos.
///
/// Cuando está activo:
///   - Las capturas de pantalla salen en negro
///   - No aparece en grabaciones de pantalla
///   - No se muestra en el reciente de apps
class ScreenSecure {
  static const _channel = MethodChannel('sicavs/screen_secure');

  /// Activa FLAG_SECURE. Llamar en initState de la pantalla sensible.
  static Future<void> activar() async {
    try {
      await _channel.invokeMethod('secureOn');
    } catch (_) {
      // Si falla (ej. en un dispositivo sin soporte), no rompe la app
    }
  }

  /// Desactiva FLAG_SECURE. Llamar en dispose.
  static Future<void> desactivar() async {
    try {
      await _channel.invokeMethod('secureOff');
    } catch (_) {}
  }
}
