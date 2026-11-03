import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tarjeta_qr.dart';

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
  // Día 72 — error al CARGAR la lista (distinto de _error, que es al
  // guardar). Antes un fallo de carga dejaba la lista vacía y la pantalla
  // decía "No hay puntos de acceso configurados", que es falso: había
  // puntos, lo que falló fue la consulta.
  String? _errorCarga;
  String? _puntoElegido;

  @override
  void initState() {
    super.initState();
    _cargarPuntos();
  }

  Future<void> _cargarPuntos() async {
    setState(() { _cargando = true; _errorCarga = null; });
    // Un reintento automático: justo después de iniciar sesión la primera
    // consulta a veces falla (conexión recién abierta) y la segunda pasa.
    for (var intento = 1; intento <= 2; intento++) {
      try {
        final res = await ApiClient.get('/acceso/puntos');
        final lista = res as List<dynamic>;
        if (!mounted) return;
        setState(() { _puntos = lista; _cargando = false; });
        return;
      } on ApiException catch (e) {
        if (intento == 2 && mounted) {
          setState(() => _errorCarga = e.message);
        }
      } catch (e) {
        if (intento == 2 && mounted) {
          setState(() => _errorCarga =
              'No se pudo conectar con el servidor. (${e.runtimeType})');
        }
      }
      if (intento == 1) await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
    }
    if (mounted) setState(() => _cargando = false);
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
                child: LogoResidencial(size: 48, colorRespaldo: AppColors.naranja),
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
                      : _errorCarga != null
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.gris),
                              const SizedBox(height: 12),
                              const Text('No se pudieron cargar los puntos de acceso.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.azulDeFabrica,
                                      fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(_errorCarga!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.gris, fontSize: 12.5)),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _cargarPuntos,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ]))
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
                                        Text(nombre, style: TextStyle(
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
