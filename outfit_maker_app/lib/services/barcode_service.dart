import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeService {
  MobileScannerController? _controller;
  bool _isInitialized = false;

  MobileScannerController get controller {
    if (_controller == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      _isInitialized = true;
    }
    return _controller!;
  }

  bool get isInitialized => _isInitialized;

  /// Inicializa el controlador
  Future<void> initialize() async {
    if (_isInitialized) return;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _isInitialized = true;
  }

  /// Libera los recursos
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    }
  }

  /// Activa/desactiva la linterna
  Future<void> toggleTorch() async {
    if (_controller != null) {
      await _controller!.toggleTorch();
    }
  }

  /// Cambia entre cámara frontal y trasera
  Future<void> switchCamera() async {
    if (_controller != null) {
      await _controller!.switchCamera();
    }
  }
}