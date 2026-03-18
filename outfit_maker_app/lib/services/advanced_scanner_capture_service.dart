import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/multi_angle_avatar.dart';

/// Servicio avanzado de captura tipo "scanner" con guía visual en tiempo real
/// Proporciona feedback visual mientras el usuario se posiciona correctamente
class AdvancedScannerCaptureService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
    ),
  );

  /// Analiza una imagen y proporciona feedback detallado sobre la posición
  Future<ScannerAnalysisResult> analyzeFrame(
    File imageFile,
    AvatarAngle expectedAngle,
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        return ScannerAnalysisResult.error(
          'No se detectó ninguna persona',
          feedback: 'Asegúrate de estar completamente visible en la cámara',
        );
      }

      final pose = poses.first;
      final landmarks = pose.landmarks;

      // Verificar cuerpo completo
      final bodyValidation = _validateFullBody(landmarks);
      if (!bodyValidation.isValid) {
        return ScannerAnalysisResult.error(
          bodyValidation.message,
          feedback: bodyValidation.feedback,
        );
      }

      // Validar según ángulo
      final angleValidation = _validateAngle(landmarks, expectedAngle);
      if (!angleValidation.isValid) {
        return ScannerAnalysisResult.error(
          angleValidation.message,
          feedback: angleValidation.feedback,
          positioningHints: angleValidation.hints,
        );
      }

      // Calcular calidad de la captura
      final quality = _calculateCaptureQuality(landmarks, expectedAngle);

      return ScannerAnalysisResult.success(
        confidence: quality.confidence,
        quality: quality.quality,
        message: 'Posición perfecta',
        landmarks: landmarks,
        positioningHints: quality.hints,
      );
    } catch (e) {
      return ScannerAnalysisResult.error(
        'Error procesando imagen',
        feedback: 'Intenta de nuevo con mejor iluminación',
      );
    }
  }

  /// Valida que el cuerpo esté completo
  _ValidationResult _validateFullBody(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final requiredLandmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final missing = <String>[];
    for (final landmark in requiredLandmarks) {
      if (!landmarks.containsKey(landmark) || landmarks[landmark]!.likelihood < 0.5) {
        missing.add(_getLandmarkName(landmark));
      }
    }

    if (missing.isNotEmpty) {
      return _ValidationResult(
        isValid: false,
        message: 'Cuerpo incompleto',
        feedback: 'Asegúrate de que se vean: ${missing.join(", ")}',
      );
    }

    return _ValidationResult(isValid: true);
  }

  /// Valida la posición según el ángulo esperado
  _ValidationResult _validateAngle(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    AvatarAngle expectedAngle,
  ) {
    switch (expectedAngle) {
      case AvatarAngle.front:
        return _validateFrontAngle(landmarks);
      case AvatarAngle.rightSide:
        return _validateRightSideAngle(landmarks);
      case AvatarAngle.back:
        return _validateBackAngle(landmarks);
      case AvatarAngle.leftSide:
        return _validateLeftSideAngle(landmarks);
    }
  }

  _ValidationResult _validateFrontAngle(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final nose = landmarks[PoseLandmarkType.nose]!;

    // Verificar simetría
    final shoulderHeightDiff = (leftShoulder.y - rightShoulder.y).abs();
    final hipHeightDiff = (leftHip.y - rightHip.y).abs();

    if (shoulderHeightDiff > 0.1 || hipHeightDiff > 0.1) {
      return _ValidationResult(
        isValid: false,
        message: 'Postura inclinada',
        feedback: 'Mantén los hombros y caderas a la misma altura',
        hints: ['Endereza tu postura', 'Distribuye el peso equitativamente'],
      );
    }

    // Verificar que no está de lado
    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();
    if (shoulderDistance < 0.15) {
      return _ValidationResult(
        isValid: false,
        message: 'Estás de lado',
        feedback: 'Gira para estar completamente de frente',
        hints: ['Gira hacia la cámara', 'Mira directamente al lente'],
      );
    }

    // Verificar que no está de espaldas
    final noseToShoulderDist = (nose.y - leftShoulder.y).abs();
    if (noseToShoulderDist > 0.4) {
      return _ValidationResult(
        isValid: false,
        message: 'Estás de espaldas',
        feedback: 'Gira para estar de frente a la cámara',
        hints: ['Gira hacia la cámara', 'Mira al lente'],
      );
    }

    return _ValidationResult(isValid: true);
  }

  _ValidationResult _validateRightSideAngle(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final nose = landmarks[PoseLandmarkType.nose]!;

    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Debe estar de lado (hombros juntos)
    if (shoulderDistance > 0.15) {
      return _ValidationResult(
        isValid: false,
        message: 'No estás completamente de lado',
        feedback: 'Gira más para mostrar tu lado derecho',
        hints: ['Gira 90 grados', 'Tu lado derecho debe estar frente a la cámara'],
      );
    }

    // Verificar que es lado derecho (nariz a la derecha de los hombros)
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    if (nose.x < shoulderCenterX) {
      return _ValidationResult(
        isValid: false,
        message: 'Estás mostrando el lado izquierdo',
        feedback: 'Gira para mostrar tu lado derecho',
        hints: ['Gira hacia la derecha', 'Tu lado derecho debe estar frente a la cámara'],
      );
    }

    return _ValidationResult(isValid: true);
  }

  _ValidationResult _validateLeftSideAngle(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final nose = landmarks[PoseLandmarkType.nose]!;

    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Debe estar de lado (hombros juntos)
    if (shoulderDistance > 0.15) {
      return _ValidationResult(
        isValid: false,
        message: 'No estás completamente de lado',
        feedback: 'Gira más para mostrar tu lado izquierdo',
        hints: ['Gira 90 grados', 'Tu lado izquierdo debe estar frente a la cámara'],
      );
    }

    // Verificar que es lado izquierdo (nariz a la izquierda de los hombros)
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    if (nose.x > shoulderCenterX) {
      return _ValidationResult(
        isValid: false,
        message: 'Estás mostrando el lado derecho',
        feedback: 'Gira para mostrar tu lado izquierdo',
        hints: ['Gira hacia la izquierda', 'Tu lado izquierdo debe estar frente a la cámara'],
      );
    }

    return _ValidationResult(isValid: true);
  }

  _ValidationResult _validateBackAngle(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final nose = landmarks[PoseLandmarkType.nose]!;

    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Debe estar de frente (hombros separados)
    if (shoulderDistance < 0.15) {
      return _ValidationResult(
        isValid: false,
        message: 'No estás completamente de espaldas',
        feedback: 'Gira más para estar completamente de espaldas',
        hints: ['Gira 180 grados', 'Muestra tu espalda a la cámara'],
      );
    }

    // Verificar que está de espaldas (nariz no visible o muy arriba)
    final noseToShoulderDist = (nose.y - leftShoulder.y).abs();
    if (noseToShoulderDist < 0.3) {
      return _ValidationResult(
        isValid: false,
        message: 'Aún se ve tu cara',
        feedback: 'Gira completamente para estar de espaldas',
        hints: ['Gira hacia atrás', 'No mires a la cámara'],
      );
    }

    return _ValidationResult(isValid: true);
  }

  /// Calcula la calidad de la captura
  _CaptureQuality _calculateCaptureQuality(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    AvatarAngle angle,
  ) {
    double qualityScore = 1.0;
    final hints = <String>[];

    // Verificar confianza de los landmarks
    double avgConfidence = 0;
    int count = 0;
    for (final landmark in landmarks.values) {
      avgConfidence += landmark.likelihood;
      count++;
    }
    avgConfidence /= count;

    if (avgConfidence < 0.7) {
      qualityScore -= 0.2;
      hints.add('Mejora la iluminación');
    }

    // Verificar postura
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;

    final shoulderHeightDiff = (leftShoulder.y - rightShoulder.y).abs();
    final hipHeightDiff = (leftHip.y - rightHip.y).abs();

    if (shoulderHeightDiff > 0.05 || hipHeightDiff > 0.05) {
      qualityScore -= 0.1;
      hints.add('Endereza tu postura');
    }

    // Verificar distancia a la cámara
    final bodyHeight = (leftShoulder.y - leftHip.y).abs();
    if (bodyHeight < 0.3 || bodyHeight > 0.8) {
      qualityScore -= 0.15;
      hints.add('Ajusta la distancia a la cámara');
    }

    // Verificar centrado
    final bodyCenter = (leftShoulder.x + rightShoulder.x) / 2;
    if ((bodyCenter - 0.5).abs() > 0.2) {
      qualityScore -= 0.1;
      hints.add('Centra tu cuerpo en la pantalla');
    }

    qualityScore = qualityScore.clamp(0.0, 1.0);

    final quality = qualityScore > 0.85
        ? CaptureQualityLevel.excellent
        : qualityScore > 0.7
            ? CaptureQualityLevel.good
            : qualityScore > 0.5
                ? CaptureQualityLevel.fair
                : CaptureQualityLevel.poor;

    return _CaptureQuality(
      confidence: qualityScore,
      quality: quality,
      hints: hints,
    );
  }

  String _getLandmarkName(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return 'nariz';
      case PoseLandmarkType.leftShoulder:
        return 'hombro izquierdo';
      case PoseLandmarkType.rightShoulder:
        return 'hombro derecho';
      case PoseLandmarkType.leftHip:
        return 'cadera izquierda';
      case PoseLandmarkType.rightHip:
        return 'cadera derecha';
      case PoseLandmarkType.leftKnee:
        return 'rodilla izquierda';
      case PoseLandmarkType.rightKnee:
        return 'rodilla derecha';
      case PoseLandmarkType.leftAnkle:
        return 'tobillo izquierdo';
      case PoseLandmarkType.rightAnkle:
        return 'tobillo derecho';
      default:
        return 'parte del cuerpo';
    }
  }

  void dispose() {
    _poseDetector.close();
  }
}

