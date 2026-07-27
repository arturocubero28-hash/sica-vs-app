import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'config.dart';
import 'models.dart';

// ── Nombre/logo de la residencial (Día 46) ─────────────────────────────────────
/// Caché del nombre y logo de la residencial del usuario logueado.
///
/// El NOMBRE vive en memoria (se recarga cada apertura de la app, es una
/// consulta liviana). El LOGO se descarga UNA SOLA VEZ y se guarda en el
/// almacenamiento persistente del dispositivo (sobrevive a reinicios de la
/// app; solo desaparece si se desinstala o se borran los datos) — así la
/// marca de agua y demás usos del logo no vuelven a pedir la red después de
/// la primera vez.
///
/// Si por algún motivo no se pudo cargar todavía, [nombre] devuelve
/// "tu residencial" como texto neutro — nunca queda vacío ni asume un nombre
/// que puede no ser el correcto. [logoUrl] es null si la residencial no tiene
/// logo propio subido — en ese caso las pantallas deben mostrar su ícono de
/// respaldo (el escudo azul), no asumir el logo de otra residencial.
class ResidencialCache {
  static String? _nombre;
  static String? _logoArchivo;

  static String get nombre => _nombre ?? 'tu residencial';

  /// URL completa y autenticable del logo, o null si no hay logo subido.
  static String? get logoUrl => _logoArchivo == null
      ? null
      : '${ApiConfig.baseUrl}/unidades/mi-residencial/logo/$_logoArchivo';

  static void set(String? nombre, {String? logoArchivo}) {
    if (nombre != null && nombre.trim().isNotEmpty) _nombre = nombre;
    if (logoArchivo != null && logoArchivo.trim().isNotEmpty) {
      _logoArchivo = logoArchivo;
    }
  }

  /// Limpia el nombre/logo EN MEMORIA (no borra los archivos ya descargados
  /// en disco — esos quedan cacheados para la próxima vez que se use esa
  /// residencial). Se llama al cerrar sesión, para que si otra cuenta inicia
  /// sesión enseguida, ninguna pantalla en transición pueda mostrar por un
  /// instante el nombre/logo de la cuenta que se acaba de ir.
  static void clear() {
    _nombre = null;
    _logoArchivo = null;
  }

  /// Ruta local del logo de ESTE archivo remoto en particular. Se incluye el
  /// nombre del archivo del servidor para que, si el dispositivo se usa con
  /// distintas cuentas/residenciales (como en pruebas), cada logo tenga su
  /// propio archivo en disco sin pisarse entre sí.
  static Future<File> _archivoLocal(String logoArchivo) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/residencial_logo_$logoArchivo');
  }

  /// Devuelve el archivo local del logo si ya fue descargado antes, o null si
  /// todavía no existe en disco (primera vez, o el logo cambió).
  static Future<File?> logoLocal() async {
    if (_logoArchivo == null) return null;
    final file = await _archivoLocal(_logoArchivo!);
    return await file.exists() ? file : null;
  }

  /// Descarga el logo y lo guarda en disco, PERO SOLO si todavía no existe
  /// localmente — así se descarga una única vez por logo. Se llama en
  /// segundo plano después del login; si falla (sin red, etc.) no rompe
  /// nada, simplemente se reintentará la próxima vez que se llame a esto.
  static Future<void> asegurarLogoDescargado() async {
    if (_logoArchivo == null) return;
    final file = await _archivoLocal(_logoArchivo!);
    if (await file.exists()) return; // ya en disco, no hace falta bajar de nuevo
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(Uri.parse(logoUrl!), headers: headers);
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
      }
    } catch (_) {
      // Sin conexión u otro error: se reintenta en la próxima llamada porque
      // el archivo nunca se llegó a crear.
    }
  }
}

// ── Gestión del token ─────────────────────────────────────────────────────────
/// El JWT de sesión se guarda en el Keystore/Keychain del sistema operativo
/// (FlutterSecureStorage) para que otras apps no puedan leerlo.
///
/// Los datos no sensibles (rol, info básica del usuario) siguen en
/// SharedPreferences porque no contienen credenciales.
class AuthStorage {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'sica_token';
  static const _rolKey   = 'sica_rol';
  static const _userKey  = 'sica_user';

