import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../api/client.dart';

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

const double kAnchoTarjeta = 640;
// Día 47: se sube de 880 a 1010 para sumar la fila de recomendaciones de
// acceso (íconos) sin apretar el resto del contenido.
const double kAltoTarjeta = 1010;

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

  /// Devuelve el valor del campo si existe y no está vacío; si no, null.
  String? _campo(String clave) {
    final v = visita[clave];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? get _placa => _campo('placa_vehiculo');
  String? get _empresa => _campo('empresa');

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
        // ── Encabezado con degradado naranja (color secundario) ──
        Container(
          height: 175,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Día 47 — bug encontrado por el usuario: este degradado
              // estaba escrito con hex literal (0xFFF48723/0xFFFFBE6E), sin
              // pasar nunca por AppColors.naranja — por eso no seguía el
              // color secundario personalizado aunque todo lo demás sí.
              // Para el caso de fábrica se usa el segundo tono exacto
              // original (no es una relación matemática limpia con el
              // primero); para un naranja personalizado se deriva
              // aclarando, mismo criterio que AppColors.azul2.
              colors: [
                AppColors.naranja,
                AppColors.naranja.value == AppColors.naranjaDeFabrica.value
                    ? const Color(0xFFFFBE6E)
                    : AppColors.aclarar(AppColors.naranja, 0.4),
              ],
            ),
            // Día 47, a pedido del usuario: se quita la línea plana de
            // abajo del encabezado — ahora se curva hacia adentro, mismo
            // radio que usa el encabezado del residente en el resto de la
            // app (residente_shell.dart, AppRadius.lg) para que se vea
            // consistente con el resto del diseño.
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            // Logo en círculo blanco. Día 46: antes era un asset fijo
            // (assets/images/logo.png) con el escudo de Villas del Sol —
            // ahora se pide el logo real que cada admin sube en Mi Perfil.
            // Si la residencial no tiene logo propio, o falla la descarga,
            // se muestra el escudo genérico como respaldo (nunca el logo de
            // otra residencial).
            Container(
              width: 116, height: 116,
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
              // ClipOval + BoxFit.cover (vía LogoResidencial fit): recorta
              // el logo en círculo perfecto sin importar su proporción
              // original — antes con BoxFit.contain un logo no cuadrado
              // quedaba descentrado o con espacios en blanco raros.
              child: const ClipOval(
                child: LogoResidencial(size: 62, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 22),
            // Expanded: sin esto, un nombre de residencial largo no tenía
            // límite de ancho dentro del Row y desbordaba el marco fijo de
            // la tarjeta (600px), rompiendo la captura de la imagen.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RESIDENCIAL', style: GoogleFonts.inter(
                      fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white,
                      letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  // FittedBox reduce el tamaño de fuente automáticamente si
                  // el nombre es muy largo, en vez de desbordar o cortar
                  // texto a la mitad.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(ResidencialCache.nombre.toUpperCase(), style: GoogleFonts.inter(
                        fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // ── QR con marco naranja y logo incrustado al centro ──
        // Día 47, a pedido del usuario: el logo de la residencial va
        // incrustado en el medio del QR (no solo en el círculo de arriba).
        // Funciona porque el nivel de corrección de errores ya es H (alto,
        // ~30% del código puede taparse sin que deje de leerse) — eso ya
        // estaba configurado, pensado justamente para esto. Usa el mismo
        // logo ya cacheado en disco (ResidencialCache.logoLocal) — sin
        // logo propio, el QR se ve limpio sin nada en el centro.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.naranja, width: 5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: FutureBuilder<File?>(
            future: ResidencialCache.logoLocal(),
            builder: (context, snap) {
              final logo = snap.data;
              return QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 320,
                padding: EdgeInsets.zero,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: AppColors.azul),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle, color: AppColors.azul),
                embeddedImage: logo != null ? FileImage(logo) : null,
                embeddedImageStyle: logo != null
                    ? const QrEmbeddedImageStyle(size: Size(52, 52))
                    : null,
              );
            },
          ),
        ),

        const SizedBox(height: 22),
        // ── Línea separadora ──
        Container(height: 2, width: kAnchoTarjeta - 160, color: const Color(0xFFE6E6E6)),
        const SizedBox(height: 18),

        // ── Nombre del visitante + tipo de visita, agrupados ──
        // Día 47: se ajusta la tipografía para un look más moderno —
        // letterSpacing levemente negativo en el nombre grande (recurso
        // típico de diseño de tarjetas/credenciales: texto grande y bold
        // se ve más prolijo con las letras un poco más juntas).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            visita['nombre_visitante']?.toString() ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800,
                color: AppColors.azul, letterSpacing: -0.5),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.naranja,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(_tipoTexto, style: GoogleFonts.inter(
              fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white,
              letterSpacing: 0.2)),
        ),
        const SizedBox(height: 14),

        // ── Detalles opcionales ──
        // Expanded absorbe el espacio sobrante y centra los detalles.
        // No lleva Spacer() al lado: dos widgets flexibles compitiendo por el
        // mismo espacio dejaban a los detalles con altura cero.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (_validoHasta != null) _detalle('Válido hasta: $_validoHasta', icono: Icons.calendar_today_outlined),
                if (_placa != null) _detalle('Vehículo: $_placa', icono: Icons.directions_car_outlined),
                if (_empresa != null) _detalle('Empresa: $_empresa'),
              ],
            ),
          ),
        ),

        // ── Recomendaciones de acceso (Día 47) ──
        // Fila de pictogramas al estilo señalética vial: ícono + 1-2
        // palabras debajo, sin párrafos largos — la tarjeta se mira rápido,
        // en la entrada. Código de color con significado, igual que una
        // señal de tránsito real: azul = informativo/obligatorio, naranja =
        // cortesía esperada, rojo = prohibición.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconoConsejo(Icons.speed, 'Máx.\n20 km/h', AppColors.azul),
              _iconoConsejo(Icons.pets, 'Peatones y\nmascotas', AppColors.naranja),
              _iconoConsejo(Icons.badge, 'Muestre\nidentificación', AppColors.azul),
              _iconoConsejo(Icons.directions_car, 'Baje el\nvidrio', AppColors.naranja),
              _iconoConsejo(Icons.local_parking, 'No estacione\nen comunes', AppColors.rojo),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Pie de página ──
        Text('Presente este código al guardia en la entrada',
            style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF969696), letterSpacing: 0.1)),
        const SizedBox(height: 16),

        // ── Franja inferior naranja ──
        Container(height: 14, width: double.infinity, color: AppColors.naranja),
      ]),
    );

    return captureKey != null
        ? RepaintBoundary(key: captureKey, child: tarjeta)
        : tarjeta;
  }

  // Día 47, a pedido del usuario: ícono chico opcional a la par del texto
  // (calendario para la fecha de vigencia, auto para la placa) — el mismo
  // detalle que le gustó de una referencia que compartió.
  Widget _detalle(String texto, {IconData? icono}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 19, color: AppColors.azul),
          const SizedBox(width: 6),
        ],
        Text(texto, style: GoogleFonts.inter(fontSize: 18, color: const Color(0xFF5A5A5A))),
      ],
    ),
  );

  /// Pictograma de la fila de "recomendaciones de acceso" (Día 47): un
  /// ícono en círculo de color + 1-2 palabras debajo, al estilo señalética
  /// vial. `color` no es decorativo — codifica el significado (ver el
  /// comentario donde se arma la fila): azul = informativo, naranja =
  /// cortesía, rojo = prohibición.
  Widget _iconoConsejo(IconData icono, String texto, Color color) {
    // Día 47, a pedido del usuario: círculo e ícono un 30% más grandes que
    // la versión original (46→60, 24→31), con la tarjeta ensanchada
    // (600→640) para que las 5 columnas sigan entrando cómodas.
    return SizedBox(
      width: 116,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icono, color: Colors.white, size: 31),
          ),
          const SizedBox(height: 7),
          Text(
            texto,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: const Color(0xFF6B6B6B), height: 1.25),
          ),
        ],
      ),
    );
  }

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

    // Día 47: la tarjeta usa Inter (google_fonts), que se descarga en
    // segundo plano la primera vez que el dispositivo la necesita. Si se
    // captura la imagen antes de que termine, saldría con la fuente de
    // respaldo del sistema en vez de Inter — GoogleFonts.pendingFonts()
    // ya es un Future (resuelve en List<void> cuando todas las descargas
    // pendientes terminan), no una lista de futuros para envolver en
    // Future.wait. Después de la primera vez, con la fuente ya cacheada
    // localmente, esta espera es prácticamente instantánea.
    await GoogleFonts.pendingFonts();

    final image = await boundary.toImage(pixelRatio: escala);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Widget reutilizable de QR simple para la tarjeta virtual.