/// Resultado del análisis de scanner
class ScannerAnalysisResult {
  final bool isSuccess;
  final double confidence;
  final CaptureQualityLevel quality;
  final String message;
  final String? feedback;
  final List<String> positioningHints;
  final Map<PoseLandmarkType, PoseLandmark>? landmarks;

  ScannerAnalysisResult({
    required this.isSuccess,
    required this.confidence,
    required this.quality,
    required this.message,
    this.feedback,
    required this.positioningHints,
    this.landmarks,
  });

  factory ScannerAnalysisResult.success({
    required double confidence,
    required CaptureQualityLevel quality,
    required String message,
    required List<String> positioningHints,
    Map<PoseLandmarkType, PoseLandmark>? landmarks,
  }) {
    return ScannerAnalysisResult(
      isSuccess: true,
      confidence: confidence,
      quality: quality,
      message: message,
      positioningHints: positioningHints,
      landmarks: landmarks,
    );
  }

  factory ScannerAnalysisResult.error(
    String message, {
    String? feedback,
    List<String> positioningHints = const [],
  }) {
    return ScannerAnalysisResult(
      isSuccess: false,
      confidence: 0.0,
      quality: CaptureQualityLevel.poor,
      message: message,
      feedback: feedback,
      positioningHints: positioningHints,
    );
  }
}

