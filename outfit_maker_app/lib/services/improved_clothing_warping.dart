import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';

/// Servicio mejorado para deformar prendas y ajustarlas al cuerpo
/// Usa técnicas avanzadas de transformación de perspectiva y deformación elástica
class ImprovedClothingWarpingService {
  static final ImprovedClothingWarpingService _instance = ImprovedClothingWarpingService._internal();
  factory ImprovedClothingWarpingService() => _instance;
  ImprovedClothingWarpingService._internal();

  /// Transforma una prenda para ajustarse a la silueta del cuerpo con alta precisión
  Future<File?> warpClothingToBody({
    required File clothingImage,
    required Map<String, ui.Offset> bodyAnchors,
    required ClothingType type,
    required Size targetSize,
    UserMeasurements? measurements,
  }) async {
    try {
      // Cargar imagen de la prenda
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final clothing = frame.image;

      // Calcular puntos de control basados en el tipo de prenda
      final controlPoints = _calculateControlPoints(
        clothing: clothing,
        bodyAnchors: bodyAnchors,
        type: type,
        measurements: measurements,
      );

      // Aplicar transformación de malla (mesh warping)
      final warpedImage = await _applyMeshWarping(
        source: clothing,
        controlPoints: controlPoints,
        targetSize: targetSize,
      );

      // Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/warped_improved_${DateTime.now().millisecondsSinceEpoch}.png');

      final byteData = await warpedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());
      return resultFile;
    } catch (e) {
      debugPrint('Error en warping mejorado: $e');
      return null;
    }
  }

  /// Calcula puntos de control para la transformación
  List<ControlPoint> _calculateControlPoints({
    required ui.Image clothing,
    required Map<String, ui.Offset> bodyAnchors,
    required ClothingType type,
    UserMeasurements? measurements,
  }) {
    final points = <ControlPoint>[];
    final width = clothing.width.toDouble();
    final height = clothing.height.toDouble();

    // Factores de ajuste basados en medidas
    final heightFactor = (measurements?.height ?? 170) / 170;
    final shoulderFactor = (measurements?.shoulders ?? 45) / 45;
    final waistFactor = (measurements?.waist ?? 80) / 80;

    switch (type) {
      case ClothingType.top:
        // Puntos de control para parte superior
        points.add(ControlPoint(
          source: const ui.Offset(0, 0),
          target: bodyAnchors['topLeft'] ?? ui.Offset(0, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width, 0),
          target: bodyAnchors['topRight'] ?? ui.Offset(width, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(0, height * 0.6),
          target: bodyAnchors['bottomLeft'] ?? ui.Offset(0, height * 0.6),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width, height * 0.6),
          target: bodyAnchors['bottomRight'] ?? ui.Offset(width, height * 0.6),
        ));
        // Puntos intermedios para mejor deformación
        points.add(ControlPoint(
          source: ui.Offset(width * 0.5, 0),
          target: ui.Offset(
            ((bodyAnchors['topLeft']?.dx ?? 0) + (bodyAnchors['topRight']?.dx ?? width)) / 2,
            ((bodyAnchors['topLeft']?.dy ?? 0) + (bodyAnchors['topRight']?.dy ?? 0)) / 2,
          ),
        ));
        break;

      case ClothingType.bottom:
        // Puntos de control para parte inferior
        points.add(ControlPoint(
          source: const ui.Offset(0, 0),
          target: bodyAnchors['topLeft'] ?? ui.Offset(0, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width, 0),
          target: bodyAnchors['topRight'] ?? ui.Offset(width, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(0, height * 0.8),
          target: bodyAnchors['bottomLeft'] ?? ui.Offset(0, height * 0.8),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width, height * 0.8),
          target: bodyAnchors['bottomRight'] ?? ui.Offset(width, height * 0.8),
        ));
        break;

      case ClothingType.headwear:
        // Puntos de control para cabeza
        final center = bodyAnchors['center'] ?? ui.Offset(width / 2, height / 2);
        points.add(ControlPoint(
          source: ui.Offset(width * 0.5, height * 0.5),
          target: center,
        ));
        points.add(ControlPoint(
          source: const ui.Offset(0, 0),
          target: bodyAnchors['left'] ?? ui.Offset(0, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width, 0),
          target: bodyAnchors['right'] ?? ui.Offset(width, 0),
        ));
        break;

      case ClothingType.footwear:
        // Puntos de control para calzado
        points.add(ControlPoint(
          source: ui.Offset(width * 0.25, height * 0.5),
          target: bodyAnchors['left'] ?? ui.Offset(width * 0.25, height * 0.5),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width * 0.75, height * 0.5),
          target: bodyAnchors['right'] ?? ui.Offset(width * 0.75, height * 0.5),
        ));
        break;

      case ClothingType.neckwear:
        // Puntos de control para cuello
        points.add(ControlPoint(
          source: ui.Offset(width * 0.5, 0),
          target: bodyAnchors['top'] ?? ui.Offset(width * 0.5, 0),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width * 0.5, height),
          target: bodyAnchors['bottom'] ?? ui.Offset(width * 0.5, height),
        ));
        points.add(ControlPoint(
          source: ui.Offset(width * 0.5, height * 0.5),
          target: bodyAnchors['center'] ?? ui.Offset(width * 0.5, height * 0.5),
        ));
        break;
    }

    return points;
  }

  /// Aplica warping de malla con interpolación suave
  Future<ui.Image> _applyMeshWarping({
    required ui.Image source,
    required List<ControlPoint> controlPoints,
    required Size targetSize,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Crear malla de deformación
    final mesh = _createDeformationMesh(
      sourceSize: Size(source.width.toDouble(), source.height.toDouble()),
      controlPoints: controlPoints,
      targetSize: targetSize,
    );

    // Dibujar malla deformada
    for (final quad in mesh) {
      _drawWarpedQuad(canvas, source, quad);
    }

    final picture = recorder.endRecording();
    final result = await picture.toImage(
      targetSize.width.ceil(),
      targetSize.height.ceil(),
    );

    picture.dispose();
    return result;
  }

  /// Crea una malla de deformación basada en puntos de control
  List<WarpQuad> _createDeformationMesh({
    required Size sourceSize,
    required List<ControlPoint> controlPoints,
    required Size targetSize,
  }) {
    final quads = <WarpQuad>[];

    // Grid de subdivisión
    const divisionsX = 8;
    const divisionsY = 8;

    for (int y = 0; y < divisionsY; y++) {
      for (int x = 0; x < divisionsX; x++) {
        final srcX1 = (x / divisionsX) * sourceSize.width;
        final srcY1 = (y / divisionsY) * sourceSize.height;
        final srcX2 = ((x + 1) / divisionsX) * sourceSize.width;
        final srcY2 = ((y + 1) / divisionsY) * sourceSize.height;

        // Calcular posiciones destino interpolando puntos de control
        final dstX1 = _interpolatePosition(srcX1, srcY1, controlPoints, targetSize).dx;
        final dstY1 = _interpolatePosition(srcX1, srcY1, controlPoints, targetSize).dy;
        final dstX2 = _interpolatePosition(srcX2, srcY2, controlPoints, targetSize).dx;
        final dstY2 = _interpolatePosition(srcX2, srcY2, controlPoints, targetSize).dy;

        quads.add(WarpQuad(
          sourceRect: Rect.fromLTRB(srcX1, srcY1, srcX2, srcY2),
          targetRect: Rect.fromLTRB(dstX1, dstY1, dstX2, dstY2),
        ));
      }
    }

    return quads;
  }

  /// Interpola posición basada en puntos de control cercanos
  ui.Offset _interpolatePosition(double x, double y, List<ControlPoint> controlPoints, Size targetSize) {
    if (controlPoints.isEmpty) return ui.Offset(x, y);

    double totalWeight = 0;
    double sumX = 0;
    double sumY = 0;

    for (final cp in controlPoints) {
      final distance = (cp.source - ui.Offset(x, y)).distance;
      final weight = 1.0 / (distance + 1.0); // Evitar división por cero

      sumX += cp.target.dx * weight;
      sumY += cp.target.dy * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return ui.Offset(x, y);

    return ui.Offset(sumX / totalWeight, sumY / totalWeight);
  }

  /// Dibuja un cuadrilátero deformado
  void _drawWarpedQuad(Canvas canvas, ui.Image source, WarpQuad quad) {
    final srcRect = quad.sourceRect;
    final dstRect = quad.targetRect;

    // Dibujar imagen con transformación
    final paint = Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    // Usar drawImageRect para mapear la porción de la imagen
    canvas.drawImageRect(
      source,
      srcRect,
      dstRect,
      paint,
    );
  }

  /// Aplica suavizado a los bordes de la prenda
  Future<File?> smoothClothingEdges(File clothingImage, {double smoothness = 0.5}) async {
    try {
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Dibujar imagen original
      canvas.drawImage(image, Offset.zero, Paint()..filterQuality = ui.FilterQuality.high);

      // Aplicar suavizado en bordes
      final smoothPaint = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, smoothness)
        ..blendMode = ui.BlendMode.srcOver;

      canvas.drawImage(image, Offset.zero, smoothPaint);

      final picture = recorder.endRecording();
      final result = await picture.toImage(image.width, image.height);

      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/smoothed_${DateTime.now().millisecondsSinceEpoch}.png');

      final byteData = await result.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());
      return resultFile;
    } catch (e) {
      debugPrint('Error suavizando bordes: $e');
      return null;
    }
  }
}

/// Representa un punto de control para warping
class ControlPoint {
  final ui.Offset source;
  final ui.Offset target;

  ControlPoint({required this.source, required this.target});
}

/// Representa un cuadrilátero de deformación
class WarpQuad {
  final Rect sourceRect;
  final Rect targetRect;

  WarpQuad({required this.sourceRect, required this.targetRect});
}
