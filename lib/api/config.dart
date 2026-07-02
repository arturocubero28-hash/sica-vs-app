// ── Configuración de la API ───────────────────────────────────────────────────
// Cambiá baseUrl a la URL real cuando vayas a producción.
class ApiConfig {
  // Desarrollo: URL de ngrok
  static const String baseUrl = 'https://diabetes-earflap-faction.ngrok-free.app/api/v1';

  // Producción (descomentar cuando tengas el servidor real):
  // static const String baseUrl = 'https://tudominio.com/api/v1';

  static const Duration timeout = Duration(seconds: 15);

  // Headers que ngrok requiere para no mostrar la pantalla de aviso
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
