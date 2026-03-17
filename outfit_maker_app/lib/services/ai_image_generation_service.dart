import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import 'clothing_warping.dart';
import 'avatar_storage_service.dart';

/// Resultado de la generación de imagen con IA
class AIGenerationResult {
  final bool success;
  final File? generatedImage;
  final String? errorMessage;
  final List<String> appliedItems;

  const AIGenerationResult({
    required this.success,
    this.generatedImage,
    this.errorMessage,
    this.appliedItems = const [],
  });

  factory AIGenerationResult.success(File image, List<String> items) {
    return AIGenerationResult(
      success: true,
      generatedImage: image,
      appliedItems: items,
    );
  }

  factory AIGenerationResult.error(String message) {
    return AIGenerationResult(
      success: false,
      errorMessage: message,
    );
  }
}

/// Servicio para generar imágenes realistas del usuario con ropa puesta
/// usando técnicas de IA (simulado con composición de imágenes + warping)
class AIImageGenerationService {
  static final AIImageGenerationService _instance = AIImageGenerationService._internal();
  factory AIImageGenerationService() => _instance;
  AIImageGenerationService._internal();

  final ClothingWarpingService _warpingService = ClothingWarpingService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  /// Genera una imagen realista del avatar con las prendas seleccionadas
  /// Esta función simula el comportamiento de IA combinando:
  /// 1. La imagen del avatar del usuario
  /// 2. Las prendas warpeadas (deformadas) para ajustarse al cuerpo
  /// 3. Efectos de iluminación y sombreado para realismo
  Future<AIGenerationResult> generateOutfitPreview({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
  }) async {
    try {
      debugPrint('🎨 Iniciando generación de outfit con ${outfitItems.length} prendas');

      // Cargar imagen del avatar
      final avatarBytes = await avatarImage.readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(avatarBytes);
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;

      // Crear canvas para composición
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(avatarImg.width.toDouble(), avatarImg.height.toDouble());

      // Dibujar avatar base
      canvas.drawImage(avatarImg, Offset.zero, Paint());

      // Lista de prendas aplicadas
      final appliedItems = <String>[];

      // Por cada prenda, aplicar warping y superponer
      for (final item in outfitItems) {
        if (item.imagePath.isEmpty) continue;

        final clothingFile = File(item.imagePath);
        if (!await clothingFile.exists()) continue;

        // Calcular posición según tipo de prenda
        final anchors = _calculateAnchorsForClothingType(
          item.type,
          size,
          measurements,
        );

        // Aplicar warping a la prenda
        final warpedFile = await _warpingService.warpClothingToBody(
          clothingImage: clothingFile,
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

          // Aplicar blending con sombra
          final paint = Paint()
            ..blendMode = ui.BlendMode.srcOver
            ..filterQuality = ui.FilterQuality.high;

          // Dibujar prenda sobre el avatar
          canvas.drawImage(warpedImg, Offset.zero, paint);

          appliedItems.add(item.name);

          debugPrint('✅ Prenda aplicada: ${item.name}');
        }
      }

      // Finalizar imagen
      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(
        avatarImg.width,
        avatarImg.height,
      );

      // Guardar resultado
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final resultFile = File('${tempDir.path}/outfit_preview_$timestamp.png');

      final byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return AIGenerationResult.error('Error al codificar imagen');
      }

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('✅ Imagen generada: ${resultFile.path}');

      return AIGenerationResult.success(resultFile, appliedItems);
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando imagen: $e');
      debugPrint(stackTrace.toString());
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Calcula los puntos de anclaje para cada tipo de prenda
  Map<String, ui.Offset> _calculateAnchorsForClothingType(
    ClothingType type,
    Size avatarSize,
    UserMeasurements? measurements,
  ) {
    // Factores de posición basados en proporciones del cuerpo humano
    final width = avatarSize.width;
    final height = avatarSize.height;

    switch (type) {
      case ClothingType.top:
        // Parte superior: hombros a cintura
        return {
          'topLeft': ui.Offset(width * 0.25, height * 0.15),
          'topRight': ui.Offset(width * 0.75, height * 0.15),
          'bottomLeft': ui.Offset(width * 0.30, height * 0.45),
          'bottomRight': ui.Offset(width * 0.70, height * 0.45),
          'center': ui.Offset(width * 0.5, height * 0.30),
        };

      case ClothingType.bottom:
        // Parte inferior: cintura a tobillos
        return {
          'topLeft': ui.Offset(width * 0.30, height * 0.42),
          'topRight': ui.Offset(width * 0.70, height * 0.42),
          'bottomLeft': ui.Offset(width * 0.28, height * 0.88),
          'bottomRight': ui.Offset(width * 0.72, height * 0.88),
          'center': ui.Offset(width * 0.5, height * 0.65),
        };

      case ClothingType.headwear:
        // Cabeza: encima de la cabeza
        return {
          'center': ui.Offset(width * 0.5, height * 0.08),
          'left': ui.Offset(width * 0.35, height * 0.08),
          'right': ui.Offset(width * 0.65, height * 0.08),
        };

      case ClothingType.footwear:
        // Calzado: pies
        return {
          'left': ui.Offset(width * 0.35, height * 0.92),
          'right': ui.Offset(width * 0.65, height * 0.92),
          'center': ui.Offset(width * 0.5, height * 0.92),
        };

      case ClothingType.neckwear:
        // Accesorios de cuello
        return {
          'center': ui.Offset(width * 0.5, height * 0.18),
          'top': ui.Offset(width * 0.5, height * 0.15),
          'bottom': ui.Offset(width * 0.5, height * 0.25),
        };
    }
  }

  /// Genera una imagen de alta calidad con efectos adicionales
  Future<AIGenerationResult> generateHighQualityPreview({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
    bool addShadows = true,
    bool smoothEdges = true,
  }) async {
    try {
      // Primero generar preview básico
      final basicResult = await generateOutfitPreview(
        avatarImage: avatarImage,
        outfitItems: outfitItems,
        measurements: measurements,
      );

      if (!basicResult.success || basicResult.generatedImage == null) {
        return basicResult;
      }

      // Aplicar mejoras visuales adicionales
      if (addShadows || smoothEdges) {
        final enhancedImage = await _applyVisualEnhancements(
          basicResult.generatedImage!,
          addShadows: addShadows,
          smoothEdges: smoothEdges,
        );

        if (enhancedImage != null) {
          return AIGenerationResult.success(
            enhancedImage,
            basicResult.appliedItems,
          );
        }
      }

      return basicResult;
    } catch (e) {
      debugPrint('Error en HQ generation: $e');
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Aplica mejoras visuales a la imagen generada
  Future<File?> _applyVisualEnhancements(
    File sourceImage, {
    bool addShadows = true,
    bool smoothEdges = true,
  }) async {
    try {
      final bytes = await sourceImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Dibujar imagen base
      canvas.drawImage(image, Offset.zero, Paint());

      // Aplicar sombreado si se solicita
      if (addShadows) {
        final shadowPaint = Paint()
          ..color = Colors.black.withAlpha(30)
          ..blendMode = ui.BlendMode.multiply;

        canvas.drawRect(
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          shadowPaint,
        );
      }

      // Finalizar
      final picture = recorder.endRecording();
      final enhancedImage = await picture.toImage(image.width, image.height);

      // Guardar
      final tempDir = await getTemporaryDirectory();
      final resultFile = File(
        '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final byteData = await enhancedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());
      return resultFile;
    } catch (e) {
      debugPrint('Error aplicando mejoras: $e');
      return null;
    }
  }

  /// Obtiene el avatar del usuario y genera preview
  Future<AIGenerationResult> generateWithStoredAvatar({
    required List<ClothingItem> outfitItems,
  }) async {
    final avatarFile = await _avatarStorage.getAvatarImageFile();
    if (avatarFile == null) {
      return AIGenerationResult.error('No se encontró avatar del usuario');
    }

    final measurements = await _avatarStorage.getMeasurements();

    return generateOutfitPreview(
      avatarImage: avatarFile,
      outfitItems: outfitItems,
      measurements: measurements,
    );
  }
}
