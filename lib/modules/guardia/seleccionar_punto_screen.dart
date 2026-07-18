import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

/// Pantalla bloqueante: el guardia debe elegir en qué punto de acceso está
/// trabajando antes de poder usar el resto de la app (ACCESS-04, Auditoría
/// Día 35). Se muestra en el primer login, y también cuando el guardia
/// decide cambiar de punto manualmente (ej. lo mandan a cubrir otro acceso).
class SeleccionarPuntoScreen extends StatefulWidget {
  /// Si es true, el usuario puede cancelar y volver atrás (caso "cambiar
  /// de punto" desde un menú). Si es false, es la pantalla obligatoria del
  /// primer login y no hay forma de salir sin elegir.
  final bool esCambioVoluntario;
  const SeleccionarPuntoScreen({super.key, this.esCambioVoluntario = false});

  @override
  State<SeleccionarPuntoScreen> createState() => _SeleccionarPuntoScreenState();
}

class _SeleccionarPuntoScreenState extends State<SeleccionarPuntoScreen> {
  List<dynamic> _puntos = [];
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _puntoElegido;

  @override
  void initState() {
    super.initState();
    _cargarPuntos();
  }

  Future<void> _cargarPuntos() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ApiClient.get('/acceso/puntos');
      final lista = res as List<dynamic>;
      if (!mounted) return;
      setState(() => _puntos = lista);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los puntos de acceso');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmar() async {
    if (_puntoElegido == null) return;
    setState(() { _guardando = true; _error = null; });
    try {
      await ApiClient.post('/guardias/mi-punto-acceso', {'punto_acceso': _puntoElegido});
      if (!mounted) return;
      Navigator.of(context).pop(_puntoElegido);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar tu punto de acceso');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Bloqueante en el primer login: no se puede cerrar con el botón atrás.
      // Si es un cambio voluntario, sí se puede cancelar.
      canPop: widget.esCambioVoluntario,
      child: Scaffold(
        backgroundColor: AppColors.azul,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 24),
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield, color: AppColors.naranja, size: 48)),
              ),
              const SizedBox(height: 20),
              Text(
                widget.esCambioVoluntario ? 'Cambiar de punto de acceso' : '¿En qué punto estás?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                widget.esCambioVoluntario
                    ? 'Elegí el punto de acceso al que te trasladaron.'
                    : 'Elegí el punto de acceso donde estás trabajando este turno. '
                      'Los accesos que registres quedarán a nombre de ese punto.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.4),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : _puntos.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.location_off_outlined, size: 48, color: AppColors.gris),
                              const SizedBox(height: 12),
                              const Text('No hay puntos de acceso configurados.\n'
                                  'Pedile al administrador que cree al menos uno.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.gris, fontSize: 13)),
                            ]))
                          : ListView.separated(
                              itemCount: _puntos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final p = _puntos[i] as Map<String, dynamic>;
                                final nombre = p['punto_acceso']?.toString() ?? '';
                                final elegido = _puntoElegido == nombre;
                                final tags = <String>[
                                  if (p['tiene_peatonal'] == true) 'Peatonal',
                                  if (p['tiene_vehicular_entrada'] == true) 'Entrada vehicular',
                                  if (p['tiene_vehicular_salida'] == true) 'Salida vehicular',
                                ];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  onTap: () => setState(() => _puntoElegido = nombre),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: elegido ? AppColors.azul.withOpacity(0.06) : Colors.white,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                          color: elegido ? AppColors.azul : AppColors.borde,
                                          width: elegido ? 2 : 1),
                                    ),
                                    child: Row(children: [
                                      Icon(
                                        elegido ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                        color: elegido ? AppColors.azul : AppColors.gris,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(nombre, style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                                        const SizedBox(height: 4),
                                        Wrap(spacing: 6, runSpacing: 4, children: tags.map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.grisCl,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(t, style: const TextStyle(fontSize: 10.5, color: AppColors.gris)),
                                        )).toList()),
                                      ])),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_puntoElegido == null || _guardando) ? null : _confirmar,
                  child: Text(_guardando ? 'Guardando…' : 'Confirmar'),
                ),
              ),
              if (widget.esCambioVoluntario) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