/// Niveles de calidad de captura
enum CaptureQualityLevel {
  excellent,
  good,
  fair,
  poor,
}

extension CaptureQualityLevelExtension on CaptureQualityLevel {
  String get displayName {
    switch (this) {
      case CaptureQualityLevel.excellent:
        return 'Excelente';
      case CaptureQualityLevel.good:
        return 'Buena';
      case CaptureQualityLevel.fair:
        return 'Aceptable';
      case CaptureQualityLevel.poor:
        return 'Pobre';
    }
  }

  Color get color {
    switch (this) {
      case CaptureQualityLevel.excellent:
        return Colors.green;
      case CaptureQualityLevel.good:
        return Colors.lightGreen;
      case CaptureQualityLevel.fair:
        return Colors.orange;
      case CaptureQualityLevel.poor:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case CaptureQualityLevel.excellent:
        return Icons.check_circle;
      case CaptureQualityLevel.good:
        return Icons.check_circle_outline;
      case CaptureQualityLevel.fair:
        return Icons.info;
      case CaptureQualityLevel.poor:
        return Icons.error_outline;
    }
  }
}

class _ValidationResult {
  final bool isValid;
  final String message;
  final String? feedback;
  final List<String> hints;

  _ValidationResult({
    required this.isValid,
    this.message = '',
    this.feedback,
    this.hints = const [],
  });
}

class _CaptureQuality {
  final double confidence;
  final CaptureQualityLevel quality;
  final List<String> hints;

  _CaptureQuality({
    required this.confidence,
    required this.quality,
    required this.hints,
  });
}
