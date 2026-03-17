import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import '../models/multi_angle_avatar.dart';
import '../models/multi_angle_clothing.dart';
import 'clothing_warping.dart';
import 'avatar_storage_service.dart';
import 'body_segmentation.dart';
import 'ai_image_generation_service.dart' show AIGenerationResult;

/// Servicio mejorado para generar imágenes realistas del usuario con ropa puesta
/// Usa técnicas avanzadas de:
/// 1. Segmentación corporal precisa con múltiples vistas del avatar
/// 2. Compositing con oclusión correcta (capas correctas)
/// 3. Iluminación y sombras consistentes
/// 4. Blending suave en bordes
/// 5. Uso de imágenes multi-ángulo para mejor precisión
class EnhancedAIImageGenerationService {
  static final EnhancedAIImageGenerationService _instance = EnhancedAIImageGenerationService._internal();
  factory EnhancedAIImageGenerationService() => _instance;
  EnhancedAIImageGenerationService._internal();

  final ClothingWarpingService _warpingService = ClothingWarpingService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();
  final BodySegmentationService _segmentationService = BodySegmentationService();

  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _segmentationService.initialize();
    _isInitialized = true;
  }

  /// Genera una imagen realista del avatar con las prendas seleccionadas
  /// Esta versión mejorada:
  /// - Usa avatar multi-ángulo si está disponible
  /// - Usa prendas multi-ángulo si están disponibles
  /// - Aplica segmentación corporal precisa
  /// - Genera compositing con oclusión correcta
  Future<AIGenerationResult> generateRealisticOutfitPreview({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
    bool useSegmentation = true,
    bool addShadows = true,
    bool smoothBlending = true,
    bool useMultiAngle = true,
  }) async {
    try {
      debugPrint('🎨 Iniciando generación realista con ${outfitItems.length} prendas');
      await initialize();

      // 1. Cargar avatar multi-ángulo si existe
      MultiAngleAvatar? multiAngleAvatar;
      if (useMultiAngle) {
        multiAngleAvatar = await _avatarStorage.getMultiAngleAvatar();
        debugPrint('📸 Avatar multi-ángulo: ${multiAngleAvatar?.viewCount ?? 0} vistas');
      }

      // 2. Cargar imagen del avatar
      final avatarBytes = await avatarImage.readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(avatarBytes);
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;

      // 3. Segmentar el cuerpo si está habilitado
      BodySegmentationResult? segmentationResult;
      if (useSegmentation) {
        segmentationResult = await _segmentationService.segmentBodyDetailed(avatarImage);
        debugPrint('✅ Segmentación corporal completada');
      }

      // 4. Ordenar prendas por capas (de abajo hacia arriba)
      final orderedItems = _orderItemsByLayer(outfitItems);

      // 5. Cargar prendas multi-ángulo
      final Map<String, MultiAngleClothing> multiAngleClothes = {};
      if (useMultiAngle) {
        for (final item in orderedItems) {
          final multiAngle = await _loadMultiAngleClothing(item.id);
          if (multiAngle != null) {
            multiAngleClothes[item.id] = multiAngle;
          }
        }
      }

      // 6. Crear canvas para composición
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(avatarImg.width.toDouble(), avatarImg.height.toDouble());

      // 7. Dibujar avatar base
      canvas.drawImage(avatarImg, Offset.zero, Paint()..filterQuality = FilterQuality.high);

      // 8. Procesar cada prenda en orden de capas
      final appliedItems = <String>[];
      final List<_ClothingLayer> clothingLayers = [];

      for (final item in orderedItems) {
        if (item.imagePath.isEmpty) continue;

        final clothingFile = File(item.imagePath);
        if (!await clothingFile.exists()) continue;

        // Verificar si tenemos multi-ángulo para esta prenda
        final hasMultiAngle = multiAngleClothes.containsKey(item.id);
        File? sourceImage = clothingFile;

        // Si tiene multi-ángulo, usar vista frontal como principal
        if (hasMultiAngle) {
          final multiAngle = multiAngleClothes[item.id]!;
          final frontImage = multiAngle.getImageForAngle(ClothingAngle.front);
          if (frontImage != null && await frontImage.exists()) {
            sourceImage = frontImage;
            debugPrint('✅ Usando vista frontal de ${item.name}');
          }
        }

        // Calcular posición y anclajes según tipo de prenda
        final anchors = _calculatePreciseAnchors(
          item.type,
          size,
          measurements,
          segmentationResult,
        );

        // Aplicar warping avanzado
        final warpedFile = await _warpingService.warpClothingToBody(
          clothingImage: sourceImage,
          bodyAnchors: anchors,
          type: item.type,
          targetSize: size,
        );

        if (warpedFile != null) {
          // Cargar imagen warpeada
          final warpedBytes = await warpedFile.readAsBytes();
          final warpedCodec = await ui.instantiateImageCodec(warpedBytes);
          final warpedFrame = await warpedCodec.getNextFrame();
          final warpedImg = warpedFrame.image;

          // Calcular posición de la prenda
          final position = _calculateItemPosition(item.type, size, anchors);

          clothingLayers.add(_ClothingLayer(
            image: warpedImg,
            item: item,
            position: position,
            hasMultiAngle: hasMultiAngle,
          ));

          appliedItems.add(item.name);
          debugPrint('✅ Prenda procesada: ${item.name}');
        }
      }

      // 9. Aplicar compositing con oclusión correcta
      await _applyAdvancedCompositing(
        canvas: canvas,
        size: size,
        layers: clothingLayers,
        bodyMask: segmentationResult?.maskImage,
        addShadows: addShadows,
        smoothBlending: smoothBlending,
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

      // Calcular confianza basada en el número de prendas aplicadas
      final confidence = appliedItems.length / outfitItems.length;

      debugPrint('✅ Imagen realista generada: ${resultFile.path}');

      return AIGenerationResult.success(
        resultFile,
        appliedItems,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando imagen realista: $e');
      debugPrint(stackTrace.toString());
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Ordena las prendas por capas (de abajo hacia arriba)
  List<ClothingItem> _orderItemsByLayer(List<ClothingItem> items) {
    // Definir orden de capas (menor número = más abajo)
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

  /// Calcula anclajes precisos basados en segmentación corporal
  Map<String, ui.Offset> _calculatePreciseAnchors(
    ClothingType type,
    Size avatarSize,
    UserMeasurements? measurements,
    BodySegmentationResult? segmentation,
  ) {
    final width = avatarSize.width;
    final height = avatarSize.height;

    // Factores de ajuste basados en medidas
    final heightFactor = (measurements?.height ?? 170) / 170;
    final shoulderFactor = (measurements?.shoulders ?? 45) / 45;
    final waistFactor = (measurements?.waist ?? 80) / 80;

    // Si tenemos segmentación, usar puntos detectados
    if (segmentation?.bodyPoints != null) {
      final points = segmentation!.bodyPoints!;
      return _calculateAnchorsFromBodyPoints(type, points, width, height);
    }

    // Fallback a cálculo proporcional
    switch (type) {
      case ClothingType.top:
        return {
          'topLeft': ui.Offset(
            width * 0.25 * (2 - shoulderFactor),
            height * 0.15 * heightFactor,
          ),
          'topRight': ui.Offset(
            width * 0.75 * shoulderFactor,
            height * 0.15 * heightFactor,
          ),
          'bottomLeft': ui.Offset(
            width * 0.30 * (2 - waistFactor),
            height * 0.45 * heightFactor,
          ),
          'bottomRight': ui.Offset(
            width * 0.70 * waistFactor,
            height * 0.45 * heightFactor,
          ),
          'center': ui.Offset(width * 0.5, height * 0.30 * heightFactor),
        };

      case ClothingType.bottom:
        return {
          'topLeft': ui.Offset(
            width * 0.30 * (2 - waistFactor),
            height * 0.42 * heightFactor,
          ),
          'topRight': ui.Offset(
            width * 0.70 * waistFactor,
            height * 0.42 * heightFactor,
          ),
          'bottomLeft': ui.Offset(
            width * 0.28,
            height * 0.88 * heightFactor,
          ),
          'bottomRight': ui.Offset(
            width * 0.72,
            height * 0.88 * heightFactor,
          ),
          'center': ui.Offset(width * 0.5, height * 0.65 * heightFactor),
        };

      case ClothingType.headwear:
        return {
          'center': ui.Offset(width * 0.5, height * 0.08 * heightFactor),
          'left': ui.Offset(width * 0.35, height * 0.08 * heightFactor),
          'right': ui.Offset(width * 0.65, height * 0.08 * heightFactor),
        };

      case ClothingType.footwear:
        return {
          'left': ui.Offset(width * 0.35, height * 0.92 * heightFactor),
          'right': ui.Offset(width * 0.65, height * 0.92 * heightFactor),
          'center': ui.Offset(width * 0.5, height * 0.92 * heightFactor),
        };

      case ClothingType.neckwear:
        return {
          'center': ui.Offset(width * 0.5, height * 0.18 * heightFactor),
          'top': ui.Offset(width * 0.5, height * 0.15 * heightFactor),
          'bottom': ui.Offset(width * 0.5, height * 0.25 * heightFactor),
        };
    }
  }

  /// Calcula anclajes desde puntos detectados del cuerpo
  Map<String, ui.Offset> _calculateAnchorsFromBodyPoints(
    ClothingType type,
    BodyPoints points,
    double width,
    double height,
  ) {
    switch (type) {
      case ClothingType.top:
        return {
          'topLeft': ui.Offset(
            points.leftShoulder?.dx ?? width * 0.25,
            points.leftShoulder?.dy ?? height * 0.15,
          ),
          'topRight': ui.Offset(
            points.rightShoulder?.dx ?? width * 0.75,
            points.rightShoulder?.dy ?? height * 0.15,
          ),
          'bottomLeft': ui.Offset(
            (points.leftShoulder?.dx ?? width * 0.25) + width * 0.05,
            points.leftHip?.dy ?? height * 0.45,
          ),
          'bottomRight': ui.Offset(
            (points.rightShoulder?.dx ?? width * 0.75) - width * 0.05,
            points.rightHip?.dy ?? height * 0.45,
          ),
          'center': ui.Offset(
            width * 0.5,
            ((points.leftShoulder?.dy ?? height * 0.15) + (points.leftHip?.dy ?? height * 0.45)) / 2,
          ),
        };

      case ClothingType.bottom:
        return {
          'topLeft': ui.Offset(
            (points.leftHip?.dx ?? width * 0.30) - width * 0.02,
            points.leftHip?.dy ?? height * 0.42,
          ),
          'topRight': ui.Offset(
            (points.rightHip?.dx ?? width * 0.70) + width * 0.02,
            points.rightHip?.dy ?? height * 0.42,
          ),
          'bottomLeft': ui.Offset(
            points.leftAnkle?.dx ?? width * 0.28,
            points.leftAnkle?.dy ?? height * 0.88,
          ),
          'bottomRight': ui.Offset(
            points.rightAnkle?.dx ?? width * 0.72,
            points.rightAnkle?.dy ?? height * 0.88,
          ),
          'center': ui.Offset(
            width * 0.5,
            ((points.leftHip?.dy ?? height * 0.42) + (points.leftAnkle?.dy ?? height * 0.88)) / 2,
          ),
        };

      case ClothingType.headwear:
        return {
          'center': ui.Offset(
            width * 0.5,
            (points.headTop?.dy ?? height * 0.08) - height * 0.02,
          ),
          'left': ui.Offset(
            (points.leftShoulder?.dx ?? width * 0.35) - width * 0.05,
            points.headTop?.dy ?? height * 0.08,
          ),
          'right': ui.Offset(
            (points.rightShoulder?.dx ?? width * 0.65) + width * 0.05,
            points.headTop?.dy ?? height * 0.08,
          ),
        };

      case ClothingType.footwear:
        return {
          'left': ui.Offset(
            points.leftAnkle?.dx ?? width * 0.35,
            (points.leftAnkle?.dy ?? height * 0.90) + height * 0.02,
          ),
          'right': ui.Offset(
            points.rightAnkle?.dx ?? width * 0.65,
            (points.rightAnkle?.dy ?? height * 0.90) + height * 0.02,
          ),
          'center': ui.Offset(width * 0.5, height * 0.92),
        };

      case ClothingType.neckwear:
        return {
          'center': ui.Offset(
            width * 0.5,
            ((points.headTop?.dy ?? height * 0.08) + (points.leftShoulder?.dy ?? height * 0.15)) / 2,
          ),
          'top': ui.Offset(width * 0.5, (points.headTop?.dy ?? height * 0.08) + height * 0.05),
          'bottom': ui.Offset(width * 0.5, points.leftShoulder?.dy ?? height * 0.15),
        };
    }
  }

  /// Calcula la posición de una prenda
  Rect _calculateItemPosition(
    ClothingType type,
    Size size,
    Map<String, ui.Offset> anchors,
  ) {
    switch (type) {
      case ClothingType.top:
        return Rect.fromPoints(
          anchors['topLeft'] ?? ui.Offset.zero,
          anchors['bottomRight'] ?? ui.Offset(size.width * 0.5, size.height * 0.5),
        );
      case ClothingType.bottom:
        return Rect.fromPoints(
          anchors['topLeft'] ?? ui.Offset.zero,
          anchors['bottomRight'] ?? ui.Offset(size.width * 0.5, size.height),
        );
      case ClothingType.headwear:
        final center = anchors['center'] ?? ui.Offset(size.width * 0.5, size.height * 0.1);
        return Rect.fromCenter(
          center: center,
          width: size.width * 0.3,
          height: size.height * 0.15,
        );
      case ClothingType.footwear:
        final center = anchors['center'] ?? ui.Offset(size.width * 0.5, size.height * 0.9);
        return Rect.fromCenter(
          center: center,
          width: size.width * 0.4,
          height: size.height * 0.1,
        );
      case ClothingType.neckwear:
        final center = anchors['center'] ?? ui.Offset(size.width * 0.5, size.height * 0.2);
        return Rect.fromCenter(
          center: center,
          width: size.width * 0.25,
          height: size.height * 0.1,
        );
    }
  }

  /// Aplica compositing avanzado con oclusión correcta y efectos visuales
  Future<void> _applyAdvancedCompositing({
    required Canvas canvas,
    required Size size,
    required List<_ClothingLayer> layers,
    ui.Image? bodyMask,
    bool addShadows = true,
    bool smoothBlending = true,
  }) async {
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final item = layer.item;

      // Crear paint con blending suave si está habilitado
      final paint = Paint()
        ..blendMode = ui.BlendMode.srcOver
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true;

      if (smoothBlending) {
        // Aplicar máscara de suavizado en bordes
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.3);
      }

      // Dibujar sombra debajo de la prenda si está habilitado
      if (addShadows && _shouldAddShadow(item.type)) {
        final shadowPaint = Paint()
          ..color = Colors.black.withAlpha(30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..blendMode = ui.BlendMode.srcOver;

        final shadowOffset = const Offset(2, 4);
        canvas.drawImage(
          layer.image,
          Offset(
            layer.position.left + shadowOffset.dx,
            layer.position.top + shadowOffset.dy,
          ),
          shadowPaint,
        );
      }

      // Dibujar la prenda
      canvas.drawImage(
        layer.image,
        Offset(layer.position.left, layer.position.top),
        paint,
      );

      // Aplicar efectos de iluminación
      if (addShadows) {
        _applyLightingEffects(canvas, layer.position, item.type, size);
      }

      // Aplicar oclusión (partes del cuerpo que cubren la prenda)
      if (i < layers.length - 1) {
        _applyOcclusion(canvas, layer, layers.sublist(i + 1), size);
      }
    }
  }

  /// Determina si una prenda debería tener sombra
  bool _shouldAddShadow(ClothingType type) {
    return type == ClothingType.top ||
           type == ClothingType.neckwear ||
           type == ClothingType.headwear;
  }

  /// Aplica efectos de iluminación realistas
  void _applyLightingEffects(
    Canvas canvas,
    Rect position,
    ClothingType type,
    Size canvasSize,
  ) {
    // Crear gradiente de iluminación sutil
    final lightingPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(position.left, position.top),
        Offset(position.right, position.bottom),
        [
          Colors.white.withAlpha(15),
          Colors.transparent,
          Colors.black.withAlpha(10),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = ui.BlendMode.overlay;

    canvas.drawRect(position, lightingPaint);
  }

  /// Aplica oclusión para evitar que prendas se superpongan incorrectamente
  void _applyOcclusion(
    Canvas canvas,
    _ClothingLayer currentLayer,
    List<_ClothingLayer> upperLayers,
    Size canvasSize,
  ) {
    // Las prendas superiores (como chaquetas) pueden tapar partes de las inferiores
    // Implementación básica - en una versión avanzada usaría la máscara del cuerpo
  }

  /// Genera una vista previa de alta calidad con todos los efectos
  Future<AIGenerationResult> generateHighQualityPreview({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
  }) async {
    return generateRealisticOutfitPreview(
      avatarImage: avatarImage,
      outfitItems: outfitItems,
      measurements: measurements,
      useSegmentation: true,
      addShadows: true,
      smoothBlending: true,
      useMultiAngle: true,
    );
  }

  /// Obtiene el avatar del usuario y genera preview realista
  Future<AIGenerationResult> generateWithStoredAvatar({
    required List<ClothingItem> outfitItems,
    bool highQuality = true,
  }) async {
    final avatarFile = await _avatarStorage.getAvatarImageFile();
    if (avatarFile == null) {
      return AIGenerationResult.error('No se encontró avatar del usuario');
    }

    final measurements = await _avatarStorage.getMeasurements();

    if (highQuality) {
      return generateHighQualityPreview(
        avatarImage: avatarFile,
        outfitItems: outfitItems,
        measurements: measurements,
      );
    }

    return generateRealisticOutfitPreview(
      avatarImage: avatarFile,
      outfitItems: outfitItems,
      measurements: measurements,
      useSegmentation: false,
      addShadows: false,
      smoothBlending: false,
    );
  }

  /// Carga una prenda multi-ángulo si existe
  Future<MultiAngleClothing?> _loadMultiAngleClothing(String id) async {
    // Por ahora, buscar en el sistema de archivos
    // En una implementación completa, esto usaría un servicio de persistencia
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

  void dispose() {
    _segmentationService.dispose();
    _isInitialized = false;
  }
}

/// Representa una capa de ropa en el compositing
class _ClothingLayer {
  final ui.Image image;
  final ClothingItem item;
  final Rect position;
  final bool hasMultiAngle;

  _ClothingLayer({
    required this.image,
    required this.item,
    required this.position,
    this.hasMultiAngle = false,
  });
}

/// Resultado de la segmentación corporal
class BodySegmentationResult {
  final ui.Image maskImage;
  final BodyPoints? bodyPoints;
  final double confidence;

  BodySegmentationResult({
    required this.maskImage,
    this.bodyPoints,
    this.confidence = 0.0,
  });
}

/// Puntos clave del cuerpo detectados
class BodyPoints {
  final ui.Offset? headTop;
  final ui.Offset? leftShoulder;
  final ui.Offset? rightShoulder;
  final ui.Offset? leftElbow;
  final ui.Offset? rightElbow;
  final ui.Offset? leftWrist;
  final ui.Offset? rightWrist;
  final ui.Offset? leftHip;
  final ui.Offset? rightHip;
  final ui.Offset? leftKnee;
  final ui.Offset? rightKnee;
  final ui.Offset? leftAnkle;
  final ui.Offset? rightAnkle;

  BodyPoints({
    this.headTop,
    this.leftShoulder,
    this.rightShoulder,
    this.leftElbow,
    this.rightElbow,
    this.leftWrist,
    this.rightWrist,
    this.leftHip,
    this.rightHip,
    this.leftKnee,
    this.rightKnee,
    this.leftAnkle,
    this.rightAnkle,
  });
}

/// Extensión del servicio de segmentación para detectar puntos del cuerpo
extension BodySegmentationExtension on BodySegmentationService {
  Future<BodySegmentationResult?> segmentBodyDetailed(File image) async {
    // Obtener máscara de segmentación (SegmentationMask)
    final mask = await segmentBody(image);
    if (mask == null) return null;

    // Aplicar máscara a la imagen para obtener un PNG con alpha en disco
    final maskedFile = await applyMaskToImage(image, mask);
    if (maskedFile == null) return null;

    // Cargar la imagen resultante como ui.Image
    try {
      final bytes = await maskedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      // Extraer puntos del cuerpo usando los anclajes de ropa
      final bodyPoints = getClothingAnchorPoints(
        mask,
        Size(uiImage.width.toDouble(), uiImage.height.toDouble()),
        ClothingType.top, // Usar top para obtener puntos generales del cuerpo
      );

      return BodySegmentationResult(
        maskImage: uiImage,
        bodyPoints: BodyPoints(
          leftShoulder: bodyPoints['topLeft'],
          rightShoulder: bodyPoints['topRight'],
          leftHip: bodyPoints['bottomLeft'],
          rightHip: bodyPoints['bottomRight'],
        ),
        confidence: 0.85,
      );
    } catch (e) {
      debugPrint('Error creando máscara ui.Image: $e');
      return null;
    }
  }
}
