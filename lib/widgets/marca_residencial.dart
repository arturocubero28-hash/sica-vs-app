import 'dart:math' as math;
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

/// Entrada animada de la app (Día 71): el logo aparece creciendo, detrás se
/// enciende un resplandor de sol que late suave, los rayos giran despacio y
/// el nombre aparece línea por línea.
///
/// [entrada] corre una sola vez de 0 a 1 (la aparición). [giro] se repite
/// sin fin (rayos y latido). Si el teléfono tiene activado "quitar
/// animaciones" por accesibilidad, quien la usa debe dejar [entrada] en 1.
class MarcaAnimada extends StatelessWidget {
  final Animation<double> entrada;
  final Animation<double> giro;
  final double tamLogo;
  const MarcaAnimada({
    super.key,
    required this.entrada,
    required this.giro,
    this.tamLogo = 108,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([entrada, giro]),
      builder: (context, _) {
        final t = entrada.value;
        double tramo(double desde, double hasta) =>
            ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);

        final logo = Curves.easeOutBack.transform(tramo(0.0, 0.45));
        final brillo = Curves.easeOut.transform(tramo(0.15, 0.65));
        final rayos = Curves.easeOut.transform(tramo(0.30, 0.85));
        // Latido suave: tres por cada vuelta completa de los rayos.
        final latido = 0.5 + 0.5 * math.sin(giro.value * 2 * math.pi * 3);
        final escena = tamLogo * 2.5;

        Widget linea(int i, Widget hijo) {
          final v = Curves.easeOutCubic.transform(tramo(0.45 + i * 0.12, 0.75 + i * 0.12));
          return Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: hijo),
          );
        }

        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: escena, height: escena,
            child: Stack(alignment: Alignment.center, children: [
              // Rayos del sol, girando despacio
              Opacity(
                opacity: rayos,
                child: Transform.rotate(
                  angle: giro.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size.square(escena),
                    painter: _RayosSol(AppColors.amarillo.withOpacity(0.55)),
                  ),
                ),
              ),
              // Resplandor que late
              Container(
                width: tamLogo * (1.55 + 0.12 * latido) * (0.6 + 0.4 * brillo),
                height: tamLogo * (1.55 + 0.12 * latido) * (0.6 + 0.4 * brillo),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.amarillo.withOpacity((0.55 + 0.15 * latido) * brillo),
                    AppColors.naranjaDeFabrica.withOpacity(0.28 * brillo),
                    AppColors.naranjaDeFabrica.withOpacity(0.0),
                  ], stops: const [0.35, 0.7, 1.0]),
                ),
              ),
              // Logo
              Opacity(
                opacity: tramo(0.0, 0.25),
                child: Transform.scale(
                  scale: 0.55 + 0.45 * logo,
                  child: Container(
                    width: tamLogo, height: tamLogo,
                    padding: EdgeInsets.all(tamLogo * 0.14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amarillo.withOpacity(0.35 * brillo),
                          blurRadius: 30 + 10 * latido,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.wb_sunny_rounded,
                          color: AppColors.naranjaDeFabrica, size: tamLogo * 0.5),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          linea(0, Text('RESIDENCIAL',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 4,
                color: Colors.white.withOpacity(0.75),
              ))),
          const SizedBox(height: 2),
          linea(1, const Text('Villas del Sol',
              style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15,
              ))),
          const SizedBox(height: 10),
          linea(2, Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.naranjaDeFabrica,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('App',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,
                )),
          )),
        ]);
      },
    );
  }
}

/// Doce rayos alrededor del logo, alternando largos y cortos.
class _RayosSol extends CustomPainter {
  final Color color;
  _RayosSol(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final pincel = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.022;
    for (var i = 0; i < 12; i++) {
      final angulo = i * math.pi / 6;
      final largo = i.isEven ? 0.47 : 0.42;
      final dir = Offset(math.cos(angulo), math.sin(angulo));
      canvas.drawLine(
        centro + dir * (size.width * 0.36),
        centro + dir * (size.width * largo),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_RayosSol viejo) => viejo.color != color;
}
