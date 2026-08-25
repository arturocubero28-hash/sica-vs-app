import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Día 64 — pantalla de consentimiento de Política de Privacidad y Términos
/// y Condiciones. Se muestra UNA SOLA VEZ, antes de llegar al login, la
/// primera vez que el usuario abre la app (o si los términos se actualizan
/// y hay que volver a pedir el consentimiento). Una vez aceptada, queda
/// guardado en el almacenamiento seguro del dispositivo.
///
/// IMPORTANTE: esta pantalla navega directamente a LoginScreen usando su
/// propio context (no un callback del padre). El context del splash ya no
/// existe en el árbol de widgets cuando el usuario pulsa "Acepto" -- usar
/// un callback capturado desde el splash causaba que la app quedara pegada
/// sin avanzar (el Navigator del splash era inválido para ese momento).
class ConsentimientoScreen extends StatefulWidget {
  const ConsentimientoScreen({super.key});

  @override
  State<ConsentimientoScreen> createState() => _ConsentimientoScreenState();

  // ── Persistencia ───────────────────────────────────────────────────────────
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyVersion = 'sica_terminos_version';
  // Incrementar este número cuando los documentos cambien de forma relevante
  // para volver a pedirle el consentimiento a todos los usuarios.
  static const _versionActual = '1';

  static Future<bool> necesitaConsentimiento() async {
    final guardado = await _store.read(key: _keyVersion);
    return guardado != _versionActual;
  }

  static Future<void> marcarAceptado() async {
    await _store.write(key: _keyVersion, value: _versionActual);
  }
}

class _ConsentimientoScreenState extends State<ConsentimientoScreen> {
  bool _aceptaTerminos = false;
  bool _aceptaPrivacidad = false;
  bool _guardando = false;

  bool get _puedeContiuar => _aceptaTerminos && _aceptaPrivacidad;

  Future<void> _abrir(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento')),
        );
      }
    }
  }

  Future<void> _continuar() async {
    if (!_puedeContiuar) return;
    setState(() => _guardando = true);
    await ConsentimientoScreen.marcarAceptado();
    if (!mounted) return;
    // Usa el context propio de esta pantalla, que sí está vivo en este
    // momento -- no el del splash (que ya fue reemplazado y es inválido).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azul,
      body: SafeArea(
        child: Column(
          children: [
            // ── Encabezado ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 18),
                  const Text('Antes de continuar',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Leé y aceptá nuestros documentos legales para usar la aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            // ── Tarjeta de checkboxes ────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Documentos legales',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
                    const SizedBox(height: 6),
                    Text(
                      'Tocá el nombre del documento para leerlo completo.',
                      style: TextStyle(fontSize: 13, color: AppColors.gris.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 24),

                    // ── Checkbox Términos ────────────────────────────────────
                    _CheckboxDocumento(
                      aceptado: _aceptaTerminos,
                      onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                      titulo: 'Términos y Condiciones de Uso',
                      descripcion: 'Reglas de uso de la app, gestión de cuotas y accesos.',
                      onVerDocumento: () => _abrir('https://patronatovillasdelsol.com/terminos.html'),
                    ),

                    const SizedBox(height: 16),

                    // ── Checkbox Privacidad ──────────────────────────────────
                    _CheckboxDocumento(
                      aceptado: _aceptaPrivacidad,
                      onChanged: (v) => setState(() => _aceptaPrivacidad = v ?? false),
                      titulo: 'Política de Privacidad',
                      descripcion: 'Cómo recopilamos, usamos y protegemos tus datos personales.',
                      onVerDocumento: () => _abrir('https://patronatovillasdelsol.com/privacidad.html'),
                    ),

                    const Spacer(),

                    // ── Botón continuar ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_puedeContiuar && !_guardando) ? _continuar : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.naranja,
                          disabledBackgroundColor: AppColors.naranja.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _guardando
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Acepto y quiero continuar',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Debés aceptar ambos documentos para usar la app.',
                        style: TextStyle(fontSize: 12, color: AppColors.gris.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget reutilizable para cada checkbox de documento legal.
class _CheckboxDocumento extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool?> onChanged;
  final String titulo;
  final String descripcion;
  final VoidCallback onVerDocumento;

  const _CheckboxDocumento({
    required this.aceptado,
    required this.onChanged,
    required this.titulo,
    required this.descripcion,
    required this.onVerDocumento,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: aceptado ? AppColors.naranja.withOpacity(0.06) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aceptado ? AppColors.naranja.withOpacity(0.4) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: aceptado,
            onChanged: onChanged,
            activeColor: AppColors.naranja,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onVerDocumento,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.azul,
                              decoration: TextDecoration.underline,
                            )),
                        ),
                        Icon(Icons.open_in_new, size: 14, color: AppColors.naranja),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(descripcion,
                    style: TextStyle(fontSize: 12.5, color: AppColors.gris.withOpacity(0.8), height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
