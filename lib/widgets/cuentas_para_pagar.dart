import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/client.dart';
import '../theme/app_theme.dart';

/// Día 76 — las cuentas bancarias a las que el residente puede transferir
/// su cuota (las configura la administración en el panel web), con un botón
/// para copiar el número. Se copian solo los dígitos, que es como lo pide la
/// app del banco.
///
/// Si no hay ninguna configurada, no se muestra nada.
///
/// [compacta]: versión plegable, para la pantalla de subir comprobante.
class CuentasParaPagar extends StatefulWidget {
  final bool compacta;
  const CuentasParaPagar({super.key, this.compacta = false});

  @override
  State<CuentasParaPagar> createState() => _CuentasParaPagarState();
}

class _CuentasParaPagarState extends State<CuentasParaPagar> {
  List<dynamic> _cuentas = [];

  @override
  void initState() {
    super.initState();
    ResidenteApi.cuentasBancarias().then((c) {
      if (mounted) setState(() => _cuentas = c);
    }).catchError((_) {/* sin cuentas: no se muestra nada */});
  }

  @override
  Widget build(BuildContext context) {
    if (_cuentas.isEmpty) return const SizedBox.shrink();
    final filas = <Widget>[];
    for (var i = 0; i < _cuentas.length; i++) {
      if (i > 0) filas.add(const Divider(height: 1, color: AppColors.borde));
      filas.add(_FilaCuenta(cuenta: _cuentas[i] as Map<String, dynamic>));
    }

    if (widget.compacta) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.grisCl,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            leading: Icon(Icons.account_balance_outlined, color: AppColors.azul, size: 20),
            title: Text('¿A dónde transferir?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.azul)),
            subtitle: Text(
                _cuentas.length == 1 ? '1 cuenta · tocá para ver' : '${_cuentas.length} cuentas · tocá para ver',
                style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            children: filas,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.account_balance_outlined, color: AppColors.azul, size: 20),
            const SizedBox(width: 8),
            Text('Cuentas para pagar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.azul)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Transferí o depositá a cualquiera de estas cuentas y después subí el comprobante en la cuota.',
            style: TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.4)),
          const SizedBox(height: 6),
          ...filas,
        ]),
      ),
    );
  }
}

class _FilaCuenta extends StatefulWidget {
  final Map<String, dynamic> cuenta;
  const _FilaCuenta({required this.cuenta});

  @override
  State<_FilaCuenta> createState() => _FilaCuentaState();
}

class _FilaCuentaState extends State<_FilaCuenta> {
  bool _copiado = false;

  static const _tipos = {'ahorro': 'Ahorro', 'cheques': 'Cheques'};

  Future<void> _copiar() async {
    final numero = (widget.cuenta['numero'] ?? '').toString();
    await Clipboard.setData(ClipboardData(text: numero.replaceAll(RegExp(r'\D'), '')));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _copiado = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Número de ${widget.cuenta['banco']} copiado. Pegalo en la app de tu banco.'),
      duration: const Duration(seconds: 2),
    ));
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cuenta;
    final detalle = [
      if (c['tipo'] != null) _tipos[c['tipo']] ?? c['tipo'].toString(),
      if ((c['titular'] ?? '').toString().isNotEmpty) c['titular'].toString(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((c['banco'] ?? '').toString(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gris)),
          const SizedBox(height: 2),
          SelectableText((c['numero'] ?? '').toString(),
              style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.azul,
                letterSpacing: 0.6, fontFeatures: const [FontFeature.tabularFigures()],
              )),
          if (detalle.isNotEmpty)
            Text(detalle, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        ])),
        const SizedBox(width: 10),
        _copiado
            ? FilledButton.icon(
                onPressed: _copiar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Copiado'),
              )
            : OutlinedButton.icon(
                onPressed: _copiar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azul,
                  side: const BorderSide(color: AppColors.borde, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar'),
              ),
      ]),
    );
  }
}
