import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_dialog.dart';

/// Día 69 — Código de emergencia del residente.
///
/// Resuelve el problema que el patronato planteó como "se me descargó el
/// celular y no puedo mostrar mi QR". La alternativa era poner lectores
/// biométricos en el portón: lectores nuevos, un lector de enrolamiento, y
/// que alguien tuviera que custodiar las huellas de 500 familias. Esto no
/// cuesta nada y queda auditado igual.
///
/// El código se guarda HASHEADO en el servidor, así que esta pantalla nunca
/// puede mostrarlo. Solo sabe si ya hay uno configurado. Si el residente lo
/// olvida, define uno nuevo.
class CodigoEmergenciaScreen extends StatefulWidget {
  const CodigoEmergenciaScreen({super.key});

  @override
  State<CodigoEmergenciaScreen> createState() => _CodigoEmergenciaScreenState();
}

class _CodigoEmergenciaScreenState extends State<CodigoEmergenciaScreen> {
  final _codigoCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  bool _configurado = false;
  bool _ver = false;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    try {
      final r = await CodigoEmergenciaApi.estado();
      if (!mounted) return;
      setState(() {
        _configurado = r['configurado'] == true;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    final codigo = _codigoCtrl.text.trim();
    final repetir = _repetirCtrl.text.trim();

    if (codigo.length != 6) {
      ErrorDialog.mostrar(context, 'El código debe tener 6 dígitos');
      return;
    }
    if (codigo != repetir) {
      ErrorDialog.mostrar(context, 'Los dos códigos no coinciden');
      return;
    }

    setState(() => _guardando = true);
    try {
      await CodigoEmergenciaApi.definir(codigo);
      if (!mounted) return;
      setState(() {
        _configurado = true;
        _guardando = false;
      });
      _codigoCtrl.clear();
      _repetirCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de emergencia guardado')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ErrorDialog.mostrar(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        ErrorDialog.mostrar(context, 'No se pudo guardar el código');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código de emergencia')),
      // Scroll siempre: con el teclado abierto y el zoom de Android en
      // grande, un formulario sin scroll deja el botón fuera de alcance.
      // Es exactamente el problema que tuvo la pantalla de consentimiento.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.naranja.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.naranja.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.vpn_key_outlined, color: AppColors.naranja, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¿Para qué sirve?\n\nSi llegás al portón y tu teléfono está sin '
                    'batería, no vas a poder mostrar tu código QR. Decile al guardia '
                    'tu número de casa y este código: él te va a pedir tu '
                    'identificación, va a comparar con tu foto registrada y te abre.',
                    style: TextStyle(
                      fontSize: 13.5, height: 1.5,
                      color: AppColors.gris,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            if (_cargando)
              const Center(child: Padding(
                padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              Row(children: [
                Icon(
                  _configurado ? Icons.check_circle : Icons.info_outline,
                  size: 18,
                  color: _configurado ? Colors.green.shade600 : AppColors.gris,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _configurado
                        ? 'Ya tenés un código configurado.'
                        : 'Todavía no configuraste tu código.',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: _configurado ? Colors.green.shade700 : AppColors.gris,
                    ),
                  ),
                ),
              ]),

              if (_configurado)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 26),
                  child: Text(
                    'Por seguridad no podemos mostrártelo. Si lo olvidaste, '
                    'escribí uno nuevo acá abajo y reemplazá el anterior.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.gris.withOpacity(0.8), height: 1.4),
                  ),
                ),

              const SizedBox(height: 24),

              Text(_configurado ? 'Cambiar mi código' : 'Crear mi código',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
              const SizedBox(height: 12),

              TextField(
                controller: _codigoCtrl,
                keyboardType: TextInputType.number,
                obscureText: !_ver,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Código de 6 dígitos',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _ver = !_ver),
                    tooltip: _ver ? 'Ocultar' : 'Ver',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repetirCtrl,
                keyboardType: TextInputType.number,
                obscureText: !_ver,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Repetí el código',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'No uses el mismo dígito seis veces ni una secuencia como 123456, '
                'y que no sea igual a tu contraseña.',
                style: TextStyle(fontSize: 12, color: AppColors.gris.withOpacity(0.75), height: 1.4),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.naranja,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(_configurado ? 'Reemplazar código' : 'Guardar código',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: AppColors.gris),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Memorizalo ahora: el día que lo necesites vas a tener el '
                      'teléfono apagado y no vas a poder abrir la app para verlo.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.45),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
