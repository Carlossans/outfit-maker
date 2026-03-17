import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/multi_angle_avatar.dart';

/// Servicio para guiar la captura de fotos multi-ángulo del avatar
class MultiAngleCaptureService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
    ),
  );

  /// Verifica si la pose detectada corresponde al ángulo esperado
  Future<CaptureValidationResult> validateAngle(
    File imageFile,
    AvatarAngle expectedAngle,
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        return CaptureValidationResult.notValid(
          'No se detectó ninguna persona en la imagen',
        );
      }

      final pose = poses.first;
      final landmarks = pose.landmarks;

      // Verificar que es cuerpo completo
      final requiredLandmarks = [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      ];

      for (final landmark in requiredLandmarks) {
        if (!landmarks.containsKey(landmark)) {
          return CaptureValidationResult.notValid(
            'No se detectó el cuerpo completo. Asegúrate de que se vean cabeza, torso y pies.',
          );
        }
      }

      // Validar según el ángulo esperado
      switch (expectedAngle) {
        case AvatarAngle.front:
          return _validateFrontView(landmarks);
        case AvatarAngle.rightSide:
          return _validateRightSideView(landmarks);
        case AvatarAngle.back:
          return _validateBackView(landmarks);
        case AvatarAngle.leftSide:
          return _validateLeftSideView(landmarks);
      }
    } catch (e) {
      return CaptureValidationResult.notValid('Error procesando imagen: $e');
    }
  }

  /// Valida que la imagen sea de frente
  CaptureValidationResult _validateFrontView(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;

    // En vista frontal, ambos hombros deberían estar a la misma altura aproximadamente
    // y separados horizontalmente
    final shoulderHeightDiff = (leftShoulder.y - rightShoulder.y).abs();
    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Si los hombros están muy juntos, probablemente es vista lateral
    if (shoulderDistance < 0.1) {
      return CaptureValidationResult.notValid(
        'Parece que estás de lado. Por favor, posicionate de frente a la cámara.',
      );
    }

    // Verificar que no está de espaldas (la distancia entre hombros y caderas debe ser similar)
    final hipDistance = (leftHip.x - rightHip.x).abs();
    final shoulderToHipRatio = shoulderDistance / hipDistance;

    if (shoulderToHipRatio < 0.7 || shoulderToHipRatio > 1.4) {
      return CaptureValidationResult.notValid(
        'La proporción entre hombros y caderas parece incorrecta. Asegúrate de estar de frente.',
      );
    }

    // Calcular confianza basada en la simetría
    final confidence = _calculateConfidence(shoulderHeightDiff, 0.05, 0.15);

    return CaptureValidationResult.valid(
      confidence: confidence,
      message: 'Vista frontal detectada correctamente',
    );
  }

  /// Valida que la imagen sea del lado derecho
  CaptureValidationResult _validateRightSideView(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    return _validateSideView(landmarks, isRightSide: true);
  }

  /// Valida que la imagen sea del lado izquierdo
  CaptureValidationResult _validateLeftSideView(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    return _validateSideView(landmarks, isRightSide: false);
  }

  /// Valida vista lateral (compartida para derecho e izquierdo)
  CaptureValidationResult _validateSideView(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required bool isRightSide,
  }) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) {
      return CaptureValidationResult.notValid(
        'No se detectaron ambos hombros. Intenta con mejor iluminación.',
      );
    }

    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Si los hombros están muy separados, no es vista lateral
    if (shoulderDistance > 0.15) {
      return CaptureValidationResult.notValid(
        'Parece que estás de frente. Por favor, posicionate de lado.',
      );
    }

    // Determinar si es lado derecho o izquierdo basado en la posición
    final nose = landmarks[PoseLandmarkType.nose];
    if (nose != null) {
      // Verificar orientación basada en nariz respecto a hombros
      final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
      final facingDirection = nose.x > shoulderCenterX ? 'derecho' : 'izquierdo';

      final expectedSide = isRightSide ? 'derecho' : 'izquierdo';
      final detectedSide = facingDirection;

      if (isRightSide && detectedSide != 'derecho') {
        return CaptureValidationResult.notValid(
          'Parece que estás mostrando el lado izquierdo. Gira para mostrar el lado derecho.',
        );
      }

      if (!isRightSide && detectedSide != 'izquierdo') {
        return CaptureValidationResult.notValid(
          'Parece que estás mostrando el lado derecho. Gira para mostrando el lado izquierdo.',
        );
      }
    }

    final confidence = _calculateConfidence(shoulderDistance, 0.0, 0.1);

    return CaptureValidationResult.valid(
      confidence: confidence,
      message: 'Vista lateral ${isRightSide ? 'derecha' : 'izquierda'} detectada correctamente',
    );
  }

  /// Valida que la imagen sea de espaldas
  CaptureValidationResult _validateBackView(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    // Similar a la vista frontal pero sin visibilidad de cara
    // Usamos la distancia entre hombros como indicador
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final nose = landmarks[PoseLandmarkType.nose];

    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Si los hombros están muy juntos, es vista lateral
    if (shoulderDistance < 0.1) {
      return CaptureValidationResult.notValid(
        'Parece que estás de lado. Por favor, posicionate de espaldas.',
      );
    }

    // Si podemos ver la nariz claramente, probablemente es de frente
    if (nose != null) {
      final noseToShouldersY = (nose.y - leftShoulder.y).abs();
      if (noseToShouldersY < 0.3) {
        return CaptureValidationResult.notValid(
          'Se detecta la cara. Por favor, gira para mostrar la espalda.',
        );
      }
    }

    final confidence = _calculateConfidence(shoulderDistance, 0.1, 0.3);

    return CaptureValidationResult.valid(
      confidence: confidence,
      message: 'Vista trasera detectada correctamente',
    );
  }

  double _calculateConfidence(double value, double ideal, double tolerance) {
    final diff = (value - ideal).abs();
    if (diff <= tolerance) {
      return 1.0 - (diff / tolerance) * 0.3;
    }
    return 0.7;
  }

  void dispose() {
    _poseDetector.close();
  }
}

