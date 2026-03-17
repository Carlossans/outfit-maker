import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Servicio de detección de pose usando ML Kit
class PoseDetectionService {
  PoseDetector? _poseDetector;
  bool _isInitialized = false;

  /// Inicializa el detector de pose
  Future<void> initialize({
    PoseDetectionModel model = PoseDetectionModel.base,
    PoseDetectionMode mode = PoseDetectionMode.stream,
  }) async {
    if (_isInitialized) return;

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: model,
        mode: mode,
      ),
    );
    _isInitialized = true;
  }

  /// Procesa una imagen y detecta poses
  Future<List<Pose>> processImage(InputImage image) async {
    if (!_isInitialized || _poseDetector == null) {
      throw StateError('PoseDetectionService not initialized');
    }

    try {
      return await _poseDetector!.processImage(image);
    } catch (e) {
      debugPrint('Error detecting pose: $e');
      return [];
    }
  }

  /// Obtiene los puntos clave de la pose
  Map<PoseLandmarkType, PoseLandmark>? getKeyLandmarks(Pose pose) {
    final landmarks = pose.landmarks;

    // Verificar puntos esenciales
    final required = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final type in required) {
      if (!landmarks.containsKey(type) || landmarks[type] == null) {
        return null;
      }
    }

    return landmarks;
  }

  /// Calcula el ancho de los hombros en píxeles
  double? calculateShoulderWidth(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return null;

    return (rightShoulder.x - leftShoulder.x).abs();
  }

  /// Calcula la altura del torso en píxeles
  double? calculateTorsoHeight(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null || leftHip == null) return null;

    return (leftHip.y - leftShoulder.y).abs();
  }

  /// Libera los recursos
  Future<void> dispose() async {
    if (_poseDetector != null) {
      await _poseDetector!.close();
      _poseDetector = null;
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;
}
