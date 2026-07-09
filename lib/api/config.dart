// ── Configuración de la API ───────────────────────────────────────────────────
//
// La URL base se selecciona automáticamente según el sabor de compilación:
//   flutter run --dart-define=ENV=prod
//   flutter build apk --dart-define=ENV=prod
//
// En desarrollo (default): apunta al emulador Android (10.0.2.2 → localhost PC)
// En producción: apunta al servidor en DigitalOcean (HTTPS obligatorio)
class ApiConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const bool _esProd = _env == 'prod';

  static const String baseUrl = _esProd
      ? 'https://sicavs.villasdelsol.hn/api/v1'   // ← URL real al desplegar
      : 'http://10.0.2.2:5000/api/v1';              // ← emulador Android

  // Timeout generoso para fotos (upload multipart en conexión móvil)
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    // ngrok requiere este header para no mostrar su pantalla de aviso
    // (no tiene efecto en producción)
    'ngrok-skip-browser-warning': 'true',
  };
}
