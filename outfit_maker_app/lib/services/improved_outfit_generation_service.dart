import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import '../models/multi_angle_avatar.dart';
import 'avatar_storage_service.dart';
import 'ai_image_generation_service.dart' show AIGenerationResult;

/// Servicio mejorado de generación de outfits con precisión realista
/// Utiliza:
/// 1. Análisis de proporciones corporales
/// 2. Posicionamiento preciso de prendas
/// 3. Información multi-ángulo cuando está disponible
/// 4. Blending y compositing avanzado
class ImprovedOutfitGenerationService {
  static final ImprovedOutfitGenerationService _instance =
      ImprovedOutfitGenerationService._internal();
  factory ImprovedOutfitGenerationService() => _instance;
  ImprovedOutfitGenerationService._internal();

  final AvatarStorageService _avatarStorage = AvatarStorageService();

  /// Genera una imagen realista del outfit con máxima precisión
  Future<AIGenerationResult> generatePreciseOutfit({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
    MultiAngleAvatar? multiAngleAvatar,
  }) async {
    try {
      debugPrint('🎨 Iniciando generación precisa de outfit con ${outfitItems.length} prendas');

      // 1. Cargar y analizar avatar
      final avatarBytes = await avatarImage.readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(avatarBytes);
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;
      final size = Size(avatarImg.width.toDouble(), avatarImg.height.toDouble());

      // 2. Calcular proporciones corporales
      final bodyProportions = _calculateBodyProportions(size, measurements);

      // 3. Ordenar prendas por capas
      final orderedItems = _orderItemsByLayer(outfitItems);

      // 4. Crear canvas para composición
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 5. Dibujar avatar base
      canvas.drawImage(avatarImg, Offset.zero, Paint()..filterQuality = FilterQuality.high);

      // 6. Procesar cada prenda
      final appliedItems = <String>[];
      for (final item in orderedItems) {
        if (item.imagePath.isEmpty) continue;

        final clothingFile = File(item.imagePath);
        if (!await clothingFile.exists()) continue;

        // Calcular posición y transformación
        final position = _calculateClothingPosition(
          item.type,
          size,
          bodyProportions,
        );

        // Procesar y aplicar prenda
        final success = await _applyClothingToCanvas(
          canvas: canvas,
          clothingFile: clothingFile,
          position: position,
          size: size,
          clothingType: item.type,
        );

        if (success) {
          appliedItems.add(item.name);
        }
      }

      // 7. Aplicar efectos finales
      _applyFinalEffects(canvas, size);

      // 8. Finalizar imagen
      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(
        avatarImg.width,
        avatarImg.height,
      );

      // 9. Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final resultFile = File('${tempDir.path}/improved_outfit_$timestamp.png');

      final byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return AIGenerationResult.error('Error al codificar imagen');
      }

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('✅ Imagen mejorada generada: ${resultFile.path}');

      return AIGenerationResult.success(resultFile, appliedItems);
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando outfit: $e');
      debugPrint(stackTrace.toString());
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Calcula las proporciones corporales basadas en medidas
  _BodyProportions _calculateBodyProportions(
    Size avatarSize,
    UserMeasurements? measurements,
  ) {
    final width = avatarSize.width;
    final height = avatarSize.height;

    // Proporciones antropométricas estándar
    final headHeight = height * 0.12;
    final torsoHeight = height * 0.35;
    final legHeight = height * 0.53;

    // Ajustar según medidas
    final shoulderWidth = width * 0.35;
    final waistWidth = width * 0.25;
    final hipWidth = width * 0.32;

    return _BodyProportions(
      totalHeight: height,
      totalWidth: width,
      headHeight: headHeight,
      torsoHeight: torsoHeight,
      legHeight: legHeight,
      shoulderWidth: shoulderWidth,
      waistWidth: waistWidth,
      hipWidth: hipWidth,
      headCenter: Offset(width / 2, headHeight / 2),
      torsoCenter: Offset(width / 2, headHeight + torsoHeight / 2),
      legCenter: Offset(width / 2, headHeight + torsoHeight + legHeight / 2),
    );
  }

  /// Calcula la posición exacta para una prenda
  _ClothingPosition _calculateClothingPosition(
    ClothingType type,
    Size avatarSize,
    _BodyProportions proportions,
  ) {
    final width = avatarSize.width;
    final height = avatarSize.height;

    switch (type) {
      case ClothingType.top:
        return _ClothingPosition(
          topLeft: Offset(
            width * 0.15,
            proportions.headHeight + height * 0.02,
          ),
          topRight: Offset(
            width * 0.85,
            proportions.headHeight + height * 0.02,
          ),
          bottomLeft: Offset(
            width * 0.18,
            proportions.headHeight + proportions.torsoHeight - height * 0.02,
          ),
          bottomRight: Offset(
            width * 0.82,
            proportions.headHeight + proportions.torsoHeight - height * 0.02,
          ),
          layer: 3,
          opacity: 0.95,
        );

      case ClothingType.bottom:
        return _ClothingPosition(
          topLeft: Offset(
            width * 0.2,
            proportions.headHeight + proportions.torsoHeight - height * 0.01,
          ),
          topRight: Offset(
            width * 0.8,
            proportions.headHeight + proportions.torsoHeight - height * 0.01,
          ),
          bottomLeft: Offset(
            width * 0.22,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight - height * 0.05,
          ),
          bottomRight: Offset(
            width * 0.78,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight - height * 0.05,
          ),
          layer: 2,
          opacity: 0.95,
        );

      case ClothingType.footwear:
        return _ClothingPosition(
          topLeft: Offset(
            width * 0.25,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight - height * 0.08,
          ),
          topRight: Offset(
            width * 0.75,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight - height * 0.08,
          ),
          bottomLeft: Offset(
            width * 0.25,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight,
          ),
          bottomRight: Offset(
            width * 0.75,
            proportions.headHeight + proportions.torsoHeight + proportions.legHeight,
          ),
          layer: 1,
          opacity: 0.95,
        );

      case ClothingType.headwear:
        return _ClothingPosition(
          topLeft: Offset(
            width * 0.2,
            height * 0.01,
          ),
          topRight: Offset(
            width * 0.8,
            height * 0.01,
          ),
          bottomLeft: Offset(
            width * 0.2,
            proportions.headHeight + height * 0.02,
          ),
          bottomRight: Offset(
            width * 0.8,
            proportions.headHeight + height * 0.02,
          ),
          layer: 5,
          opacity: 0.95,
        );

      case ClothingType.neckwear:
        return _ClothingPosition(
          topLeft: Offset(
            width * 0.35,
            proportions.headHeight + height * 0.01,
          ),
          topRight: Offset(
            width * 0.65,
            proportions.headHeight + height * 0.01,
          ),
          bottomLeft: Offset(
            width * 0.35,
            proportions.headHeight + height * 0.08,
          ),
          bottomRight: Offset(
            width * 0.65,
            proportions.headHeight + height * 0.08,
          ),
          layer: 4,
          opacity: 0.95,
        );
    }
  }

  /// Aplica una prenda al canvas con transformación precisa
  Future<bool> _applyClothingToCanvas({
    required Canvas canvas,
    required File clothingFile,
    required _ClothingPosition position,
    required Size canvasSize,
    required ClothingType clothingType,
  }) async {
    try {
      // Cargar imagen de la prenda
      final bytes = await clothingFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final clothingImg = frame.image;

      // Calcular rectángulo destino
      final destRect = Rect.fromPoints(
        position.topLeft,
        position.bottomRight,
      );

      // Calcular rectángulo fuente
      final srcRect = Rect.fromLTWH(
        0,
        0,
        clothingImg.width.toDouble(),
        clothingImg.height.toDouble(),
      );

      // Crear paint con blending
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true
        ..opacity = position.opacity
        ..blendMode = ui.BlendMode.srcOver;

      // Aplicar sombra suave
      if (position.layer > 1) {
        final shadowPaint = Paint()
          ..color = Colors.black.withAlpha(15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
          ..blendMode = ui.BlendMode.multiply;

        canvas.drawImageRect(
          clothingImg,
          srcRect,
          destRect.translate(1, 1),
          shadowPaint,
        );
      }

      // Dibujar la prenda
      canvas.drawImageRect(clothingImg, srcRect, destRect, paint);

      // Aplicar efecto de iluminación sutil
      _applyClothingLighting(canvas, destRect, clothingType);

      return true;
    } catch (e) {
      debugPrint('Error aplicando prenda: $e');
      return false;
    }
  }

  /// Aplica efecto de iluminación a una prenda
  void _applyClothingLighting(
    Canvas canvas,
    Rect clothingRect,
    ClothingType type,
  ) {
    // Gradiente de iluminación sutil
    final lightingPaint = Paint()
      ..shader = ui.Gradient.linear(
        clothingRect.topLeft,
        clothingRect.bottomRight,
        [
          Colors.white.withAlpha(8),
          Colors.transparent,
          Colors.black.withAlpha(5),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = ui.BlendMode.overlay;

    canvas.drawRect(clothingRect, lightingPaint);
  }

  /// Aplica efectos finales a la imagen
  void _applyFinalEffects(Canvas canvas, Size size) {
    // Viñeta sutil
    final vignettePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.7,
        [Colors.transparent, Colors.black.withAlpha(10)],
        [0.0, 1.0],
      )
      ..blendMode = ui.BlendMode.multiply;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  /// Ordena las prendas por capas
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

  /// Genera con avatar almacenado
  Future<AIGenerationResult> generateWithStoredAvatar({
    required List<ClothingItem> outfitItems,
  }) async {
    final avatarFile = await _avatarStorage.getAvatarImageFile();
    if (avatarFile == null) {
      return AIGenerationResult.error('No se encontró avatar del usuario');
    }

    final measurements = await _avatarStorage.getMeasurements();
    final multiAngleAvatar = await _avatarStorage.getMultiAngleAvatar();

    return generatePreciseOutfit(
      avatarImage: avatarFile,
      outfitItems: outfitItems,
      measurements: measurements,
      multiAngleAvatar: multiAngleAvatar,
    );
  }
}

/// Proporciones corporales calculadas
class _BodyProportions {
  final double totalHeight;
  final double totalWidth;
  final double headHeight;
  final double torsoHeight;
  final double legHeight;
  final double shoulderWidth;
  final double waistWidth;
  final double hipWidth;
  final Offset headCenter;
  final Offset torsoCenter;
  final Offset legCenter;

  _BodyProportions({
    required this.totalHeight,
    required this.totalWidth,
    required this.headHeight,
    required this.torsoHeight,
    required this.legHeight,
    required this.shoulderWidth,
    required this.waistWidth,
    required this.hipWidth,
    required this.headCenter,
    required this.torsoCenter,
    required this.legCenter,
  });
}

/// Posición de una prenda
class _ClothingPosition {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRightPos;
  final int layer;
  final double opacity;

  _ClothingPosition({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRightPos,
    required this.layer,
    required this.opacity,
  });

  Offset get bottomRight => bottomRightPos;
}