/// No incluye el diseño completo de la tarjeta de visitas.
class QrImageViewWidget extends StatelessWidget {
  final String data;
  final double size;
  const QrImageViewWidget({super.key, required this.data, this.size = 240});

  @override
  Widget build(BuildContext context) => QrImageView(
    data: data,
    version: QrVersions.auto,
    size: size,
    padding: EdgeInsets.zero,
    errorCorrectionLevel: QrErrorCorrectLevel.H,
    backgroundColor: Colors.white,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.azul),
    dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.circle, color: AppColors.azul),
  );
}

/// Día 46: muestra el logo real de la residencial (subido por el admin en
/// Mi Perfil) en vez del asset fijo de Villas del Sol. Reutilizable en
/// cualquier pantalla que antes usaba Image.asset('assets/images/logo.png').
///
/// Primero busca el logo en el CACHÉ EN DISCO (ResidencialCache.logoLocal,
/// descargado una única vez tras el login — ver asegurarLogoDescargado). Eso
/// hace que la app no vuelva a pedir la imagen por red en cada apertura. Si
/// por algún motivo todavía no está en disco (primera vez muy rápida, sin
/// conexión al momento de la descarga inicial, etc.), cae a pedirlo por red
/// como respaldo. Si no hay logo subido, o toda descarga falla, se muestra un
/// ícono de respaldo — nunca un logo de otra residencial ni un hueco vacío.
class LogoResidencial extends StatelessWidget {
  final double size;
  // Día 47: nullable en vez de tener AppColors.azul como valor por defecto
  // del constructor — ese valor ya no es una constante de compilación
  // (puede cambiar en tiempo de ejecución), así que el constructor no
  // puede seguir siendo const con ese default. El color efectivo se
  // resuelve en build(), leyendo AppColors.azul en ese momento (el color
  // VIGENTE, no el que había cuando se construyó el widget).
  final Color? colorRespaldo;
  final BoxFit fit;

