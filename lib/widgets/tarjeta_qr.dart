import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

/// Renderiza la tarjeta QR completa en el DISPOSITIVO, no en el servidor.
///
/// Antes la app pedía `GET /visitas/<uuid>/qr-imagen` y el backend generaba
/// con PIL/Pillow una imagen de 1200×1760 px (2.1 megapíxeles): degradado
/// dibujado línea por línea, logo redimensionado, fuentes TrueType y encode
/// a PNG. Costaba ~150 ms de CPU por request y no había caché — abrir el QR
/// tres veces disparaba tres renders completos. Con 500 familias, un sábado
/// por la tarde eso ocupaba todos los workers de Gunicorn y dejaba esperando
/// al guardia que estaba escaneando en la garita.
///
/// El token del QR ya viajaba en el JSON de la visita (`qr_token`), así que
/// el dispositivo tiene todo lo necesario. Ahora la tarjeta se pinta con
/// widgets de Flutter y `qr_flutter`. El servidor no toca una sola imagen.
///
/// Para compartir, `RepaintBoundary` captura el widget ya renderizado a PNG
/// sin necesidad de volver a pedirle nada al backend.

const double kAnchoTarjeta = 600;
const double kAltoTarjeta = 880;

class TarjetaQR extends StatelessWidget {
  final Map<String, dynamic> visita;
  final GlobalKey? captureKey;

  const TarjetaQR({super.key, required this.visita, this.captureKey});

  static const Map<String, String> _tipos = {
    'unica': 'VISITA ÚNICA',
    'recurrente': 'VISITA RECURRENTE',
    'repartidor': 'REPARTIDOR',
  };

  String get _tipoTexto {
    final t = visita['tipo']?.toString() ?? '';
    return _tipos[t] ?? t.toUpperCase();
  }

  String? get _validoHasta {
    final v = visita['valido_hasta'];
    if (v == null) return null;
    final d = DateTime.tryParse(v.toString())?.toLocal();
    if (d == null) return null;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} a las ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final token = visita['qr_token']?.toString();
    if (token == null || token.isEmpty) {
      return _placeholderError();
    }

    final tarjeta = Container(
      width: kAnchoTarjeta,
      height: kAltoTarjeta,
      color: Colors.white,
      child: Column(children: [
        // ── Encabezado con degradado naranja ──
        Container(
          height: 175,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF48723), Color(0xFFFFBE6E)],
            ),
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            // Logo en círculo blanco
            Container(
              width: 116, height: 116,
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.shield, color: AppColors.azul, size: 62),
            ),
            const SizedBox(width: 22),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESIDENCIAL', style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 6),
                Text('VILLAS DEL SOL', style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ]),
        ),

        const SizedBox(height: 40),

        // ── QR con marco naranja ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.naranja, width: 5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: QrImageView(
            data: token,
            version: QrVersions.auto,
            size: 380,
            padding: EdgeInsets.zero,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square, color: AppColors.azul),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle, color: AppColors.azul),
          ),
        ),

        const SizedBox(height: 50),
        // ── Línea separadora ──
        Container(height: 2, width: kAnchoTarjeta - 160, color: const Color(0xFFE6E6E6)),
        const SizedBox(height: 35),

        // ── Nombre del visitante ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            visita['nombre_visitante']?.toString() ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.azul),
          ),
        ),
        const SizedBox(height: 22),

        // ── Pill del tipo de visita ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.naranja,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(_tipoTexto, style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 22),

        // ── Detalles opcionales ──
        // Envueltos en Flexible: si un visitante tiene nombre largo y los tres
        // campos opcionales, el bloque se comprime en vez de desbordar la
        // tarjeta (que tiene altura fija de 880).
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_validoHasta != null) _detalle('Válido hasta: $_validoHasta'),
              if (visita['placa_vehiculo'] != null &&
                  visita['placa_vehiculo'].toString().isNotEmpty)
                _detalle('Vehículo: ${visita['placa_vehiculo']}'),
              if (visita['empresa'] != null &&
                  visita['empresa'].toString().isNotEmpty)
                _detalle('Empresa: ${visita['empresa']}'),
            ],
          ),
        ),

        const Spacer(),

        // ── Pie de página ──
        const Text('Presente este código al guardia en la entrada',
            style: TextStyle(fontSize: 15, color: Color(0xFF969696))),
        const SizedBox(height: 31),

        // ── Franja inferior naranja ──
        Container(height: 14, width: double.infinity, color: AppColors.naranja),
      ]),
    );

    return captureKey != null
        ? RepaintBoundary(key: captureKey, child: tarjeta)
        : tarjeta;
  }

  Widget _detalle(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(texto, style: const TextStyle(fontSize: 17, color: Color(0xFF5A5A5A))),
  );

  Widget _placeholderError() => Container(
    width: kAnchoTarjeta, height: kAltoTarjeta,
    color: AppColors.grisCl,
    child: const Center(child: Text('No se pudo generar el código QR',
        style: TextStyle(color: AppColors.gris))),
  );
}

/// Captura el widget marcado con [captureKey] y lo devuelve como bytes PNG.
///
/// Se usa para compartir la tarjeta sin pedirle la imagen al servidor.
///
/// El [RepaintBoundary] envuelve la tarjeta a su tamaño lógico natural
/// (600×880), aunque en pantalla se muestre escalada dentro de un FittedBox.
/// Por eso basta con [escala] = 2.0 para obtener un PNG de 1200×1760 px —
/// exactamente la misma resolución que generaba el servidor con PIL.
Future<Uint8List?> capturarTarjetaComoPng(GlobalKey key, {double escala = 2.0}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: escala);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