/// Resultado de validación de captura
class CaptureValidationResult {
  final bool isValid;
  final double confidence;
  final String message;
  final Map<String, dynamic>? metadata;

  CaptureValidationResult({
    required this.isValid,
    required this.confidence,
    required this.message,
    this.metadata,
  });

  factory CaptureValidationResult.valid({
    required double confidence,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    return CaptureValidationResult(
      isValid: true,
      confidence: confidence,
      message: message,
      metadata: metadata,
    );
  }

  factory CaptureValidationResult.notValid(String message) {
    return CaptureValidationResult(
      isValid: false,
      confidence: 0.0,
      message: message,
    );
  }
}

/// Guía de instrucciones para cada ángulo
class AngleGuidelines {
  static List<String> getInstructions(AvatarAngle angle) {
    final baseInstructions = [
      'Asegúrate de tener buena iluminación',
      'El fondo debe ser simple y despejado',
      'Ropa ajustada para mejor estimación de medidas',
      'De pie, postura natural',
    ];

    switch (angle) {
      case AvatarAngle.front:
        return [
          ...baseInstructions,
          'De frente a la cámara',
          'Brazos ligeramente separados del cuerpo',
          'Mira directamente a la cámara',
          'Asegúrate de que se vean pies y cabeza',
        ];
      case AvatarAngle.rightSide:
        return [
          ...baseInstructions,
          'De perfil mirando hacia tu izquierda',
          'Cuerpo completamente de lado',
          'Brazos a los lados',
          'Tu lado derecho debe estar de frente a la cámara',
        ];
      case AvatarAngle.back:
        return [
          ...baseInstructions,
          'De espaldas a la cámara',
          'Postura recta',
          'Asegúrate de que se vea toda la espalda',
          'Brazos ligeramente separados',
        ];
      case AvatarAngle.leftSide:
        return [
          ...baseInstructions,
          'De perfil mirando hacia tu derecha',
          'Cuerpo completamente de lado',
          'Brazos a los lados',
          'Tu lado izquierdo debe estar de frente a la cámara',
        ];
    }
  }

  static List<CaptureTip> getTips(AvatarAngle angle) {
    switch (angle) {
      case AvatarAngle.front:
        return [
          CaptureTip(
            icon: Icons.accessibility,
            title: 'Simetría',
            description: 'Mantén el peso distribuido equitativamente',
          ),
          CaptureTip(
            icon: Icons.height,
            title: 'Altura completa',
            description: 'La cámara debe capturar desde la cabeza hasta los pies',
          ),
        ];
      case AvatarAngle.rightSide:
        return [
          CaptureTip(
            icon: Icons.straighten,
            title: 'Perfil recto',
            description: 'Tu lado derecho completamente visible',
          ),
          CaptureTip(
            icon: Icons.arrow_forward,
            title: 'Orientación',
            description: 'Mira hacia tu izquierda, no a la cámara',
          ),
        ];
      case AvatarAngle.back:
        return [
          CaptureTip(
            icon: Icons.view_column,
            title: 'Espalda recta',
            description: 'Mantén la espalda erguida y relajada',
          ),
          CaptureTip(
            icon: Icons.height,
            title: 'Vista completa',
            description: 'Asegúrate de que se vean los talones',
          ),
        ];
      case AvatarAngle.leftSide:
        return [
          CaptureTip(
            icon: Icons.straighten,
            title: 'Perfil recto',
            description: 'Tu lado izquierdo completamente visible',
          ),
          CaptureTip(
            icon: Icons.arrow_back,
            title: 'Orientación',
            description: 'Mira hacia tu derecha, no a la cámara',
          ),
        ];
    }
  }
}

class CaptureTip {
  final IconData icon;
  final String title;
  final String description;

  CaptureTip({
    required this.icon,
    required this.title,
    required this.description,
  });
}