  static Future<void> guardar(String token, String rol, Map user) async {
    await _secure.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rolKey, rol);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<String?> getToken() async {
    return await _secure.read(key: _tokenKey);
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
    await _secure.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rolKey);
    await prefs.remove(_userKey);
  }

  /// AUTH-02 (Auditoría Día 35): punto ÚNICO de cierre de sesión.
  ///
  /// Antes cada pantalla implementaba su propio logout llamando
  /// directamente a AuthStorage.limpiar() — eso solo borra el token del
  /// teléfono, pero el JWT sigue siendo VÁLIDO en el servidor hasta que
  /// expira solo. Si alguien capturó ese token antes (red comprometida,
  /// dispositivo perdido y recuperado, etc.), seguía pudiendo usarlo
  /// después de que el dueño "cerrara sesión".
  ///
  /// Ahora: se llama a POST /auth/logout (que ya existía en el backend,
  /// simplemente nunca se usaba) para revocar el token en el servidor
  /// ANTES de borrar el almacenamiento local. Si no hay conexión, se
  /// limpia igual el estado local — el usuario no debe quedar atrapado
  /// sin poder cerrar sesión por falta de red, pero se intenta la
  /// revocación primero siempre que se pueda.
  ///
  /// El desregistro de FCM sigue siendo responsabilidad de quien llama
  /// (residente_shell, guardia_shell, etc.) porque NotificacionesService
  /// ya importa este archivo — importarlo acá crearía una dependencia
  /// circular. El orden correcto en cada pantalla es:
  ///   await NotificacionesService.desregistrar();
  ///   await AuthStorage.cerrarSesion();
  static Future<void> cerrarSesion() async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {
      // Sin conexión o token ya inválido — no bloquear el logout local
    }
    ResidencialCache.clear();
    await limpiar();
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

  // Día 46: headers públicos (con el Authorization ya resuelto) para usar en
  // Image.network al pedir el logo de la residencial — ver ResidencialCache.
  static Future<Map<String, String>> authHeaders() => _headers();

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

  /// Igual que postMultipart, pero acepta varios archivos bajo el mismo
  /// nombre de campo (ej. varios comprobantes de un mismo pago, cuando el
  /// residente depositó en dos partes).
  static Future<dynamic> postMultipartVarios(
      String path, List<File> archivos, Map<String, String> fields) async {
    final token = await AuthStorage.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}$path'));
    req.headers.addAll({
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    });
    req.fields.addAll(fields);
    for (final archivo in archivos) {
      req.files.add(await http.MultipartFile.fromPath('comprobante', archivo.path));
    }
    final streamed = await req.send().timeout(ApiConfig.timeout);
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  /// Registra acceso del guardia subiendo las fotos como archivos multipart.
  /// Evita el límite de 1MB de ngrok al no usar base64.
  static Future<dynamic> registrarAcceso({
    required String token,
    String? placaObservada,
    File? fotoId,
    File? fotoPlaca,
    File? fotoNumero,
  }) async {
    final authToken = await AuthStorage.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}/visitas/accesos/visita'));
    req.headers.addAll({
      'Authorization': 'Bearer $authToken',
      'ngrok-skip-browser-warning': 'true',
    });
    // ACCESS-03: se envía el TOKEN del QR, no un visita_id suelto. El
    // servidor vuelve a validar todo (revocación, expiración, uso previo)
    // dentro de una transacción con bloqueo de fila — ya no es posible
    // saltarse la validación llamando este endpoint directamente.
    req.fields['token'] = token;
    if (placaObservada != null && placaObservada.isNotEmpty) {
      // ACCESS-04: la placa que el guardia observó/digitó viendo el
      // vehículo, separada de la que el residente declaró al crear la
      // visita. El servidor guarda ambas y avisa si no coinciden.
      req.fields['placa_observada'] = placaObservada;
    }
    if (fotoId != null) {
      req.files.add(await http.MultipartFile.fromPath('foto_identidad', fotoId.path));
    }
    if (fotoPlaca != null) {
      req.files.add(await http.MultipartFile.fromPath('foto_placa', fotoPlaca.path));
    }
    if (fotoNumero != null) {
      req.files.add(await http.MultipartFile.fromPath('foto_numero_asignado', fotoNumero.path));
    }
    final streamed = await req.send().timeout(ApiConfig.timeout);
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['data'] ?? body;
    }
    // 401: token inválido o expirado → limpiar sesión local
    if (res.statusCode == 401) {
      AuthStorage.limpiar(); // async fire-and-forget — no bloquea
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

  // Día 46: nombre/logo de la residencial del usuario logueado. Antes la app
  // tenía "Villas del Sol" escrito directo en varias pantallas — un usuario
  // de otra residencial veía ese nombre igual. Mismo endpoint que ya usa el
  // panel web (existe desde el Día 37).
  static Future<Map<String, dynamic>?> miResidencial() async {
    final res = await ApiClient.get('/unidades/mi-residencial');
    if (res == null) return null;
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

  static Future<void> subirComprobante(String cuotaId, List<File> archivos, double monto) async {
    await ApiClient.postMultipartVarios(
      '/cuotas/mias/$cuotaId/pagar',
      archivos,
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