  const LogoResidencial({
    super.key,
    this.size = 48,
    this.colorRespaldo,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final respaldo = Icon(Icons.shield, color: colorRespaldo ?? AppColors.azul, size: size);

    return FutureBuilder<File?>(
      future: ResidencialCache.logoLocal(),
      builder: (context, snapLocal) {
        if (snapLocal.connectionState != ConnectionState.done) {
          return respaldo; // evita parpadeo mientras resuelve (es una lectura de disco, rápida)
        }
        final archivoLocal = snapLocal.data;
        if (archivoLocal != null) {
          // key única por ruta de archivo: obliga a Flutter a tratar el
          // logo de cada residencial como un elemento visual nuevo, sin
          // posibilidad de mezclar el render de un logo anterior con el
          // actual durante una transición de pantalla (ej. al cambiar de
          // cuenta sin recompilar la app).
          return Image.file(
            archivoLocal,
            key: ValueKey(archivoLocal.path),
            fit: fit,
            errorBuilder: (_, __, ___) => respaldo,
          );
        }

        // Respaldo: todavía no está en disco (raro, pero posible) — se pide
        // por red esta vez. asegurarLogoDescargado() lo dejará cacheado para
        // la próxima.
        final url = ResidencialCache.logoUrl;
        if (url == null) return respaldo;
        return FutureBuilder<Map<String, String>>(
          future: ApiClient.authHeaders(),
          builder: (context, snap) {
            if (!snap.hasData) return respaldo;
            return Image.network(
              url,
              headers: snap.data,
              fit: fit,
              errorBuilder: (_, __, ___) => respaldo,
            );
          },
        );
      },
    );
  }
}

