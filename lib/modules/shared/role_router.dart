import 'package:flutter/material.dart';
import '../residente/residente_shell.dart';
import '../guardia/guardia_shell.dart';
import 'no_mobile_screen.dart';

/// Determina qué pantalla mostrar según el rol del usuario logueado.
/// Roles móviles: residente, guardia.
/// Roles solo web: admin, super_admin, cajero, desarrollador.
class RoleRouter {
  static void navegar(BuildContext context, String rol) {
    Widget destino;
    switch (rol) {
      case 'residente':
        destino = const ResidenteShell();
        break;
      case 'guardia':
        destino = const GuardiaShell();
        break;
      default:
        // admin, cajero, desarrollador → redirigir al panel web
        destino = NoMobileScreen(rol: rol);
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destino),
      (_) => false,
    );
  }
}
