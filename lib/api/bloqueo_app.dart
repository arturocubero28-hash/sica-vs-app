import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import '../screens/bloqueo_screen.dart';
import 'bloqueo_biometrico.dart';
import 'client.dart';

/// Día 72 — bloqueo al volver a la app, estilo WhatsApp.
///
/// Antes la huella se pedía solo al ARRANCAR la app desde cero. Android
/// casi nunca cierra la app de verdad: al tocar el ícono otra vez, la app
/// volvía del segundo plano y entraba directo, sin huella. Ahora, si la
/// persona activó el desbloqueo con huella y la app estuvo en segundo plano
/// más de [margen], al volver se tapa todo con la pantalla de bloqueo.
///
/// El margen evita pedir la huella por salir un momento (contestar un
/// mensaje, sacar la foto de un comprobante con la cámara).
class GuardianBloqueo with WidgetsBindingObserver {
  GuardianBloqueo._();
  static final GuardianBloqueo instancia = GuardianBloqueo._();

  static const Duration margen = Duration(minutes: 1);

  DateTime? _enSegundoPlanoDesde;
  bool _mostrando = false;
  bool _iniciado = false;

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // El diálogo de huella puede mandar la app a segundo plano un
        // instante: eso no cuenta como "se fue".
        if (BloqueoBiometrico.enCurso) return;
        _enSegundoPlanoDesde ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final desde = _enSegundoPlanoDesde;
        _enSegundoPlanoDesde = null;
        if (desde != null && DateTime.now().difference(desde) >= margen) {
          _bloquearSiCorresponde();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _bloquearSiCorresponde() async {
    // Solo con la app ya abierta (no sobre el login ni sobre el inicio,
    // que tiene su propio paso de huella).
    if (_mostrando || !AuthStorage.desbloqueada) return;
    if (!await BloqueoBiometrico.estaActivo()) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _mostrando = true;
    try {
      await nav.push(PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, __, ___) => const PantallaBloqueo(),
      ));
    } finally {
      _mostrando = false;
    }
  }
}
