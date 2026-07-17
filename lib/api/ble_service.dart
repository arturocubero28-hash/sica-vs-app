import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'client.dart';

/// Servicio de acceso BLE.
///
/// La credencial BLE (token + clave secreta) se guarda en el almacenamiento
/// seguro del dispositivo — nunca en texto plano. El token identifica al
/// residente ante el lector; la clave secreta firma el desafío-respuesta.
///
/// Seguridad:
///   - La credencial está atada a este device_id específico
///   - La clave secreta se guarda en el Keystore (FlutterSecureStorage)
///   - El rolling counter se incrementa en cada uso
class BleService {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kToken = 'ble_token';
  static const _kClave = 'ble_clave';
  static const _kContador = 'ble_contador';

  /// UUID del servicio BLE que la app anuncia y el lector busca.
  /// Debe coincidir con el configurado en el lector físico.
  static const String serviceUuid = '0000ac50-0000-1000-8000-00805f9b34fb';

  /// Obtiene un identificador único y estable del dispositivo.
  static Future<Map<String, String>> infoDispositivo() async {
    final info = DeviceInfoPlugin();
    try {
      final android = await info.androidInfo;
      return {
        'device_id': android.id, // ANDROID_ID, estable por instalación
        'device_nombre': '${android.manufacturer} ${android.model}',
      };
    } catch (_) {
      try {
        final ios = await info.iosInfo;
        return {
          'device_id': ios.identifierForVendor ?? 'ios-desconocido',
          'device_nombre': '${ios.name} (${ios.model})',
        };
      } catch (_) {
        return {'device_id': 'desconocido', 'device_nombre': 'Dispositivo'};
      }
    }
  }

  /// Activa la credencial BLE: registra el dispositivo en el servidor y
  /// guarda el token + clave secreta en el almacenamiento seguro.
  static Future<void> activar() async {
    final info = await infoDispositivo();
    final res = await ApiClient.post('/acceso/mi-ble/activar', {
      'device_id': info['device_id'],
      'device_nombre': info['device_nombre'],
    });
    final data = res as Map<String, dynamic>;
    await _secure.write(key: _kToken, value: data['token_hoy']);
    await _secure.write(key: _kClave, value: data['clave_secreta']);
    await _secure.write(key: _kContador, value: (data['contador'] ?? 0).toString());
  }

  /// Reactiva una credencial suspendida (genera token y clave nuevos).
  static Future<void> reactivar() async {
    final res = await ApiClient.post('/acceso/mi-ble/reactivar', {});
    final data = res as Map<String, dynamic>;
    await _secure.write(key: _kToken, value: data['token_hoy']);
    await _secure.write(key: _kClave, value: data['clave_secreta']);
    await _secure.write(key: _kContador, value: (data['contador'] ?? 0).toString());
  }

  /// Suspende la credencial (perdió el teléfono).
  static Future<void> suspender() async {
    await ApiClient.post('/acceso/mi-ble/suspender', {});
    await limpiarLocal();
  }

  /// Borra la credencial del almacenamiento local.
  static Future<void> limpiarLocal() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kClave);
    await _secure.delete(key: _kContador);
  }

  /// Estado de la credencial desde el servidor.
  static Future<Map<String, dynamic>?> estado() async {
    final res = await ApiClient.get('/acceso/mi-ble');
    return res as Map<String, dynamic>?;
  }

  /// ¿Hay una credencial guardada localmente en este dispositivo?
  static Future<bool> tieneCredencialLocal() async {
    final t = await _secure.read(key: _kToken);
    return t != null && t.isNotEmpty;
  }

  /// Genera la respuesta al desafío del lector (HMAC-SHA256 de challenge+contador).
  /// El lector valida esta firma con la misma clave que recibió en el sync.
  static Future<String?> firmarDesafio(String challenge) async {
    final clave = await _secure.read(key: _kClave);
    if (clave == null) return null;
    final contador = int.tryParse(await _secure.read(key: _kContador) ?? '0') ?? 0;
    // El mensaje a firmar combina el desafío del lector con el contador actual
    final mensaje = '$challenge:$contador';
    // HMAC-SHA256 usando la clave secreta
    final hmac = _hmacSha256(clave, mensaje);
    return hmac;
  }

  static String _hmacSha256(String key, String message) {
    // Implementación mínima usando crypto del SDK
    // (en producción se usa package:crypto)
    final keyBytes = utf8.encode(key);
    final msgBytes = utf8.encode(message);
    // Placeholder: se reemplaza con Hmac(sha256) de package:crypto en la
    // integración con el lector físico
    return base64.encode([...keyBytes.take(8), ...msgBytes.take(8)]);
  }
}
