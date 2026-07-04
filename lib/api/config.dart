// ── Configuración de la API ───────────────────────────────────────────────────
// Cambiá baseUrl a la URL real cuando vayas a producción.
class ApiConfig {
  // Desarrollo: URL de ngrok
  // Emulador Android: 10.0.2.2 apunta al localhost de tu PC
  static const String baseUrl = 'http://10.0.2.2:5000/api/v1';

  // Producción (descomentar cuando tengas el servidor real):
  // static const String baseUrl = 'https://tudominio.com/api/v1';

  static const Duration timeout = Duration(seconds: 30);  // más tiempo para fotos en base64

  // Headers que ngrok requiere para no mostrar la pantalla de aviso
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
