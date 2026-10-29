import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'almacen_seguro.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Día 66 — credenciales guardadas para el INICIO DE SESIÓN RÁPIDO con huella.
///
/// Día 72 — dos funciones de huella, separadas a propósito:
///   · Inicio de sesión rápido (esta clase): opcional y por cuenta. Sirve
///     para volver a ENTRAR después de haber cerrado sesión, sin escribir
///     la contraseña. La contraseña queda cifrada en este teléfono.
///   · Desbloqueo con huella (bloqueo_biometrico.dart): para cuando la
///     sesión sigue abierta y la persona vuelve a la app.
/// Antes activar() prendía las dos juntas; ahora cada una se elige aparte.
///
/// Estrategia de almacenamiento:
/// - Email: SharedPreferences (no sensible, persiste siempre, visible en login)
/// - Contraseña: FlutterSecureStorage sin encryptedSharedPreferences
///   (evita que Samsung borre los datos al limpiar EncryptedSharedPreferences)
/// - Flag activo: SharedPreferences (persiste entre sesiones)
class CredencialesGuardadas {
  // Día 70 — ESTA CONFIGURACIÓN CAUSABA PÉRDIDA DE CREDENCIALES.
  //
  // Antes acá decía `encryptedSharedPreferences: false` mientras que
  // AuthStorage (en client.dart) usa `true`. Dos instancias de
  // FlutterSecureStorage con opciones DISTINTAS, y -- esto es lo que no
  // era obvio -- escribiendo sobre el MISMO archivo de respaldo, porque
  // el plugin usa un nombre por defecto si no se le da otro.
  //
  // El resultado: según cuál instancia tocara el almacén último, lo
  // escrito por la otra quedaba ilegible. Se veía así: el correo seguía
  // apareciendo (vive en SharedPreferences, que nadie pisa) pero la
  // contraseña volvía nula. O sea, el botón "Entrar con huella" seguía
  // ofreciéndose para una cuenta cuya contraseña ya no existía.
  //
  // Arreglo: misma opción que AuthStorage, y ADEMÁS un archivo propio
  // (sharedPreferencesName) para que las dos no puedan pisarse nunca más,
  // aunque alguien cambie una de las dos configuraciones en el futuro.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'sica_credenciales_biometricas',
      resetOnError: true,
    ),
  );

  static const _keyPass   = 'sica_cred_pass';
  static const _keyEmail  = 'sica_cred_email_prefs';   // en SharedPreferences
  static const _keyActivo = 'sica_cred_activo_prefs';  // en SharedPreferences

  /// ¿Hay credenciales guardadas para el login biométrico?
  static Future<bool> estaActivo() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_keyActivo) ?? false;
    if (!activo) return false;
    final email = prefs.getString(_keyEmail) ?? '';
    return email.isNotEmpty;
  }

  /// Guardar credenciales y activar el login biométrico.
  ///
  /// Día 69 — hay UN SOLO casillero por dispositivo: guardar una cuenta nueva
  /// sobrescribe a la anterior ("gana la última"). Quien decide si llamar a
  /// este método es login_screen, que primero compara contra [getEmail] y le
  /// pide confirmación al usuario cuando el guardado es un reemplazo —
  /// nunca se pisa una cuenta en silencio.
  static Future<void> activar(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyActivo, true);
    // Solo la contraseña va al almacenamiento seguro
    await _secure.write(key: _keyPass, value: password);
  }

  /// ¿Esta cuenta ya tiene el inicio rápido guardado en este teléfono?
  static Future<bool> esDe(String email) async {
    if (!await estaActivo()) return false;
    final guardado = await getEmail();
    return guardado != null && guardado.toLowerCase() == email.toLowerCase();
  }

  /// Recuperar el email guardado (para mostrarlo en el formulario).
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    return (email != null && email.isNotEmpty) ? email : null;
  }

  /// Recuperar email y contraseña para el login automático.
  /// Solo llamar DESPUÉS de autenticar con biometría.
  static Future<({String email, String password})?> getCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail) ?? '';
    final pass  = await leerSeguro(_secure, _keyPass);
    if (email.isEmpty || pass == null) return null;
    return (email: email, password: pass);
  }

  /// Borrar todo — solo al desactivar biometría explícitamente.
  /// NO se llama al cerrar sesión normal.
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyActivo);
    await _secure.delete(key: _keyPass);
  }
}
