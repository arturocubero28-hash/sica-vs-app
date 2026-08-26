import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Día 63 — diálogo de error reutilizable en toda la app, a pedido del
/// usuario: los errores se mostraban en un SnackBar (una franja chica en
/// letras rojas, fácil de perder, sobre todo con los mensajes de
/// diagnóstico más largos que se agregaron el Día 62 — ej. "No se pudo
/// obtener el recibo (500)"). Este diálogo centra la atención, se ve
/// prolijo, y se cierra con un botón "Aceptar" explícito en vez de
/// desaparecer solo.
///
/// Uso:
///   ErrorDialog.mostrar(context, 'No se pudo obtener el recibo (500)');
///   ErrorDialog.mostrar(context, e.message, titulo: 'No se pudo guardar');
class ErrorDialog {
  static Future<void> mostrar(
    BuildContext context,
    String mensaje, {
    String titulo = 'Ocurrió un error',
  }) {
    return showDialog(
      context: context,
      // Día 65 — barrierDismissible: true permite cerrar tocando fuera,
      // como respaldo al botón "Aceptar" en caso de que el context del
      // dialog quede huérfano (ver abajo).
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.rojo.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.rojo, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.azul),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                mensaje,
                style: const TextStyle(fontSize: 14, color: AppColors.gris, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Día 65 — BUG REAL: cuando _expulsarPorSesionInvalida()
                    // llama a nav.pushAndRemoveUntil(), limpia toda la pila
                    // de navegación y el contexto del dialog queda HUÉRFANO
                    // (el árbol de widgets donde existía ya no está). En ese
                    // caso, Navigator.of(dialogContext).pop() no encuentra
                    // ningún navigator válido y no hace nada -- el diálogo
                    // se ve, el botón responde, pero no se cierra.
                    //
                    // Fix: intentar primero con el navigator del propio
                    // dialog (caso normal); si no puede hacer pop, usar el
                    // navigator raíz global (navigatorKey) que siempre
                    // existe independientemente del estado de la pila.
                    final nav = Navigator.of(dialogContext, rootNavigator: true);
                    if (nav.canPop()) {
                      nav.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.naranja,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
