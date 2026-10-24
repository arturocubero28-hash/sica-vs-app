import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/client.dart';
import '../../api/screen_secure.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_dialog.dart';

/// Código de emergencia del residente (Día 69, rediseñado el Día 71).
///
/// Sirve para entrar cuando el teléfono se quedó sin batería: el residente le
/// dice al guardia su casa y este código. Desde el Día 71, a pedido del
/// patronato, el residente puede VER su código acá por si lo olvida. Sale
/// oculto, como una contraseña, y el ojo lo muestra. La pantalla bloquea las
/// capturas mientras está abierta.
///
/// Siempre hay un botón "Cambiar código": pide el nuevo y se confirma con
/// "Cambiar".
class CodigoEmergenciaScreen extends StatefulWidget {
  const CodigoEmergenciaScreen({super.key});

  @override
  State<CodigoEmergenciaScreen> createState() => _CodigoEmergenciaScreenState();
}

class _CodigoEmergenciaScreenState extends State<CodigoEmergenciaScreen> {
  final _nuevoCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  bool _configurado = false;
  String? _codigo;          // null si no hay o si es anterior al Día 71
  bool _mostrar = false;    // el ojo del código actual
  bool _editando = false;   // formulario de cambio abierto
  bool _verNuevo = false;   // el ojo del campo nuevo

  @override
  void initState() {
    super.initState();
    ScreenSecure.activar();
    _cargarEstado();
  }

  @override
  void dispose() {
    ScreenSecure.desactivar();
    _nuevoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    setState(() => _cargando = true);
    try {
      final r = await CodigoEmergenciaApi.estado();
      if (!mounted) return;
      setState(() {
        _configurado = r['configurado'] == true;
        _codigo = r['codigo']?.toString();
        _cargando = false;
        _mostrar = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirCambio() {
    _nuevoCtrl.clear();
    setState(() {
      _editando = true;
      _verNuevo = false;
    });
  }

  Future<void> _cambiar() async {
    final codigo = _nuevoCtrl.text.trim();
    if (codigo.length != 6) {
      ErrorDialog.mostrar(context, 'El código debe tener 6 dígitos');
      return;
    }
    final eraNuevo = !_configurado;
    setState(() => _guardando = true);
    try {
      await CodigoEmergenciaApi.definir(codigo);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _editando = false;
      });
      _nuevoCtrl.clear();
      await _cargarEstado();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(eraNuevo ? 'Código creado' : 'Código cambiado')),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _explicacion(),
            const SizedBox(height: 20),
            if (_cargando)
              const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              _tarjetaCodigo(),
              const SizedBox(height: 16),
              if (_editando) _formularioCambio() else _botonCambiar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _explicacion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.naranja.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.naranja.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.vpn_key_outlined, color: AppColors.naranja, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Si llegás al portón con el teléfono sin batería, decile al guardia '
            'tu número de casa y este código. Él va a pedir tu identificación, '
            'la compara con tu foto y te deja pasar.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.gris),
          ),
        ),
      ]),
    );
  }

  /// El código actual, oculto como una contraseña, con el ojo para verlo.
  Widget _tarjetaCodigo() {
    final Widget contenido;
    if (!_configurado) {
      contenido = const Text('Todavía no tenés un código.',
          style: TextStyle(fontSize: 15, color: AppColors.gris));
    } else if (_codigo == null) {
      // Código creado antes de que se guardara la copia que se puede mostrar.
      contenido = const Text(
        'Tenés un código, pero se creó antes de que se pudiera ver desde la '
        'app. Cambialo y a partir de ahí lo vas a poder ver acá.',
        style: TextStyle(fontSize: 13.5, color: AppColors.gris, height: 1.45));
    } else {
      contenido = Row(children: [
        Expanded(
          child: Text(
            _mostrar ? _codigo!.split('').join(' ') : '•  •  •  •  •  •',
            style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 2,
              color: AppColors.azul,
            ),
          ),
        ),
        IconButton(
          iconSize: 28,
          tooltip: _mostrar ? 'Ocultar código' : 'Mostrar código',
          icon: Icon(_mostrar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.azul),
          onPressed: () => setState(() => _mostrar = !_mostrar),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tu código',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gris)),
        const SizedBox(height: 8),
        contenido,
      ]),
    );
  }

  Widget _botonCambiar() {
    return OutlinedButton.icon(
      onPressed: _abrirCambio,
      icon: const Icon(Icons.edit_outlined),
      label: Text(_configurado ? 'Cambiar código' : 'Crear código'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.azul,
        side: BorderSide(color: AppColors.azul, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _formularioCambio() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _nuevoCtrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        obscureText: !_verNuevo,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _cambiar(),
        decoration: InputDecoration(
          labelText: 'Nuevo código de 6 dígitos',
          counterText: '',
          prefixIcon: const Icon(Icons.pin_outlined),
          suffixIcon: IconButton(
            icon: Icon(_verNuevo ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _verNuevo = !_verNuevo),
            tooltip: _verNuevo ? 'Ocultar' : 'Ver',
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'No repitas el mismo dígito ni uses una secuencia como 123456, '
        'y que no sea igual a tu contraseña.',
        style: TextStyle(fontSize: 12, color: AppColors.gris.withOpacity(0.8), height: 1.4),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _guardando ? null : _cambiar,
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
            : Text(_configurado ? 'Cambiar' : 'Crear',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      TextButton(
        onPressed: _guardando ? null : () => setState(() => _editando = false),
        child: const Text('Cancelar'),
      ),
    ]);
  }
}
