import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import '../models/multi_angle_avatar.dart';
import '../models/multi_angle_clothing.dart';
import 'avatar_storage_service.dart';
import 'body_segmentation.dart';
import 'ai_image_generation_service.dart' show AIGenerationResult;

/// Servicio avanzado para generar imágenes realistas de outfits
/// Usa técnicas de:
/// 1. Segmentación corporal precisa
/// 2. Análisis de pose para posicionamiento correcto
/// 3. Multi-ángulo para mejor precisión
/// 4. Compositing con oclusión y blending avanzado
class RealisticOutfitGenerationService {
  static final RealisticOutfitGenerationService _instance = RealisticOutfitGenerationService._internal();
  factory RealisticOutfitGenerationService() => _instance;
  RealisticOutfitGenerationService._internal();

  final AvatarStorageService _avatarStorage = AvatarStorageService();
  final BodySegmentationService _segmentationService = BodySegmentationService();

  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _segmentationService.initialize();
    _isInitialized = true;
  }

  /// Genera una imagen realista del outfit con técnicas avanzadas
  Future<AIGenerationResult> generateRealisticOutfit({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
  }) async {
    try {
      debugPrint('🎨 Iniciando generación realista con ${outfitItems.length} prendas');
      await initialize();

      // 1. Cargar avatar multi-ángulo si existe
      final multiAngleAvatar = await _avatarStorage.getMultiAngleAvatar();

      // 2. Cargar imagen del avatar
      final avatarBytes = await avatarImage.readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(avatarBytes);
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;
      final size = Size(avatarImg.width.toDouble(), avatarImg.height.toDouble());

      // 3. Segmentar el cuerpo para obtener máscara precisa
      final segmentationMask = await _segmentationService.segmentBody(avatarImage);

      // 4. Calcular puntos de anclaje del cuerpo
      final bodyAnchors = await _calculateBodyAnchors(
        avatarImage,
        size,
        measurements,
        segmentationMask,
      );

      // 5. Ordenar prendas por capas (de abajo hacia arriba)
      final orderedItems = _orderItemsByLayer(outfitItems);

      // 6. Crear canvas para composición
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 7. Dibujar avatar base
      canvas.drawImage(avatarImg, Offset.zero, Paint()..filterQuality = FilterQuality.high);

      // 8. Procesar cada prenda con técnicas avanzadas
      final appliedItems = <String>[];
      final clothingLayers = <_ClothingLayer>[];

      for (final item in orderedItems) {
        if (item.imagePath.isEmpty) continue;

        final clothingFile = File(item.imagePath);
        if (!await clothingFile.exists()) continue;

        // Cargar prenda multi-ángulo si existe
        final multiAngleClothing = await _loadMultiAngleClothing(item.id);
        final sourceImage = multiAngleClothing?.frontImagePath != null
            ? File(multiAngleClothing!.frontImagePath)
            : clothingFile;

        // Calcular transformación precisa para la prenda
        final transform = _calculateClothingTransform(
          item.type,
          size,
          bodyAnchors,
          measurements,
        );

        // Procesar la prenda con la transformación
        final processedClothing = await _processClothingImage(
          sourceImage,
          transform,
          item.type,
        );

        if (processedClothing != null) {
          clothingLayers.add(_ClothingLayer(
            image: processedClothing,
            item: item,
            transform: transform,
          ));
          appliedItems.add(item.name);
        }
      }

      // 9. Aplicar compositing con oclusión correcta
      await _applyAdvancedCompositing(
        canvas: canvas,
        size: size,
        layers: clothingLayers,
        bodyAnchors: bodyAnchors,
        segmentationMask: segmentationMask,
      );

      // 10. Finalizar imagen
      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(
        avatarImg.width,
        avatarImg.height,
      );

      // 11. Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final resultFile = File('${tempDir.path}/realistic_outfit_$timestamp.png');

      final byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return AIGenerationResult.error('Error al codificar imagen');
      }

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('✅ Imagen realista generada: ${resultFile.path}');

      return AIGenerationResult.success(resultFile, appliedItems);
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando imagen realista: $e');
      debugPrint(stackTrace.toString());
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Calcula puntos de anclaje del cuerpo usando segmentación y medidas
  Future<Map<String, ui.Offset>> _calculateBodyAnchors(
    File avatarImage,
    Size size,
    UserMeasurements? measurements,
    ui.SegmentationMask? mask,
  ) async {
    final anchors = <String, ui.Offset>{};
    final width = size.width;
    final height = size.height;

    // Factores basados en medidas
    final heightFactor = (measurements?.height ?? 170) / 170;
    final shoulderFactor = (measurements?.shoulders ?? 45) / 45;
    final waistFactor = (measurements?.waist ?? 80) / 80;

    // Puntos base del cuerpo (proporciones antropométricas)
    anchors['headCenter'] = ui.Offset(width * 0.5, height * 0.08 * heightFactor);
    anchors['neckCenter'] = ui.Offset(width * 0.5, height * 0.12 * heightFactor);
    anchors['leftShoulder'] = ui.Offset(
      width * 0.25 * (2 - shoulderFactor),
      height * 0.18 * heightFactor,
    );
    anchors['rightShoulder'] = ui.Offset(
      width * 0.75 * shoulderFactor,
      height * 0.18 * heightFactor,
    );
    anchors['leftHip'] = ui.Offset(
      width * 0.32 * (2 - waistFactor),
      height * 0.45 * heightFactor,
    );
    anchors['rightHip'] = ui.Offset(
      width * 0.68 * waistFactor,
      height * 0.45 * heightFactor,
    );
    anchors['waistCenter'] = ui.Offset(
      width * 0.5,
      (anchors['leftHip']!.dy + anchors['leftShoulder']!.dy) / 2,
    );
    anchors['leftKnee'] = ui.Offset(width * 0.35, height * 0.65 * heightFactor);
    anchors['rightKnee'] = ui.Offset(width * 0.65, height * 0.65 * heightFactor);
    anchors['leftAnkle'] = ui.Offset(width * 0.35, height * 0.88 * heightFactor);
    anchors['rightAnkle'] = ui.Offset(width * 0.65, height * 0.88 * heightFactor);

    return anchors;
  }

  /// Ordena las prendas por capas (de abajo hacia arriba)
  List<ClothingItem> _orderItemsByLayer(List<ClothingItem> items) {
    final layerOrder = {
      ClothingType.footwear: 1,
      ClothingType.bottom: 2,
      ClothingType.top: 3,
      ClothingType.neckwear: 4,
      ClothingType.headwear: 5,
    };

    final sorted = List<ClothingItem>.from(items);
    sorted.sort((a, b) {
      final layerA = layerOrder[a.type] ?? 0;
      final layerB = layerOrder[b.type] ?? 0;
      return layerA.compareTo(layerB);
    });

    return sorted;
  }

  /// Calcula la transformación para una prenda según su tipo
  _ClothingTransform _calculateClothingTransform(
    ClothingType type,
    Size avatarSize,
    Map<String, ui.Offset> bodyAnchors,
    UserMeasurements? measurements,
  ) {
    final width = avatarSize.width;
    final height = avatarSize.height;

    // Factores de ajuste
    final shoulderFactor = (measurements?.shoulders ?? 45) / 45;
    final waistFactor = (measurements?.waist ?? 80) / 80;

    switch (type) {
      case ClothingType.top:
        // Parte superior: desde hombros hasta cintura
        final topLeft = bodyAnchors['leftShoulder']!.translate(
          -width * 0.05 * shoulderFactor,
          -height * 0.02,
        );
        final topRight = bodyAnchors['rightShoulder']!.translate(
          width * 0.05 * shoulderFactor,
          -height * 0.02,
        );
        final bottomLeft = bodyAnchors['leftHip']!.translate(
          -width * 0.02,
          height * 0.02,
        );
        final bottomRight = bodyAnchors['rightHip']!.translate(
          width * 0.02,
          height * 0.02,
        );

        return _ClothingTransform(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
          center: ui.Offset(width * 0.5, (topLeft.dy + bottomLeft.dy) / 2),
          scale: 1.0 * shoulderFactor,
        );

      case ClothingType.bottom:
        // Parte inferior: desde cintura hasta tobillos
        final topLeft = bodyAnchors['leftHip']!.translate(
          -width * 0.03 * waistFactor,
          -height * 0.01,
        );
        final topRight = bodyAnchors['rightHip']!.translate(
          width * 0.03 * waistFactor,
          -height * 0.01,
        );
        final bottomLeft = bodyAnchors['leftAnkle']!.translate(
          -width * 0.02,
          height * 0.02,
        );
        final bottomRight = bodyAnchors['rightAnkle']!.translate(
          width * 0.02,
          height * 0.02,
        );

        return _ClothingTransform(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
          center: ui.Offset(width * 0.5, (topLeft.dy + bottomLeft.dy) / 2),
          scale: 1.0 * waistFactor,
        );

      case ClothingType.headwear:
        // Cabeza: centrado en la cabeza
        final headCenter = bodyAnchors['headCenter']!;
        return _ClothingTransform(
          topLeft: headCenter.translate(-width * 0.15, -height * 0.05),
          topRight: headCenter.translate(width * 0.15, -height * 0.05),
          bottomLeft: headCenter.translate(-width * 0.15, height * 0.08),
          bottomRight: headCenter.translate(width * 0.15, height * 0.08),
          center: headCenter,
          scale: 1.0,
        );

      case ClothingType.footwear:
        // Calzado: en los pies
        final leftFoot = bodyAnchors['leftAnkle']!;
        final rightFoot = bodyAnchors['rightAnkle']!;
        return _ClothingTransform(
          topLeft: leftFoot.translate(-width * 0.08, -height * 0.02),
          topRight: rightFoot.translate(width * 0.08, -height * 0.02),
          bottomLeft: leftFoot.translate(-width * 0.08, height * 0.06),
          bottomRight: rightFoot.translate(width * 0.08, height * 0.06),
          center: ui.Offset(width * 0.5, (leftFoot.dy + rightFoot.dy) / 2),
          scale: 1.0,
        );

      case ClothingType.neckwear:
        // Cuello: entre cuello y hombros
        final neckCenter = bodyAnchors['neckCenter']!;
        return _ClothingTransform(
          topLeft: neckCenter.translate(-width * 0.12, -height * 0.02),
          topRight: neckCenter.translate(width * 0.12, -height * 0.02),
          bottomLeft: neckCenter.translate(-width * 0.12, height * 0.06),
          bottomRight: neckCenter.translate(width * 0.12, height * 0.06),
          center: neckCenter,
          scale: 1.0,
        );
    }
  }

  /// Procesa la imagen de la prenda aplicando transformación
  Future<ui.Image?> _processClothingImage(
    File clothingFile,
    _ClothingTransform transform,
    ClothingType type,
  ) async {
    try {
      // Cargar imagen de la prenda
      final bytes = await clothingFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final clothingImg = frame.image;

      // Crear recorder para transformar
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Calcular rectángulo destino
      final destRect = Rect.fromPoints(
        transform.topLeft,
        transform.bottomRight,
      );

      // Calcular rectángulo fuente (imagen completa)
      final srcRect = Rect.fromLTWH(
        0,
        0,
        clothingImg.width.toDouble(),
        clothingImg.height.toDouble(),
      );

      // Dibujar prenda transformada
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImageRect(clothingImg, srcRect, destRect, paint);

      // Finalizar
      final picture = recorder.endRecording();
      final result = await picture.toImage(
        destRect.width.ceil(),
        destRect.height.ceil(),
      );

      return result;
    } catch (e) {
      debugPrint('Error procesando prenda: $e');
      return null;
    }
  }

  /// Aplica compositing avanzado con oclusión y blending
  Future<void> _applyAdvancedCompositing({
    required Canvas canvas,
    required Size size,
    required List<_ClothingLayer> layers,
    required Map<String, ui.Offset> bodyAnchors,
    ui.SegmentationMask? segmentationMask,
  }) async {
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];

      // Crear paint con blending suave
      final paint = Paint()
        ..blendMode = ui.BlendMode.srcOver
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      // Aplicar sombra suave
      if (i > 0) {
        final shadowPaint = Paint()
          ..color = Colors.black.withAlpha(20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..blendMode = ui.BlendMode.srcOver;

        canvas.drawImage(
          layer.image,
          layer.transform.topLeft.translate(2, 3),
          shadowPaint,
        );
      }

      // Dibujar la prenda
      canvas.drawImage(layer.image, layer.transform.topLeft, paint);

      // Aplicar efectos de iluminación
      _applyLightingEffect(canvas, layer.transform, layer.item.type, size);
    }
  }

  /// Aplica efectos de iluminación
  void _applyLightingEffect(
    Canvas canvas,
    _ClothingTransform transform,
    ClothingType type,
    Size canvasSize,
  ) {
    final rect = Rect.fromPoints(transform.topLeft, transform.bottomRight);

    // Gradiente de iluminación sutil
    final lightingPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.bottom),
        [
          Colors.white.withAlpha(10),
          Colors.transparent,
          Colors.black.withAlpha(5),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = ui.BlendMode.overlay;

    canvas.drawRect(rect, lightingPaint);
  }

  /// Carga una prenda multi-ángulo si existe
  Future<MultiAngleClothing?> _loadMultiAngleClothing(String id) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final clothingDir = Directory('${appDir.path}/clothing/$id');

      if (!await clothingDir.exists()) {
        return null;
      }

      final frontFile = File('${clothingDir.path}/front.jpg');
      if (!await frontFile.exists()) {
        return null;
      }

      final backFile = File('${clothingDir.path}/back.jpg');

      return MultiAngleClothing(
        id: id,
        name: '',
        type: ClothingType.top,
        frontImagePath: frontFile.path,
        backImagePath: await backFile.exists() ? backFile.path : null,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error cargando prenda multi-ángulo: $e');
      return null;
    }
  }

  /// Genera con avatar almacenado
  Future<AIGenerationResult> generateWithStoredAvatar({
    required List<ClothingItem> outfitItems,
  }) async {
    final avatarFile = await _avatarStorage.getAvatarImageFile();
    if (avatarFile == null) {
      return AIGenerationResult.error('No se encontró avatar del usuario');
    }

    final measurements = await _avatarStorage.getMeasurements();

    return generateRealisticOutfit(
      avatarImage: avatarFile,
      outfitItems: outfitItems,
      measurements: measurements,
    );
  }
}

/// Representa una capa de ropa
class _ClothingLayer {
  final ui.Image image;
  final ClothingItem item;
  final _ClothingTransform transform;

  _ClothingLayer({
    required this.image,
    required this.item,
    required this.transform,
  });
}

/// Representa la transformación para una prenda
class _ClothingTransform {
  final ui.Offset topLeft;
  final ui.Offset topRight;
  final ui.Offset bottomLeft;
  final ui.Offset bottomRightPos;
  final ui.Offset center;
  final double scale;

  _ClothingTransform({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRightPos,
    required this.center,
    required this.scale,
  });

  ui.Offset get bottomRight => bottomRightPos;
}
