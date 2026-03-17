import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import 'avatar_storage_service.dart';
import 'body_segmentation.dart';
import 'bg_removal_service.dart';
import 'ai_image_generation_service.dart' show AIGenerationResult;

/// Servicio avanzado de generación de outfits usando IA externa
/// Soporta múltiples proveedores: Replicate, Stability AI, OpenAI
class AdvancedAIGenerationService {
  static final AdvancedAIGenerationService _instance = AdvancedAIGenerationService._internal();
  factory AdvancedAIGenerationService() => _instance;
  AdvancedAIGenerationService._internal();

  final AvatarStorageService _avatarStorage = AvatarStorageService();
  final BodySegmentationService _segmentationService = BodySegmentationService();
  final BgRemovalService _bgRemovalService = BgRemovalService();

  // Configuración de proveedores
  String _activeProvider = 'local'; // 'local', 'replicate', 'stability', 'openai'
  String? _apiKey;

  /// Inicializa el servicio con el proveedor deseado
  Future<void> initialize({String provider = 'local', String? apiKey}) async {
    _activeProvider = provider;
    _apiKey = apiKey;
  }

  /// Genera una imagen realista usando el proveedor activo
  Future<AIGenerationResult> generateRealisticOutfit({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
    String? style,
    String? background,
  }) async {
    try {
      debugPrint('🎨 Generando outfit con $_activeProvider provider');

      switch (_activeProvider) {
        case 'replicate':
          return await _generateWithReplicate(
            avatarImage: avatarImage,
            outfitItems: outfitItems,
            style: style,
            background: background,
          );
        case 'stability':
          return await _generateWithStability(
            avatarImage: avatarImage,
            outfitItems: outfitItems,
            style: style,
            background: background,
          );
        case 'openai':
          return await _generateWithOpenAI(
            avatarImage: avatarImage,
            outfitItems: outfitItems,
            style: style,
            background: background,
          );
        default:
          return await _generateLocalAdvanced(
            avatarImage: avatarImage,
            outfitItems: outfitItems,
            measurements: measurements,
          );
      }
    } catch (e) {
      debugPrint('❌ Error en generación avanzada: $e');
      // Fallback a generación local
      return await _generateLocalAdvanced(
        avatarImage: avatarImage,
        outfitItems: outfitItems,
        measurements: measurements,
      );
    }
  }

