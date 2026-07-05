import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maneja la recuperación del comprobante de pago cuando Android mata el
/// proceso al abrir la cámara (común en teléfonos de poca RAM como el Moto E15).
///
/// Estrategia: persiste en disco qué cuota/abono se está pagando ANTES de
/// abrir la cámara. Si Android mata el proceso, al reabrir la app detecta
/// que hay una subida pendiente, recupera la foto con retrieveLostData() y
/// completa la subida automáticamente.
class RecuperacionComprobante {
  static const _kPendiente = 'comprobante_pendiente';

  /// Guarda el contexto de la subida antes de abrir la cámara.
  static Future<void> guardar({
    required String id,
    required double monto,
    required String tipo, // 'cuota' o 'abono'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendiente, jsonEncode({
      'id': id,
      'monto': monto,
      'tipo': tipo,
    }));
  }

  /// Lee el contexto de una subida pendiente (o null si no hay).
  static Future<Map<String, dynamic>?> leerPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendiente);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Limpia el estado (al completar o cancelar la subida).
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendiente);
  }

  /// Recupera la foto perdida por Android. Se llama al arrancar la app.
  static Future<File?> recuperarFotoPerdida() async {
    try {
      final picker = ImagePicker();
      final perdida = await picker.retrieveLostData();
      if (perdida.isEmpty) return null;
      if (perdida.file != null) return File(perdida.file!.path);
      if (perdida.files != null && perdida.files!.isNotEmpty) {
        return File(perdida.files!.first.path);
      }
    } catch (_) {}
    return null;
  }
}
