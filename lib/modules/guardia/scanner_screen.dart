import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _procesando = false;
  bool _escaneando = true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _onDeteccion(BarcodeCapture capture) async {
    if (_procesando || !_escaneando) return;
    final qrData = capture.barcodes.firstOrNull?.rawValue;
    if (qrData == null) return;

    setState(() { _procesando = true; _escaneando = false; });
    await _ctrl.stop();
    await _procesarQr(qrData);
  }

  Future<void> _procesarQr(String qrData) async {
    // Tomar hasta 3 fotos
    final fotos = await _tomarFotos();

    try {
      final res = await GuardiaApi.validarQr(qrData, fotos);
      if (!mounted) return;
      _mostrarResultado(res, exitoso: true);
    } catch (e) {
      if (!mounted) return;
      _mostrarResultado({'mensaje': e.toString()}, exitoso: false);
    } finally {
      setState(() => _procesando = false);
    }
  }

  Future<List<String>> _tomarFotos() async {
    final fotos = <String>[];
    final picker = ImagePicker();
    for (int i = 0; i < 3 && mounted; i++) {
      final picked = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 60);
      if (picked == null) break;
      final bytes = await File(picked.path).readAsBytes();
      fotos.add(base64Encode(bytes));
    }
    return fotos;
  }

  void _mostrarResultado(Map res, {required bool exitoso}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ResultadoPanel(
        resultado: res,
        exitoso: exitoso,
        onCerrar: () {
          Navigator.pop(context);
          _reanudar();
        },
      ),
    ).then((_) => _reanudar());
  }

  void _reanudar() {
    setState(() { _escaneando = true; });
    _ctrl.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Cámara
      MobileScanner(controller: _ctrl, onDetect: _onDeteccion),

      // Marco de escaneo
      Center(
        child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.naranja, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Indicador de procesando
      if (_procesando)
        Container(
          color: Colors.black54,
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.naranja),
              SizedBox(height: 16),
              Text('Procesando…', style: TextStyle(color: Colors.white, fontSize: 16)),
            ]),
          ),
        ),

      // Texto guía
      Positioned(
        bottom: 40, left: 0, right: 0,
        child: Text(
          'Apuntá la cámara al código QR',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15,
              shadows: [const Shadow(color: Colors.black54, blurRadius: 4)]),
        ),
      ),
    ]);
  }
}

class _ResultadoPanel extends StatelessWidget {
  final Map resultado;
  final bool exitoso;
  final VoidCallback onCerrar;
  const _ResultadoPanel({required this.resultado, required this.exitoso, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final nombre = resultado['nombre_visitante'] ?? resultado['mensaje'] ?? '';
    final unidad = resultado['unidad'] ?? '';
    final tipo   = resultado['tipo_qr'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Ícono de resultado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (exitoso ? AppColors.verde : AppColors.rojo).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            exitoso ? Icons.check_circle : Icons.cancel,
            color: exitoso ? AppColors.verde : AppColors.rojo,
            size: 56,
          ),
        ),
        const SizedBox(height: 16),

        Text(exitoso ? 'Acceso permitido' : 'Acceso denegado',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: exitoso ? AppColors.verde : AppColors.rojo,
            )),
        const SizedBox(height: 8),
        Text(nombre, style: const TextStyle(fontSize: 16, color: AppColors.azul),
            textAlign: TextAlign.center),
        if (unidad.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(unidad, style: const TextStyle(color: AppColors.gris)),
        ],
        if (tipo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Tipo: $tipo', style: const TextStyle(color: AppColors.gris, fontSize: 13)),
        ],

        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: onCerrar,
            style: ElevatedButton.styleFrom(
              backgroundColor: exitoso ? AppColors.verde : AppColors.azul),
            child: const Text('Escanear otro'),
          ),
        ),
      ]),
    );
  }
}