  /// Generación local avanzada con técnicas mejoradas
  Future<AIGenerationResult> _generateLocalAdvanced({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    UserMeasurements? measurements,
  }) async {
    try {
      // Cargar imagen del avatar
      final avatarBytes = await avatarImage.readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(avatarBytes);
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;

      // Crear canvas de alta resolución
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(avatarImg.width.toDouble(), avatarImg.height.toDouble());

      // 1. Dibujar fondo limpio
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // 2. Dibujar avatar base con suavizado
      final avatarPaint = Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true;
      canvas.drawImage(avatarImg, Offset.zero, avatarPaint);

      // 3. Ordenar prendas por capas (de abajo hacia arriba)
      final orderedItems = _orderItemsByLayer(outfitItems);

      // Intentar segmentar el cuerpo del avatar para colocar y enmascarar mejor las prendas
      final segmentationMask = await _segmentationService.segmentBody(avatarImage);

      // 4. Procesar cada prenda con técnicas mejoradas
      final appliedItems = <String>[];

      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < orderedItems.length; i++) {
        final item = orderedItems[i];
        if (item.imagePath.isEmpty) continue;

        File clothingFile = File(item.imagePath);
        if (!await clothingFile.exists()) continue;

        // Intentar eliminar fondo de la prenda para obtener un recorte (si el servicio responde)
        try {
          final outPath = '${tempDir.path}/${item.id}_cutout_${DateTime.now().millisecondsSinceEpoch}.png';
          final cutout = await _bgRemovalService.removeBackground(clothingFile, outPath);
          if (cutout != null) {
            clothingFile = cutout;
          }
        } catch (e) {
          debugPrint('Warning: bg removal failed for ${item.name}: $e');
        }

        // Cargar imagen de la prenda (posible recorte con transparencia)
        final clothingBytes = await clothingFile.readAsBytes();
        final clothingCodec = await ui.instantiateImageCodec(clothingBytes);
        final clothingFrame = await clothingCodec.getNextFrame();
        final clothingImg = clothingFrame.image;

        // Obtener puntos ancla a partir de la segmentación (si está disponible)
        Offset anchorCenter = Offset(size.width / 2, size.height / 2);
        if (segmentationMask != null) {
          try {
            final anchors = _segmentationService.getClothingAnchorPoints(segmentationMask, size, item.type);
            if (anchors.containsKey('center')) anchorCenter = anchors['center']!;
          } catch (e) {
            debugPrint('Warning: error computing anchors for ${item.name}: $e');
          }
        }

        // Calcular escala aproximada según tipo y medidas (mejor que transform estático)
        double desiredWidthFactor;
        switch (item.type) {
          case ClothingType.top:
            desiredWidthFactor = 0.55;
            break;
          case ClothingType.bottom:
            desiredWidthFactor = 0.5;
            break;
          case ClothingType.headwear:
            desiredWidthFactor = 0.25;
            break;
          case ClothingType.footwear:
            desiredWidthFactor = 0.35;
            break;
          case ClothingType.neckwear:
            desiredWidthFactor = 0.18;
            break;
        }

        final targetWidth = size.width * desiredWidthFactor;
        final scale = (targetWidth / clothingImg.width).clamp(0.1, 4.0);

        // Calcular posición final centrando la prenda en el ancla
        final translateX = anchorCenter.dx - (clothingImg.width * scale) / 2;
        final translateY = anchorCenter.dy - (clothingImg.height * scale) / 2;

        // Preparar transformación
        final matrix = Matrix4.identity();
        matrix.translate(translateX, translateY);
        matrix.scale(scale, scale, 1.0);

        // Aplicar transformación y dibujar (usar saveLayer para permitir operaciones con alpha)
        canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
        canvas.transform(matrix.storage);

        // Sombra suave
        if (i > 0) {
          final shadowPaint = Paint()
            ..color = Colors.black.withAlpha(18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
            ..blendMode = ui.BlendMode.multiply;
          canvas.drawImage(clothingImg, const Offset(2, 3), shadowPaint);
        }

        // Dibujar la prenda
        final paint = Paint()
          ..filterQuality = ui.FilterQuality.high
          ..isAntiAlias = true
          ..blendMode = ui.BlendMode.srcOver;

        canvas.drawImage(clothingImg, Offset.zero, paint);

        // Restaurar y aplicar efectos locales
        canvas.restore();

        // Aplicar efectos de luz y sombra (en coordenadas del canvas general)
        _applyLightingEffect(canvas, size, item.type, i);

        appliedItems.add(item.name);
        debugPrint('✅ Prenda aplicada: ${item.name} (scale=${scale.toStringAsFixed(2)}, anchor=${anchorCenter.dx.toStringAsFixed(0)},${anchorCenter.dy.toStringAsFixed(0)})');
      }

      // 5. Aplicar efecto final de iluminación y color
      _applyFinalColorCorrection(canvas, size);

      // 6. Finalizar imagen
      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(
        avatarImg.width,
        avatarImg.height,
      );

      // 7. Guardar resultado
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final resultFile = File('${tempDir.path}/advanced_outfit_$timestamp.png');

      final byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return AIGenerationResult.error('Error al codificar imagen');
      }

      await resultFile.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('✅ Imagen avanzada generada: ${resultFile.path}');

      return AIGenerationResult.success(
        resultFile,
        appliedItems,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error en generación local avanzada: $e');
      debugPrint(stackTrace.toString());
      return AIGenerationResult.error('Error: $e');
    }
  }

