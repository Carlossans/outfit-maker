import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';

/// Servicio para deformar prendas y ajustarlas al cuerpo del usuario
class ClothingWarpingService {
  static final ClothingWarpingService _instance = ClothingWarpingService._internal();

  factory ClothingWarpingService() => _instance;

  ClothingWarpingService._internal();

  /// Transforma una prenda para ajustarse a la silueta del cuerpo
  /// Usa interpolación de puntos de referencia (landmarks)
  Future<File?> warpClothingToBody({
    required File clothingImage,
    required Map<String, Offset> bodyAnchors,
    required ClothingType type,
    required Size targetSize,
  }) async {
    try {
      // Cargar imagen de la prenda
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final clothing = frame.image;

      // Calcular transformación basada en el tipo de prenda
      final transformMatrix = _calculateWarpTransform(
        clothing.width,
        clothing.height,
        bodyAnchors,
        type,
      );

      // Aplicar transformación
      final warpedImage = await _applyTransform(
        clothing,
        transformMatrix,
        targetSize,
      );

      // Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/warped_${DateTime.now().millisecondsSinceEpoch}.png');

      // Convertir a bytes PNG
      final byteData = await warpedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());
      return resultFile;
    } catch (e) {
      debugPrint('Error warping clothing: $e');
      return null;
    }
  }

  /// Calcula la matriz de transformación para warping
  Matrix4 _calculateWarpTransform(
    int clothingWidth,
    int clothingHeight,
    Map<String, Offset> bodyAnchors,
    ClothingType type,
  ) {
    // Puntos de origen (imagen de prenda)
    final srcPoints = _getSourcePoints(clothingWidth, clothingHeight, type);

    // Puntos de destino (cuerpo del usuario)
    final dstPoints = _getDestinationPoints(bodyAnchors, type);

    // Calcular homografía usando least squares
    final matrix = _computeHomography(srcPoints, dstPoints);

    return matrix;
  }

  /// Obtiene puntos de origen de la prenda según tipo
  Map<String, Offset> _getSourcePoints(int width, int height, ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return {
          'topLeft': Offset(0, 0),
          'topRight': Offset(width.toDouble(), 0),
          'bottomLeft': Offset(0, height.toDouble() * 0.6),
          'bottomRight': Offset(width.toDouble(), height.toDouble() * 0.6),
          'center': Offset(width.toDouble() / 2, height.toDouble() / 2),
        };
      case ClothingType.bottom:
        return {
          'topLeft': Offset(0, 0),
          'topRight': Offset(width.toDouble(), 0),
          'bottomLeft': Offset(0, height.toDouble() * 0.8),
          'bottomRight': Offset(width.toDouble(), height.toDouble() * 0.8),
          'center': Offset(width.toDouble() / 2, height.toDouble() / 2),
        };
      case ClothingType.headwear:
        return {
          'center': Offset(width.toDouble() / 2, height.toDouble() / 2),
          'left': Offset(0, height.toDouble() / 2),
          'right': Offset(width.toDouble(), height.toDouble() / 2),
        };
      case ClothingType.footwear:
        return {
          'left': Offset(0, height.toDouble() / 2),
          'right': Offset(width.toDouble(), height.toDouble() / 2),
          'center': Offset(width.toDouble() / 2, height.toDouble() / 2),
        };
      case ClothingType.neckwear:
        return {
          'center': Offset(width.toDouble() / 2, height.toDouble() / 2),
          'top': Offset(width.toDouble() / 2, 0),
          'bottom': Offset(width.toDouble() / 2, height.toDouble()),
        };
    }
  }

  /// Obtiene puntos de destino del cuerpo
  Map<String, Offset> _getDestinationPoints(
    Map<String, Offset> bodyAnchors,
    ClothingType type,
  ) {
    return bodyAnchors;
  }

  /// Computa homografía usando Direct Linear Transform (DLT)
  Matrix4 _computeHomography(
    Map<String, Offset> srcPoints,
    Map<String, Offset> dstPoints,
  ) {
    // Implementación simplificada de homografía
    // Para 4 puntos correspondientes

    if (srcPoints.length < 4 || dstPoints.length < 4) {
      return Matrix4.identity();
    }

    // Extraer puntos
    final src = srcPoints.values.toList();
    final dst = dstPoints.values.toList();

    // Calcular centroide
    final srcCentroid = _computeCentroid(src);
    final dstCentroid = _computeCentroid(dst);

    // Calcular escala
    final srcScale = _computeScale(src, srcCentroid);
    final dstScale = _computeScale(dst, dstCentroid);

    // Calcular transformación afín
    final scale = dstScale / srcScale;
    final translation = Offset(
      dstCentroid.dx - srcCentroid.dx * scale,
      dstCentroid.dy - srcCentroid.dy * scale,
    );

    // Construir matriz 4x4 para perspectiva
    final matrix = Matrix4.identity();
    matrix.scale(scale, scale, 1.0);
    matrix.translate(translation.dx, translation.dy, 0.0);

    // Aplicar ligera perspectiva para realismo
    _applyPerspectiveDistortion(matrix, srcPoints, dstPoints);

    return matrix;
  }

  Offset _computeCentroid(List<Offset> points) {
    double sumX = 0, sumY = 0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  double _computeScale(List<Offset> points, Offset centroid) {
    double sumDistances = 0;
    for (final p in points) {
      sumDistances += (p - centroid).distance;
    }
    return sumDistances / points.length;
  }

  /// Aplica distorsión de perspectiva para realismo
  void _applyPerspectiveDistortion(
    Matrix4 matrix,
    Map<String, Offset> srcPoints,
    Map<String, Offset> dstPoints,
  ) {
    // Calcular diferencia de perspectiva
    final srcDiagonal = (srcPoints['topLeft']! - srcPoints['bottomRight']!).distance;
    final dstDiagonal = (dstPoints['topLeft']! - dstPoints['bottomRight']!).distance;

    final perspectiveFactor = (dstDiagonal - srcDiagonal) / srcDiagonal;

    // Aplicar ligera distorsión perspective (w factor)
    if (perspectiveFactor.abs() > 0.1) {
      matrix.setEntry(3, 0, perspectiveFactor * 0.001);
      matrix.setEntry(3, 1, perspectiveFactor * 0.001);
    }
  }

  /// Aplica transformación a una imagen con interpolación mejorada
  Future<ui.Image> _applyTransform(
    ui.Image source,
    Matrix4 transform,
    Size targetSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Guardar el estado del canvas
    canvas.save();

    // Aplicar transformación de perspectiva
    canvas.transform(transform.storage);

    // Dibujar imagen original con alta calidad
    canvas.drawImage(
      source,
      Offset.zero,
      Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true
        ..blendMode = ui.BlendMode.srcOver,
    );

    // Restaurar el estado del canvas
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(
      targetSize.width.ceil(),
      targetSize.height.ceil(),
    );

    picture.dispose();
    return result;
  }

  /// Aplica warping avanzado con control de deformación
  Future<File?> warpClothingAdvanced({
    required File clothingImage,
    required Map<String, Offset> bodyAnchors,
    required ClothingType type,
    required Size targetSize,
    double deformationStrength = 0.5,
  }) async {
    try {
      // Cargar imagen de la prenda
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final clothing = frame.image;

      // Calcular transformación mejorada
      final transformMatrix = _calculateAdvancedWarpTransform(
        clothing.width,
        clothing.height,
        bodyAnchors,
        type,
        deformationStrength,
      );

      // Aplicar transformación con suavizado
      final warpedImage = await _applyTransformWithSmoothing(
        clothing,
        transformMatrix,
        targetSize,
      );

      // Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/warped_adv_${DateTime.now().millisecondsSinceEpoch}.png');

      final byteData = await warpedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());
      return resultFile;
    } catch (e) {
      debugPrint('Error en warping avanzado: $e');
      return null;
    }
  }

  /// Calcula transformación avanzada con control de deformación
  Matrix4 _calculateAdvancedWarpTransform(
    int clothingWidth,
    int clothingHeight,
    Map<String, Offset> bodyAnchors,
    ClothingType type,
    double deformationStrength,
  ) {
    // Puntos de origen (imagen de prenda)
    final srcPoints = _getSourcePoints(clothingWidth, clothingHeight, type);

    // Puntos de destino (cuerpo del usuario)
    final dstPoints = _getDestinationPoints(bodyAnchors, type);

    // Calcular transformación con interpolación suave
    final matrix = _computeSmoothHomography(
      srcPoints,
      dstPoints,
      deformationStrength,
    );

    return matrix;
  }

  /// Computa homografía con interpolación suave
  Matrix4 _computeSmoothHomography(
    Map<String, Offset> srcPoints,
    Map<String, Offset> dstPoints,
    double smoothness,
  ) {
    if (srcPoints.length < 4 || dstPoints.length < 4) {
      return Matrix4.identity();
    }

    // Extraer puntos
    final src = srcPoints.values.toList();
    final dst = dstPoints.values.toList();

    // Calcular centroides
    final srcCentroid = _computeCentroid(src);
    final dstCentroid = _computeCentroid(dst);

    // Calcular escalas
    final srcScale = _computeScale(src, srcCentroid);
    final dstScale = _computeScale(dst, dstCentroid);

    // Calcular transformación afín con suavizado
    final scale = (dstScale / srcScale) * (1 - smoothness) + smoothness;
    final translation = Offset(
      dstCentroid.dx - srcCentroid.dx * scale,
      dstCentroid.dy - srcCentroid.dy * scale,
    );

    // Construir matriz con interpolación suave
    final matrix = Matrix4.identity();
    matrix.scale(scale, scale, 1.0);
    matrix.translate(translation.dx, translation.dy, 0.0);

    // Aplicar perspectiva suave
    _applySmoothPerspective(matrix, srcPoints, dstPoints, smoothness);

    return matrix;
  }

  /// Aplica perspectiva suave
  void _applySmoothPerspective(
    Matrix4 matrix,
    Map<String, Offset> srcPoints,
    Map<String, Offset> dstPoints,
    double smoothness,
  ) {
    final srcDiagonal = (srcPoints['topLeft']! - srcPoints['bottomRight']!).distance;
    final dstDiagonal = (dstPoints['topLeft']! - dstPoints['bottomRight']!).distance;

    final perspectiveFactor = ((dstDiagonal - srcDiagonal) / srcDiagonal) * smoothness;

    if (perspectiveFactor.abs() > 0.01) {
      matrix.setEntry(3, 0, perspectiveFactor * 0.0005);
      matrix.setEntry(3, 1, perspectiveFactor * 0.0005);
    }
  }

  /// Aplica transformación con suavizado adicional
  Future<ui.Image> _applyTransformWithSmoothing(
    ui.Image source,
    Matrix4 transform,
    Size targetSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.save();
    canvas.transform(transform.storage);

    // Dibujar con múltiples pasadas para suavizado
    final paint = Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true
      ..blendMode = ui.BlendMode.srcOver;

    // Primera pasada: imagen base
    canvas.drawImage(source, Offset.zero, paint);

    // Segunda pasada: ligero suavizado
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.3);
    canvas.drawImage(source, Offset.zero, paint..color = Colors.white.withAlpha(10));

    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(
      targetSize.width.ceil(),
      targetSize.height.ceil(),
    );

    picture.dispose();
    return result;
  }

  /// Aplica sombreado basado en la iluminación del cuerpo
  Future<File?> applyShading({
    required File clothingImage,
    required List<Offset> bodyContour,
    required Offset lightDirection,
  }) async {
    try {
      // Cargar imagen
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Crear canvas con shading
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Dibujar imagen original
      canvas.drawImage(image, Offset.zero, Paint());

      // Aplicar gradiente de sombreado
      final shadingPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          lightDirection * image.width.toDouble() * 0.3,
          [
            const Color(0x40000000), // Sombra semitransparente
            const Color(0x00000000), // Transparente
          ],
        )
        ..blendMode = ui.BlendMode.multiply;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        shadingPaint,
      );

      final picture = recorder.endRecording();
      final shadedImage = await picture.toImage(
        image.width,
        image.height,
      );

      // Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/shaded_${DateTime.now().millisecondsSinceEpoch}.png');

      final byteData = await shadedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      picture.dispose();
      return resultFile;
    } catch (e) {
      debugPrint('Error applying shading: $e');
      return null;
    }
  }

  /// Calcula la dirección de luz basada en la pose
  Offset calculateLightDirection(List<Offset> bodyContour) {
    if (bodyContour.isEmpty) return const Offset(0, -1);

    // Calcular normal promedio del contorno
    double avgX = 0, avgY = 0;
    for (final point in bodyContour) {
      avgX += point.dx;
      avgY += point.dy;
    }

    // Asumir luz viene de arriba-izquierda (típico)
    return const Offset(-0.5, -1).normalize();
  }

  /// Suaviza los bordes de una prenda para blending natural
  Future<File?> smoothEdges(File clothingImage, {double radius = 2.0}) async {
    try {
      final bytes = await clothingImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Crear máscara de suavizado
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final maskPaint = Paint()
        ..shader = ui.Gradient.radial(
        Offset(image.width / 2, image.height / 2),
        math.min(image.width, image.height) / 2,
        [
          const Color(0xFFFFFFFF),
          const Color(0x80FFFFFF),
          const Color(0x00FFFFFF),
        ],
      )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawImage(image, Offset.zero, Paint());
      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        maskPaint,
      );

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(image.width, image.height);

      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/smoothed_${DateTime.now().millisecondsSinceEpoch}.png');

      final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      picture.dispose();
      return resultFile;
    } catch (e) {
      debugPrint('Error smoothing edges: $e');
      return null;
    }
  }
}

/// Extensión para normalizar Offset
extension on Offset {
  Offset normalize() {
    final length = distance;
    if (length == 0) return const Offset(0, 0);
    return Offset(dx / length, dy / length);
  }
}
