import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

/// Día 76 — sección «Ayuda»: el teléfono y el correo que la administración
/// configuró en el panel web para dudas, quejas y sugerencias. La misma
/// sección existe en el portal web (AyudaResidente.tsx).
class AyudaScreen extends StatefulWidget {
  /// Casa del residente, para el asunto del correo ("Consulta — Casa 15").
  final String casa;
  const AyudaScreen({super.key, this.casa = ''});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  Map<String, dynamic>? _res;
  bool _cargando = true;
  bool _error = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = false; });
    try {
      final r = await ResidenteApi.miResidencial();
      if (mounted) setState(() => _res = r);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _contenido()),
    );
  }

  Widget _contenido() {
    final nombre = (_res?['nombre'] ?? 'la residencial').toString();
    final tel = (_res?['telefono_ayuda'] ?? '').toString().trim();
    final correo = (_res?['email_ayuda'] ?? '').toString().trim();
    final asunto = widget.casa.isNotEmpty ? 'Consulta — ${widget.casa}' : 'Consulta';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.naranja.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.support_agent_rounded, color: AppColors.naranja, size: 30),
        ),
        const SizedBox(height: 14),
        Text('¿Tenés una duda, una queja o una sugerencia?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul, height: 1.25)),
        const SizedBox(height: 10),
        Text(
          'La administración de $nombre quiere escucharte. Llamanos o escribinos sobre tu cuenta, '
          'tus cuotas, un acceso que no funcionó o cualquier idea para mejorar la residencial. '
          'Contanos con calma qué pasó: así te podemos ayudar más rápido.',
          style: const TextStyle(fontSize: 15, color: AppColors.gris, height: 1.5),
        ),
        const SizedBox(height: 20),

        if (_error)
          const _Aviso(
            texto: 'No pudimos cargar el contacto. Revisá tu conexión y deslizá hacia abajo para reintentar.',
          )
        else if (tel.isEmpty && correo.isEmpty)
          const _Aviso(
            texto: 'La administración todavía no publicó un teléfono ni un correo. '
                'Mientras tanto, acercate a la oficina de la administración.',
          )
        else ...[
          if (tel.isNotEmpty)
            _Canal(
              icono: Icons.phone_rounded,
              titulo: 'Llamar',
              nota: 'Servicio al cliente',
              valor: tel,
              accion: 'Llamar ahora',
              uri: Uri(scheme: 'tel', path: tel.replaceAll(RegExp(r'[^\d+]'), '')),
            ),
          if (correo.isNotEmpty)
            _Canal(
              icono: Icons.mail_rounded,
              titulo: 'Escribir un correo',
              nota: 'Te respondemos por el mismo medio',
              valor: correo,
              accion: 'Escribir correo',
              // Uri(queryParameters) codifica los espacios como "+", que
              // algunas apps de correo muestran tal cual: se arma a mano.
              uri: Uri.parse('mailto:$correo?subject=${Uri.encodeComponent(asunto)}'),
            ),
        ],

        const SizedBox(height: 8),
        const Text('Si es una emergencia dentro de la residencial, avisale al guardia de la caseta.',
            style: TextStyle(fontSize: 13, color: AppColors.gris)),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: AppColors.grisCl,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borde),
    ),
    child: Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.gris, height: 1.45)),
  );
}

class _Canal extends StatelessWidget {
  final IconData icono;
  final String titulo, nota, valor, accion;
  final Uri uri;
  const _Canal({
    required this.icono, required this.titulo, required this.nota,
    required this.valor, required this.accion, required this.uri,
  });

  Future<void> _abrir(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      // Sin app de teléfono o de correo (una tablet, por ejemplo): se copia.
      await Clipboard.setData(ClipboardData(text: valor));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo abrir. Copiamos «$valor» para que lo uses.')));
      }
    }
  }

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: valor));
    HapticFeedback.lightImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Copiado: $valor'), duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.azul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: AppColors.azul, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
            Text(nota, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          ])),
        ]),
        const SizedBox(height: 14),
        SelectableText(valor,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF15283B))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => _abrir(context),
            child: Text(accion),
          )),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _copiar(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.azul,
              side: const BorderSide(color: AppColors.borde, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
          ),
        ]),
      ]),
    ),
  );
}
