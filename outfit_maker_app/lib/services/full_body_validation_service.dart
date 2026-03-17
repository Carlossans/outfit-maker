import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/user_measurements.dart';

/// Resultado de la validación de una foto de cuerpo entero
class FullBodyValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<Pose>? detectedPoses;
  final Map<String, dynamic>? bodyMetrics;

  const FullBodyValidationResult({
    required this.isValid,
    this.errorMessage,
    this.detectedPoses,
    this.bodyMetrics,
  });

  factory FullBodyValidationResult.invalid(String message) {
    return FullBodyValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }

  factory FullBodyValidationResult.valid(List<Pose> poses, Map<String, dynamic> metrics) {
    return FullBodyValidationResult(
      isValid: true,
      detectedPoses: poses,
      bodyMetrics: metrics,
    );
  }
}

/// Servicio para validar fotos de cuerpo entero y extraer medidas
class FullBodyValidationService {
  late final PoseDetector _poseDetector;

  FullBodyValidationService() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.single,
      ),
    );
  }

  /// Valida que una imagen contenga una foto de cuerpo entero
  /// Retorna el resultado de la validación con métricas del cuerpo si es válida
  Future<FullBodyValidationResult> validateFullBodyPhoto(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        return FullBodyValidationResult.invalid(
          'No se detectó ninguna persona en la imagen. Asegúrate de que:\n'
          '• Estés de pie y visible\n'
          '• La iluminación sea buena\n'
          '• No haya obstrucciones',
        );
      }

      if (poses.length > 1) {
        return FullBodyValidationResult.invalid(
          'Se detectaron ${poses.length} personas. Por favor, sube una foto donde solo aparezcas tú.',
        );
      }

      final pose = poses.first;
      final landmarks = pose.landmarks;

      // Verificar que se detecten los puntos clave necesarios para cuerpo entero
      final requiredLandmarks = [
        PoseLandmarkType.nose,           // Cabeza
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,        // Tobillo izquierdo
        PoseLandmarkType.rightAnkle,       // Tobillo derecho
      ];

      final missingLandmarks = requiredLandmarks
          .where((type) => !landmarks.containsKey(type) || landmarks[type]!.likelihood < 0.3)
          .toList();

      if (missingLandmarks.isNotEmpty) {
        final missingNames = missingLandmarks.map((t) => _getLandmarkName(t)).join(', ');
        return FullBodyValidationResult.invalid(
          'No se ve el cuerpo completo. Faltan detectar: $missingNames.\n\n'
          'Asegúrate de que:\n'
          '• La foto sea de cuerpo entero (cabeza a pies)\n'
          '• Estés de pie con los pies visibles\n'
          '• No estés sentado ni recortado',
        );
      }

      // Calcular métricas del cuerpo para estimar medidas
      final bodyMetrics = _calculateBodyMetrics(landmarks);

      // Verificar proporciones razonables
      if (!_hasReasonableProportions(bodyMetrics)) {
        return FullBodyValidationResult.invalid(
          'Las proporciones del cuerpo no parecen correctas.\n'
          'Asegúrate de:\n'
          '• Estar de pie derecho\n'
          '• No estar en ángulo extremo\n'
          '• La foto sea frontal o lateral',
        );
      }

      return FullBodyValidationResult.valid(poses, bodyMetrics);
    } catch (e) {
      debugPrint('Error validando foto: $e');
      return FullBodyValidationResult.invalid(
        'Error procesando la imagen. Intenta con otra foto.',
      );
    }
  }

  /// Extrae medidas estimadas de los landmarks detectados
  /// Nota: Estas son estimaciones basadas en proporciones, no medidas exactas
  UserMeasurements extractMeasurementsFromPose(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    double? knownHeight, // Si el usuario conoce su altura, usar para calibrar
  }) {
    // Obtener coordenadas normalizadas (0-1)
    final nose = landmarks[PoseLandmarkType.nose]!;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle]!;
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    // Calcular distancias en píxeles normalizados
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    final hipWidth = _distance(leftHip, rightHip);
    final bodyHeight = _distance(nose, _midpoint(leftAnkle, rightAnkle));

    // Estimar altura
    double estimatedHeight;
    if (knownHeight != null && knownHeight > 0) {
      estimatedHeight = knownHeight;
    } else {
      // Estimación basada en proporciones promedio
      // Altura típica = distancia nariz-tobillo * factor de corrección
      estimatedHeight = bodyHeight * 180; // Factor aproximado
    }

    // Estimar medidas basadas en proporciones del cuerpo
    // Estas son aproximaciones basadas en proporciones antropométricas promedio
    final estimatedShoulders = shoulderWidth * estimatedHeight * 0.8;
    final estimatedWaist = hipWidth * estimatedHeight * 0.75;
    final estimatedChest = estimatedShoulders * 1.05;
    final estimatedHips = hipWidth * estimatedHeight * 0.85;

    // Estimar peso basado en IMC promedio y altura
    final estimatedWeight = _estimateWeight(estimatedHeight, bodyHeight, shoulderWidth);

    return UserMeasurements(
      height: estimatedHeight.clamp(140.0, 220.0),
      weight: estimatedWeight.clamp(40.0, 150.0),
      shoulders: estimatedShoulders.clamp(35.0, 65.0),
      waist: estimatedWaist.clamp(50.0, 120.0),
      chest: estimatedChest.clamp(70.0, 140.0),
      hips: estimatedHips.clamp(70.0, 130.0),
    );
  }

  /// Calcula métricas del cuerpo para validación
  Map<String, dynamic> _calculateBodyMetrics(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final nose = landmarks[PoseLandmarkType.nose]!;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final leftKnee = landmarks[PoseLandmarkType.leftKnee]!;
    final rightKnee = landmarks[PoseLandmarkType.rightKnee]!;
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle]!;

    // Calcular distancias
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    final hipWidth = _distance(leftHip, rightHip);
    final torsoHeight = _distance(
      _midpoint(leftShoulder, rightShoulder),
      _midpoint(leftHip, rightHip),
    );
    final legHeight = _distance(
      _midpoint(leftHip, rightHip),
      _midpoint(leftAnkle, rightAnkle),
    );
    final totalHeight = _distance(nose, _midpoint(leftAnkle, rightAnkle));

    return {
      'shoulderWidth': shoulderWidth,
      'hipWidth': hipWidth,
      'torsoHeight': torsoHeight,
      'legHeight': legHeight,
      'totalHeight': totalHeight,
      'torsoToLegRatio': torsoHeight / (legHeight > 0 ? legHeight : 1),
      'shoulderToHipRatio': shoulderWidth / (hipWidth > 0 ? hipWidth : 1),
    };
  }

  /// Verifica si las proporciones del cuerpo son razonables
  bool _hasReasonableProportions(Map<String, dynamic> metrics) {
    final torsoToLegRatio = metrics['torsoToLegRatio'] as double;
    final shoulderToHipRatio = metrics['shoulderToHipRatio'] as double;

    // Proporciones típicas del cuerpo humano
    // Torso:piernas suele estar entre 0.8 y 1.2 (aproximadamente mitad y mitad)
    if (torsoToLegRatio < 0.5 || torsoToLegRatio > 1.5) {
      return false;
    }

    // Hombros:caderas suele estar entre 0.8 y 1.5
    if (shoulderToHipRatio < 0.6 || shoulderToHipRatio > 1.8) {
      return false;
    }

    return true;
  }

  /// Estima el peso basado en proporciones del cuerpo
  double _estimateWeight(double height, double bodyHeight, double shoulderWidth) {
    // Fórmula simplificada basada en IMC promedio (22)
    final heightInMeters = height / 100;
    final baseWeight = 22 * heightInMeters * heightInMeters;

    // Ajustar según anchura de hombros (indicador de complexión)
    final shoulderFactor = (shoulderWidth - 0.3) * 50; // Normalizar

    return baseWeight + shoulderFactor;
  }

  /// Calcula distancia euclidiana entre dos landmarks
  double _distance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calcula punto medio entre dos landmarks
  PoseLandmark _midpoint(PoseLandmark a, PoseLandmark b) {
    return PoseLandmark(
      type: PoseLandmarkType.nose, // Placeholder
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      likelihood: (a.likelihood + b.likelihood) / 2,
    );
  }

  /// Obtiene nombre legible de un landmark
  String _getLandmarkName(PoseLandmarkType type) {
    final names = {
      PoseLandmarkType.nose: 'cabeza',
      PoseLandmarkType.leftShoulder: 'hombro izquierdo',
      PoseLandmarkType.rightShoulder: 'hombro derecho',
      PoseLandmarkType.leftHip: 'cadera izquierda',
      PoseLandmarkType.rightHip: 'cadera derecha',
      PoseLandmarkType.leftKnee: 'rodilla izquierda',
      PoseLandmarkType.rightKnee: 'rodilla derecha',
      PoseLandmarkType.leftAnkle: 'tobillo izquierdo',
      PoseLandmarkType.rightAnkle: 'tobillo derecho',
    };
    return names[type] ?? type.toString().split('.').last;
  }

  void dispose() {
    _poseDetector.close();
  }
}
