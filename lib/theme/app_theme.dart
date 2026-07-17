import 'package:flutter/material.dart';

// ── Colores de marca ──────────────────────────────────────────────────────────
class AppColors {
  static const azul      = Color(0xFF022E45);
  static const azul2     = Color(0xFF0A4A6E);
  static const naranja   = Color(0xFFF48723);
  static const amarillo  = Color(0xFFF5C518);
  static const gris      = Color(0xFF5B6B78);
  static const grisCl    = Color(0xFFF4F7FB);
  static const borde     = Color(0xFFE3E9F2);
  static const verde     = Color(0xFF1D8A4A);
  static const rojo      = Color(0xFFC0392B);
  static const amber     = Color(0xFFD89000);
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
    appBarTheme: const AppBarTheme(
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
        borderSide: const BorderSide(color: AppColors.azul, width: 2),
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
