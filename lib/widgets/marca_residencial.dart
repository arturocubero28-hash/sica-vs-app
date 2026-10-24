import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Nombre visible de la app. Un solo lugar para cambiarlo.
const String kNombreApp = 'Residencial Villas del Sol App';

/// Fondo de las pantallas de entrada (inicio y login): degradado azul de la
/// residencial con dos círculos suaves que evocan el sol del logo.
///
/// Usa los colores DE FÁBRICA a propósito: estas pantallas se ven antes de
/// iniciar sesión, cuando todavía no se cargaron los colores configurados.
class FondoMarca extends StatelessWidget {
  final Widget child;
  const FondoMarca({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.azulDeFabrica, Color(0xFF0A4A6E)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -90, right: -70,
          child: _circulo(260, AppColors.naranjaDeFabrica.withOpacity(0.18)),
        ),
        Positioned(
          top: 40, right: 60,
          child: _circulo(70, AppColors.amarillo.withOpacity(0.16)),
        ),
        Positioned(
          bottom: -120, left: -90,
          child: _circulo(280, Colors.white.withOpacity(0.05)),
        ),
        child,
      ]),
    );
  }

  Widget _circulo(double d, Color c) =>
      Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

/// Logo y nombre: "RESIDENCIAL" / "Villas del Sol" / [App].
class MarcaResidencial extends StatelessWidget {
  final double tamLogo;
  const MarcaResidencial({super.key, this.tamLogo = 96});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: tamLogo, height: tamLogo,
        padding: EdgeInsets.all(tamLogo * 0.14),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.wb_sunny_rounded, color: AppColors.naranjaDeFabrica, size: tamLogo * 0.5),
        ),
      ),
      const SizedBox(height: 22),
      Text('RESIDENCIAL',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 4,
            color: Colors.white.withOpacity(0.75),
          )),
      const SizedBox(height: 2),
      const Text('Villas del Sol',
          style: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15,
          )),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.naranjaDeFabrica,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('App',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,
            )),
      ),
    ]);
  }
}
