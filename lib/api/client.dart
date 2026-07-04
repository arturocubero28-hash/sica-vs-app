import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';

// ── Gestión del token ─────────────────────────────────────────────────────────
class AuthStorage {
  static const _tokenKey = 'sica_token';
  static const _rolKey   = 'sica_rol';
  static const _userKey  = 'sica_user';

  static Future<void> guardar(String token, String rol, Map user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_rolKey, rol);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rolKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_userKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_rolKey);
    await prefs.remove(_userKey);
  }
}

// ── Cliente HTTP base ─────────────────────────────────────────────────────────
class ApiClient {
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = Map<String, String>.from(ApiConfig.headers);
    if (auth) {
      final token = await AuthStorage.getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<dynamic> get(String path) async {
    final res = await http
        .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers())
        .timeout(ApiConfig.timeout);
    return _parse(res);
  }

  static Future<dynamic> post(String path, Map body, {bool auth = true}) async {
    final res = await http
        .post(Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _parse(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http
        .delete(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers())
        .timeout(ApiConfig.timeout);
    return _parse(res);
  }

  static Future<dynamic> postMultipart(
      String path, File file, Map<String, String> fields) async {
    final token = await AuthStorage.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}$path'));
    req.headers.addAll({
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    });
    req.fields.addAll(fields);
    req.files.add(await http.MultipartFile.fromPath('comprobante', file.path));
    final streamed = await req.send().timeout(ApiConfig.timeout);
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['data'] ?? body;
    }
    final err = body['error'];
    throw ApiException(
      code:    err?['code'] ?? 'ERROR',
      message: err?['message'] ?? 'Error desconocido',
    );
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  ApiException({required this.code, required this.message});
  @override
  String toString() => message;
}

// ── Endpoints de autenticación ────────────────────────────────────────────────
class AuthApi {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await ApiClient.post(
      '/auth/login',
      {'email': email, 'password': password},
      auth: false,
    );
    return res as Map<String, dynamic>;
  }
}

// ── Endpoints del residente ───────────────────────────────────────────────────
class ResidenteApi {
  static Future<Map<String, dynamic>> misCuotas() async {
    final res = await ApiClient.get('/cuotas/mias');
    return res as Map<String, dynamic>;
  }

  static Future<List<dynamic>> misVisitas() async {
    final res = await ApiClient.get('/visitas/mias');
    return res as List<dynamic>;
  }

  static Future<Map<String, dynamic>> crearVisitaUnica(Map body) async {
    final res = await ApiClient.post('/visitas', body);
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> crearVisitaRecurrente(Map body) async {
    final res = await ApiClient.post('/visitas', {...body, 'tipo': 'recurrente'});
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> crearRepartidor(Map body) async {
    final res = await ApiClient.post('/visitas', {...body, 'tipo': 'repartidor'});
    return res as Map<String, dynamic>;
  }

  static Future<void> subirComprobante(String cuotaId, File archivo, double monto) async {
    await ApiClient.postMultipart(
      '/cuotas/mias/$cuotaId/pagar',
      archivo,
      {'metodo': 'transferencia', 'monto': monto.toStringAsFixed(2)},
    );
  }

  static Future<void> subirComprobanteAbono(String abonoId, File archivo, double monto) async {
    await ApiClient.postMultipart(
      '/cuotas/abonos/$abonoId/pagar',
      archivo,
      {'metodo': 'transferencia', 'monto': monto.toStringAsFixed(2)},
    );
  }

  static Future<String> urlRecibo(String pagoId) async {
    final token = await AuthStorage.getToken();
    return '${ApiConfig.baseUrl}/recibos/$pagoId?_auth=$token';
  }
}

// ── Endpoints del guardia ─────────────────────────────────────────────────────
class GuardiaApi {
  static Future<Map<String, dynamic>> validarQr(
      String qrData, List<String> fotos) async {
    final res = await ApiClient.post('/visitas/qr/validar', {
      'qr_data': qrData,
      'fotos': fotos,
    });
    return res as Map<String, dynamic>;
  }

  static Future<List<dynamic>> historialAccesos({int pagina = 1}) async {
    final res = await ApiClient.get('/visitas/accesos/recientes?pagina=$pagina');
    return res as List<dynamic>;
  }
}
