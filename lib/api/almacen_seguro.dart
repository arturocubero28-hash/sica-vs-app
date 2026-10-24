import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lectura del almacenamiento cifrado que NUNCA deja la app trabada.
///
/// Día 71 — la app se quedaba pensando en la pantalla de inicio después de
/// reinstalarla. El registro del teléfono mostraba BAD_DECRYPT al leer el
/// token: Android restauró desde su copia de seguridad el archivo cifrado,
/// pero la llave que lo cifraba (que vive en el Keystore y nunca se
/// respalda) ya era otra. La lectura lanzaba una excepción y el arranque
/// nunca seguía.
///
/// Un dato que ya no se puede descifrar no sirve para nada: se borra el
/// archivo completo y se devuelve null. Para la app es lo mismo que no
/// haber iniciado sesión nunca: va al login.
Future<String?> leerSeguro(FlutterSecureStorage almacen, String llave) async {
  try {
    return await almacen.read(key: llave);
  } catch (e) {
    debugPrint('Almacen cifrado ilegible ($llave): $e. Se reinicia.');
    try {
      await almacen.deleteAll();
    } catch (_) {}
    return null;
  }
}
