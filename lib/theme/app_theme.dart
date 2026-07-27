import 'package:flutter/material.dart';

// ── Colores de marca ──────────────────────────────────────────────────────────
//
// Día 47 — colores personalizables por residencial. azul/azul2/naranja
// pasan de `static const` a `static` (variables normales, reasignables) —
// en Dart, `const` significa fijo en tiempo de COMPILACIÓN, así que no hay
// forma de que un color elegido por el admin (que llega en tiempo de
// EJECUCIÓN, después de iniciar sesión) reemplace un valor const. El resto
// de los colores (gris, verde, rojo, etc.) sí quedan const de verdad — no
// los define el admin, no necesitan ser reasignables.
//
// AppColors.notifier avisa a la app cuando estos valores cambian, para que
// MaterialApp reconstruya su tema (ver main.dart) — sin esto, aunque el
// valor de la variable cambiara, los widgets ya dibujados no se enterarían.
class AppColors {
  static Color azul     = const Color(0xFF022E45);
  static Color azul2    = const Color(0xFF0A4A6E);
  static Color naranja  = const Color(0xFFF48723);
  static const amarillo = Color(0xFFF5C518);
  static const gris     = Color(0xFF5B6B78);
  static const grisCl   = Color(0xFFF4F7FB);
  static const borde    = Color(0xFFE3E9F2);
  static const verde    = Color(0xFF1D8A4A);
  static const rojo     = Color(0xFFC0392B);
  static const amber    = Color(0xFFD89000);

  // Valores de fábrica exactos — para el caso "sin personalizar" se usan
  // estos tal cual (no una fórmula derivada), garantizando cero diferencia
  // visual frente a como se veía la app antes de este cambio. Mismo
  // criterio que ya se usó en el panel web (utils/colores.ts).
  //
  // PÚBLICOS a propósito: login_screen.dart y splash_screen.dart (pantallas
  // ANTES de iniciar sesión) los usan en vez de azul/naranja — misma
  // decisión que en el panel web (el login no se personaliza, es la marca
  // fija del producto, y antes de loguearse no hay forma de saber de qué
  // residencial serían los colores).
  static const Color azulDeFabrica = Color(0xFF022E45);
  static const Color naranjaDeFabrica = Color(0xFFF48723);
  static const Color _azul2DeFabrica = Color(0xFF0A4A6E);

  static final ColorNotifier notifier = ColorNotifier();

  /// Aplica los colores de la residencial. Se llama una vez al resolver la
  /// sesión (ver login_screen.dart / home_screen.dart, mismo punto donde ya
  /// se aplican nombre y logo — Día 46). Silencioso ante valores mal
  /// formados: se ignoran y la app se queda con lo que tenía.
  static void actualizar({String? primario, String? secundario}) {
    var huboCambio = false;
    final p = _parsearHex(primario);
    if (p != null) {
      azul = p;
      // El tono "claro" (azul2, usado en appBarTheme/degradados) se deriva
      // aclarando el primario — salvo que sea EXACTAMENTE el color de
      // fábrica, en cuyo caso se usa el valor de fábrica real (no es una
      // relación matemática limpia, fue elegido a mano en el diseño
      // original). Mismo criterio que la web.
      azul2 = (p.value == azulDeFabrica.value) ? _azul2DeFabrica : _aclarar(p, 0.35);
      huboCambio = true;
    }
    final s = _parsearHex(secundario);
    if (s != null) { naranja = s; huboCambio = true; }
    if (huboCambio) notifier.notificar();
  }

  /// Convierte "#RRGGBB" a Color. null si el formato no es válido — nunca
  /// deja que un dato mal formado llegue a pintar la pantalla.
  static Color? _parsearHex(String? hex) {
    if (hex == null) return null;
    final limpio = hex.replaceFirst('#', '').trim();
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(limpio)) return null;
    final valor = int.parse(limpio, radix: 16);
    return Color(0xFF000000 | valor);
  }

  /// Aclara un color hacia blanco un porcentaje (0 a 1), para el tono de
  /// hover/degradado cuando no hay un valor de fábrica exacto que usar.
  static Color _aclarar(Color base, double cantidad) {
    int canal(int c) => (c + (255 - c) * cantidad).round();
    return Color.fromARGB(
      255,
      canal(base.red),
      canal(base.green),
      canal(base.blue),
    );
  }
}

/// Notificador mínimo (ChangeNotifier del SDK, sin paquetes extra) para que
/// MaterialApp se reconstruya cuando los colores cambian. Ver main.dart.
class ColorNotifier extends ChangeNotifier {
  void notificar() => notifyListeners();
}

// ── Radios de esquina, centralizados para que todo el sistema respire igual ──
class AppRadius {
  static const sm = 12.0;   // botones, chips, inputs
  static const md = 16.0;   // tarjetas de contenido
  static const lg = 24.0;   // encabezados, hojas modales, superficies grandes
}

// ── Tema principal ────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.azul,
      primary: AppColors.azul,
      secondary: AppColors.naranja,
      surface: Colors.white,
      error: AppColors.rojo,
    ),
    scaffoldBackgroundColor: AppColors.grisCl,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.azul,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.naranja,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.azul, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.borde, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11.5,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
      )),
    ),
  );
}

/// BLE-08 (Auditoría Día 35): bandera de funcionalidad — hoy en false
/// porque no existe hardware lector real (HID Signo u equivalente) ni
/// el protocolo de desafío-respuesta con la clave secreta implementado
/// del lado del teléfono. flutter_blue_plus está en pubspec.yaml pero
/// NUNCA se usa en el código — es solo la dependencia preparada, no hay
/// ningún advertising ni escaneo BLE real ocurriendo.
///
/// Mientras esté en false, la app SIGUE permitiendo registrar la
/// credencial BLE (útil: deja el dato listo en la base para cuando el
/// hardware llegue), pero NINGÚN texto le dice al residente que acercarse
/// a una entrada abre algo — antes la pantalla decía "Acceso Bluetooth
/// activo" con una animación de radar, dando a entender que la función
/// ya abría las trancas físicas, cuando en realidad no hacía nada.
///
/// Cuando el hardware y el protocolo real estén listos, cambiar esto a
/// true habilita automáticamente los textos y la animación de "activo"
/// en tarjeta_virtual_screen.dart — no hace falta tocar nada más ahí.
const bool bleAccesoFisicoListo = false;
