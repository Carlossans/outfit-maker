import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

class AvatarPainter extends CustomPainter {
  final List<Pose> poses;
  final List<ui.Image> clothingImages;
  final List<ClothingItem> outfit;
  final bool showDebugPoints;

  AvatarPainter(
    this.poses,
    this.clothingImages,
    this.outfit, {
    this.showDebugPoints = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final pose = poses.first;

    // Obtener puntos clave del cuerpo
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final nose = landmarks[PoseLandmarkType.nose];

    if (leftShoulder == null || rightShoulder == null) {
      debugPrint('No se detectaron hombros');
      return;
    }

    // Calcular dimensiones del cuerpo
    final bodyMetrics = _calculateBodyMetrics(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
      leftKnee: leftKnee,
      rightKnee: rightKnee,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
      nose: nose,
    );

    // Dibujar debug points si está habilitado
    if (showDebugPoints) {
      _drawDebugPoints(canvas, pose);
    }

    // Dibujar cada prenda en su posición correspondiente
    for (int i = 0; i < clothingImages.length && i < outfit.length; i++) {
      final image = clothingImages[i];
      final item = outfit[i];

      _drawClothingItem(
        canvas,
        image,
        item.type,
        bodyMetrics,
      );
    }
  }

  /// Calcula las métricas del cuerpo para posicionar la ropa
  BodyMetrics _calculateBodyMetrics({
    required PoseLandmark leftShoulder,
    required PoseLandmark rightShoulder,
    PoseLandmark? leftHip,
    PoseLandmark? rightHip,
    PoseLandmark? leftKnee,
    PoseLandmark? rightKnee,
    PoseLandmark? leftAnkle,
    PoseLandmark? rightAnkle,
    PoseLandmark? nose,
  }) {
    // Ancho de hombros
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;

    // Altura del torso
    double torsoHeight = shoulderWidth * 1.2; // Estimación por defecto
    double hipY = shoulderY + torsoHeight;
    double hipCenterX = shoulderCenterX;

    if (leftHip != null && rightHip != null) {
      hipCenterX = (leftHip.x + rightHip.x) / 2;
      hipY = (leftHip.y + rightHip.y) / 2;
      torsoHeight = hipY - shoulderY;
    }

    // Altura hasta rodillas
    double kneeY = hipY + torsoHeight;
    if (leftKnee != null && rightKnee != null) {
      kneeY = (leftKnee.y + rightKnee.y) / 2;
    }

    // Altura hasta tobillos
    double ankleY = kneeY + torsoHeight;
    if (leftAnkle != null && rightAnkle != null) {
      ankleY = (leftAnkle.y + rightAnkle.y) / 2;
    }

    // Altura de la cabeza
    double headY = shoulderY - shoulderWidth * 0.8;
    if (nose != null) {
      headY = nose.y - shoulderWidth * 0.3;
    }

    return BodyMetrics(
      shoulderWidth: shoulderWidth,
      shoulderCenterX: shoulderCenterX,
      shoulderY: shoulderY,
      hipCenterX: hipCenterX,
      hipY: hipY,
      torsoHeight: torsoHeight,
      kneeY: kneeY,
      ankleY: ankleY,
      headY: headY,
    );
  }

  /// Dibuja una prenda en su posición correspondiente
  void _drawClothingItem(
    Canvas canvas,
    ui.Image image,
    ClothingType type,
    BodyMetrics metrics,
  ) {
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    Rect dstRect;
    double rotation = 0;

    switch (type) {
      case ClothingType.top:
        dstRect = _calculateTopRect(metrics);
        break;
      case ClothingType.bottom:
        dstRect = _calculateBottomRect(metrics);
        break;
      case ClothingType.headwear:
        dstRect = _calculateHeadwearRect(metrics);
        break;
      case ClothingType.footwear:
        dstRect = _calculateFootwearRect(metrics);
        break;
      case ClothingType.neckwear:
        dstRect = _calculateNeckwearRect(metrics);
        break;
    }

    // Ajustar proporciones manteniendo aspect ratio
    dstRect = _adjustAspectRatio(srcRect, dstRect);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    // Si hay rotación, aplicar transformación
    if (rotation != 0) {
      canvas.save();
      canvas.translate(dstRect.center.dx, dstRect.center.dy);
      canvas.rotate(rotation);
      canvas.translate(-dstRect.center.dx, -dstRect.center.dy);
      canvas.drawImageRect(image, srcRect, dstRect, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, srcRect, dstRect, paint);
    }
  }

  /// Calcula el rectángulo para prendas superiores
  Rect _calculateTopRect(BodyMetrics m) {
    // La prenda superior cubre desde los hombros hasta la cintura
    final width = m.shoulderWidth * 1.1; // Un poco más ancho que los hombros
    final height = m.torsoHeight * 0.9;
    final left = m.shoulderCenterX - width / 2;
    final top = m.shoulderY - height * 0.1;

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Calcula el rectángulo para prendas inferiores
  Rect _calculateBottomRect(BodyMetrics m) {
    // Los pantalones/faldas van desde la cadera hasta las rodillas
    final width = m.shoulderWidth * 0.9;
    final height = m.kneeY - m.hipY;
    final left = m.hipCenterX - width / 2;
    final top = m.hipY - height * 0.1;

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Calcula el rectángulo para accesorios de cabeza
  Rect _calculateHeadwearRect(BodyMetrics m) {
    // Gorras/sombreros van en la cabeza
    final width = m.shoulderWidth * 0.6;
    final height = width * 0.5;
    final left = m.shoulderCenterX - width / 2;
    final top = m.headY - height * 0.5;

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Calcula el rectángulo para calzado
  Rect _calculateFootwearRect(BodyMetrics m) {
    // Zapatos van en los pies
    final width = m.shoulderWidth * 0.35;
    final height = width * 0.6;
    final left = m.shoulderCenterX - width / 2;
    final top = m.ankleY - height;

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Calcula el rectángulo para accesorios de cuello
  Rect _calculateNeckwearRect(BodyMetrics m) {
    // Corbatas/pañuelos van en el cuello
    final width = m.shoulderWidth * 0.4;
    final height = m.torsoHeight * 0.3;
    final left = m.shoulderCenterX - width / 2;
    final top = m.shoulderY + height * 0.2;

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Ajusta el rectángulo destino para mantener el aspect ratio
  Rect _adjustAspectRatio(Rect src, Rect dst) {
    final srcAspect = src.width / src.height;
    final dstAspect = dst.width / dst.height;

    if (srcAspect > dstAspect) {
      // La imagen es más ancha que el destino
      final newHeight = dst.width / srcAspect;
      final diff = dst.height - newHeight;
      return Rect.fromLTWH(dst.left, dst.top + diff / 2, dst.width, newHeight);
    } else {
      // La imagen es más alta que el destino
      final newWidth = dst.height * srcAspect;
      final diff = dst.width - newWidth;
      return Rect.fromLTWH(dst.left + diff / 2, dst.top, newWidth, dst.height);
    }
  }

  /// Dibuja puntos de referencia para debug
  void _drawDebugPoints(Canvas canvas, Pose pose) {
    // Puntos del cuerpo
    final bodyPaint = Paint()
      ..color = Colors.green.withAlpha(200)
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;

    // Conexiones del cuerpo
    final connectionPaint = Paint()
      ..color = Colors.blue.withAlpha(150)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dibujar puntos
    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(
        Offset(landmark.x, landmark.y),
        8,
        bodyPaint,
      );
    }

    // Dibujar conexiones principales
    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    for (final connection in connections) {
      final start = pose.landmarks[connection[0]];
      final end = pose.landmarks[connection[1]];
      if (start != null && end != null) {
        canvas.drawLine(
          Offset(start.x, start.y),
          Offset(end.x, end.y),
          connectionPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Pintor para visualizar la máscara de segmentación corporal
class SegmentationMaskPainter extends CustomPainter {
  final SegmentationMask mask;
  final bool showFullBody;

  SegmentationMaskPainter(this.mask, {this.showFullBody = false});

  @override
  void paint(Canvas canvas, Size size) {
    final maskData = mask.confidences;
    final width = mask.width;
    final height = mask.height;

    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    // Dibujar pixels con confianza > 0.5
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        final confidence = maskData[idx];

        if (confidence > 0.5) {
          final alpha = (confidence * 100).clamp(0, 255).toInt();
          paint.color = Colors.blue.withAlpha(alpha);

          final scaleX = size.width / width;
          final scaleY = size.height / height;

          canvas.drawRect(
            Rect.fromLTWH(x * scaleX, y * scaleY, scaleX, scaleY),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Métricas del cuerpo para posicionamiento de ropa
class BodyMetrics {
  final double shoulderWidth;
  final double shoulderCenterX;
  final double shoulderY;
  final double hipCenterX;
  final double hipY;
  final double torsoHeight;
  final double kneeY;
  final double ankleY;
  final double headY;

  BodyMetrics({
    required this.shoulderWidth,
    required this.shoulderCenterX,
    required this.shoulderY,
    required this.hipCenterX,
    required this.hipY,
    required this.torsoHeight,
    required this.kneeY,
    required this.ankleY,
    required this.headY,
  });
}
