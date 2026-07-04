import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maneja la recuperación cuando Android mata el proceso de la app al abrir
/// la cámara (común en teléfonos de gama baja como el Moto E15).
///
/// Estrategia (según la doc oficial de image_picker):
/// 1. El estado del registro en curso del guardia se guarda en disco ANTES
///    de abrir la cámara (qué visita, qué paso, qué fotos ya se tomaron).
/// 2. retrieveLostData() se llama al ARRANCAR la app (no en el initState de
///    una pantalla enterrada en tabs), que es donde la doc dice que debe ir.
/// 3. La foto recuperada + el estado guardado permiten restaurar el flujo
///    exactamente donde estaba.
class RecuperacionGuardia {
  static const _kEstado = 'guardia_registro_en_curso';
  static const _kFotoEnCurso = 'guardia_foto_en_curso';

  /// Guarda el estado del registro del guardia antes de abrir la cámara.
  static Future<void> guardarEstado(Map<String, dynamic> estado) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEstado, jsonEncode(estado));
  }

  /// Marca qué foto se está por tomar (id / placa / numero).
  static Future<void> marcarFotoEnCurso(String cual) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFotoEnCurso, cual);
  }

  static Future<String?> leerFotoEnCurso() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFotoEnCurso);
  }

  /// Lee el estado guardado del registro (o null si no hay).
  static Future<Map<String, dynamic>?> leerEstado() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kEstado);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Limpia el estado (al terminar o cancelar el registro).
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEstado);
    await prefs.remove(_kFotoEnCurso);
  }

  /// Recupera la foto que Android perdió al matar el proceso.
  /// Se llama al arrancar la app. Devuelve la ruta del archivo o null.
  static Future<String?> recuperarFotoPerdida() async {
    try {
      final picker = ImagePicker();
      final perdida = await picker.retrieveLostData();
      if (perdida.isEmpty) return null;
      if (perdida.file != null) return perdida.file!.path;
      if (perdida.files != null && perdida.files!.isNotEmpty) {
        return perdida.files!.first.path;
      }
    } catch (_) {}
    return null;
  }
}