  /// Calcula transformación avanzada considerando medidas y capas
  Matrix4 _calculateAdvancedTransform({
    required ui.Image clothingImg,
    required Size avatarSize,
    required ClothingType type,
    UserMeasurements? measurements,
    required int layerIndex,
    required int totalLayers,
  }) {
    final matrix = Matrix4.identity();

    // Factores base
    final heightFactor = (measurements?.height ?? 170) / 170;
    final shoulderFactor = (measurements?.shoulders ?? 45) / 45;
    final waistFactor = (measurements?.waist ?? 80) / 80;

    // Calcular escala y posición según tipo de prenda
    double scaleX, scaleY;
    double translateX, translateY;

    switch (type) {
      case ClothingType.top:
        scaleX = (avatarSize.width * 0.55 * shoulderFactor) / clothingImg.width;
        scaleY = (avatarSize.height * 0.35 * heightFactor) / clothingImg.height;
        translateX = avatarSize.width * 0.225;
        translateY = avatarSize.height * 0.18 * heightFactor;
        break;

      case ClothingType.bottom:
        scaleX = (avatarSize.width * 0.50 * waistFactor / 0.8) / clothingImg.width;
        scaleY = (avatarSize.height * 0.45 * heightFactor) / clothingImg.height;
        translateX = avatarSize.width * 0.25;
        translateY = avatarSize.height * 0.42 * heightFactor;
        break;

      case ClothingType.headwear:
        scaleX = (avatarSize.width * 0.25) / clothingImg.width;
        scaleY = (avatarSize.height * 0.12) / clothingImg.height;
        translateX = avatarSize.width * 0.375;
        translateY = avatarSize.height * 0.05 * heightFactor;
        break;

      case ClothingType.footwear:
        scaleX = (avatarSize.width * 0.35) / clothingImg.width;
        scaleY = (avatarSize.height * 0.08) / clothingImg.height;
        translateX = avatarSize.width * 0.325;
        translateY = avatarSize.height * 0.88 * heightFactor;
        break;

      case ClothingType.neckwear:
        scaleX = (avatarSize.width * 0.20) / clothingImg.width;
        scaleY = (avatarSize.height * 0.10) / clothingImg.height;
        translateX = avatarSize.width * 0.40;
        translateY = avatarSize.height * 0.15 * heightFactor;
        break;
    }

    // Aplicar transformación
    matrix.translate(translateX, translateY);
    matrix.scale(scaleX, scaleY, 1.0);

    // Pequeña compensación por capa para evitar z-fighting
    final layerOffset = layerIndex * 0.001;
    matrix.translate(0, 0, layerOffset);

    return matrix;
  }

  /// Aplica efectos de iluminación específicos por tipo de prenda
  void _applyLightingEffect(Canvas canvas, Size size, ClothingType type, int layerIndex) {
    final lightingPaint = Paint()
      ..blendMode = ui.BlendMode.overlay;

    // Gradiente de iluminación sutil
    switch (type) {
      case ClothingType.top:
        lightingPaint.shader = ui.Gradient.linear(
          Offset(size.width * 0.2, size.height * 0.2),
          Offset(size.width * 0.8, size.height * 0.4),
          [
            Colors.white.withAlpha(15),
            Colors.transparent,
            Colors.black.withAlpha(10),
          ],
          [0.0, 0.5, 1.0],
        );
        break;
      case ClothingType.bottom:
        lightingPaint.shader = ui.Gradient.linear(
          Offset(size.width * 0.3, size.height * 0.5),
          Offset(size.width * 0.7, size.height * 0.8),
          [
            Colors.white.withAlpha(10),
            Colors.transparent,
            Colors.black.withAlpha(15),
          ],
          [0.0, 0.5, 1.0],
        );
        break;
      default:
        lightingPaint.shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          size.width * 0.3,
          [
            Colors.white.withAlpha(10),
            Colors.transparent,
          ],
        );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      lightingPaint,
    );
  }

  /// Aplica corrección de color final
  void _applyFinalColorCorrection(Canvas canvas, Size size) {
    // Ajuste sutil de color para unificar la imagen
    final correctionPaint = Paint()
      ..color = Colors.white.withAlpha(5)
      ..blendMode = ui.BlendMode.softLight;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      correctionPaint,
    );
  }

  /// Generación con Replicate API (comentado - requiere API key)
  Future<AIGenerationResult> _generateWithReplicate({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    String? style,
    String? background,
  }) async {
    // TODO: Implementar cuando se tenga API key
    // Por ahora retorna generación local
    return _generateLocalAdvanced(
      avatarImage: avatarImage,
      outfitItems: outfitItems,
    );
  }

  /// Generación con Stability AI (comentado - requiere API key)
  Future<AIGenerationResult> _generateWithStability({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    String? style,
    String? background,
  }) async {
    // TODO: Implementar cuando se tenga API key
    return _generateLocalAdvanced(
      avatarImage: avatarImage,
      outfitItems: outfitItems,
    );
  }

  /// Generación con OpenAI DALL-E (comentado - requiere API key)
  Future<AIGenerationResult> _generateWithOpenAI({
    required File avatarImage,
    required List<ClothingItem> outfitItems,
    String? style,
    String? background,
  }) async {
    // TODO: Implementar cuando se tenga API key
    return _generateLocalAdvanced(
      avatarImage: avatarImage,
      outfitItems: outfitItems,
    );
  }

  /// Ordena prendas por capas
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
    String? style,
    String? background,
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
      style: style,
      background: background,
    );
  }

  /// Configura el proveedor de IA
  void setProvider(String provider, {String? apiKey}) {
    _activeProvider = provider;
    if (apiKey != null) _apiKey = apiKey;
  }

  /// Obtiene el proveedor activo
  String get activeProvider => _activeProvider;
}
