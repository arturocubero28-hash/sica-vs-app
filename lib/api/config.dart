// ── Configuración de la API ───────────────────────────────────────────────────
//
// La URL base se selecciona según el sabor de compilación:
//
//   flutter run                          → dev  (túnel ngrok, teléfono físico)
//   flutter run --dart-define=ENV=emu    → emulador de Android
//   flutter build apk --dart-define=ENV=prod → producción
//
// NOTA IMPORTANTE (Día 41): el default era 10.0.2.2, que es una dirección
// especial que SOLO existe dentro del emulador de Android — es su alias para
// llegar a localhost de la PC. En un teléfono físico no resuelve a nada, y el
// resultado es "no se puede conectar". Ahora el default apunta al túnel, que
// funciona en ambos casos, y el emulador queda detrás de --dart-define=ENV=emu
// para quien lo necesite.
class ApiConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const bool _esProd = _env == 'prod';
  static const bool _esEmulador = _env == 'emu';

  // Túnel ngrok de desarrollo. Cambia si ngrok reasigna la URL —
  // ver la nota al final de este archivo sobre el dominio estático.
  static const String _tunelDev =
      'https://diabetes-earflap-faction.ngrok-free.dev/api/v1';

  static const String baseUrl = _esProd
      ? 'https://sicavs.villasdelsol.hn/api/v1'  // ← al desplegar en DigitalOcean
      : _esEmulador
          ? 'http://10.0.2.2:5000/api/v1'        // ← emulador Android
          : _tunelDev;                            // ← teléfono físico (default)

  // Timeout generoso para fotos (upload multipart en conexión móvil)
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    // ngrok muestra una pantalla de advertencia en la primera visita de cada
    // cliente; sin este header la app recibiría ese HTML en vez del JSON y
    // fallaría al parsearlo. No tiene efecto en producción.
    'ngrok-skip-browser-warning': 'true',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SOBRE LA URL DE NGROK
//
// El plan gratuito de ngrok puede reasignar la URL al reiniciar el túnel, y
// cada cambio obliga a editar este archivo y recompilar la app. ngrok ofrece
// un dominio estático gratuito (uno por cuenta) que elimina ese problema:
//
//   1. Panel de ngrok → Domains → reclamar el dominio gratuito
//   2. Levantar el túnel con:  ngrok http --domain=TU-DOMINIO.ngrok-free.app 5173
//   3. Poner esa URL fija en _tunelDev, y no volver a tocarla
//
// Al desplegar en DigitalOcean con dominio propio, ngrok deja de hacer falta.
// ─────────────────────────────────────────────────────────────────────────────
