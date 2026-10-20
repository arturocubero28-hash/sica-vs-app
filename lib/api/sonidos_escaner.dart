import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Día 70 — sonidos propios para el escáner del guardia.
///
/// POR QUÉ NO ALCANZABA EL SONIDO DEL SISTEMA
/// ------------------------------------------
/// Antes se usaba SystemSound.play(SystemSoundType.click). En Android eso
/// se traduce a AudioManager.playSoundEffect(), que SOLO suena si la
/// persona tiene activados los "sonidos táctiles" del teléfono -- apagados
/// de fábrica en muchos equipos. El guardia no escuchaba nada y no tenía
/// forma de saber por qué.
///
/// Además sonaba a toque de pantalla, no a lector. En un portón, el
/// guardia no mira la pantalla en cada escaneo: se guía por el sonido, y
/// necesita uno que signifique "pasó" sin ambigüedad.
///
/// Estos archivos van en los assets y suenan con el volumen de multimedia,
/// sin depender de ningún ajuste del sistema.
///
/// CÓMO SE DISTINGUEN
/// ------------------
/// El acierto es un tono corto y único (1300 Hz con sub-octava de 650 Hz, 145 ms: sólido y con graves, sin chillar) -- el beep
/// clásico de caja de supermercado. El rechazo son dos tonos graves y
/// descendentes (440 → 330 Hz, 355 ms en total).
///
/// Se diferencian por TRES cosas a la vez: grave contra agudo, dos contra
/// uno, y largo contra corto. Es a propósito: en un portón con ruido, con
/// viento y con el teléfono en el bolsillo, depender de una sola de esas
/// señales no alcanza. La vibración acompaña por la misma razón, para el
/// caso de que el teléfono esté en silencio.
class SonidosEscaner {
  // Un reproductor por sonido: reutilizarlo para los dos obliga a esperar
  // a que termine el anterior, y acá los escaneos pueden venir seguidos.
  static final AudioPlayer _ok = AudioPlayer();
  static final AudioPlayer _error = AudioPlayer();
  static bool _listo = false;

  /// Precarga los dos sonidos. Se llama al abrir el escáner.
  ///
  /// Sin esto, el PRIMER escaneo del turno suena tarde: el reproductor
  /// tiene que leer y decodificar el archivo recién cuando se le pide, y
  /// ese retraso es justo donde más molesta, con el vehículo esperando.
  static Future<void> precargar() async {
    if (_listo) return;
    try {
      for (final p in [_ok, _error]) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await _ok.setSource(AssetSource('sonidos/escaneo_ok.wav'));
      await _error.setSource(AssetSource('sonidos/escaneo_error.wav'));
      _listo = true;
    } catch (_) {
      // Si falla la precarga no se rompe nada: play() carga igual, solo
      // que la primera vez tarda un poco más.
    }
  }

  /// Código válido: beep agudo corto + una vibración.
  static Future<void> aceptado() async {
    HapticFeedback.vibrate();
    await _reproducir(_ok, 'sonidos/escaneo_ok.wav');
  }

  /// Código rechazado: dos tonos graves + tres vibraciones.
  ///
  /// No se espera a que termine: el guardia tiene que ver el motivo del
  /// rechazo en pantalla de inmediato, no medio segundo después.
  static void rechazado() {
    _vibrarRechazo();
    _reproducir(_error, 'sonidos/escaneo_error.wav');
  }

  static Future<void> _vibrarRechazo() async {
    for (var i = 0; i < 3; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 160));
    }
  }

  static Future<void> _reproducir(AudioPlayer p, String asset) async {
    try {
      await p.stop();              // corta el escaneo anterior si sigue sonando
      await p.play(AssetSource(asset));
    } catch (_) {
      // El sonido es una ayuda, no el mecanismo de control: si el audio
      // falla, el guardia igual ve el resultado en pantalla y siente la
      // vibración. Nunca debe impedir registrar un acceso.
    }
  }

  static Future<void> liberar() async {
    try {
      await _ok.dispose();
      await _error.dispose();
    } catch (_) {}
    _listo = false;
  }
}
