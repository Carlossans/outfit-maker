import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';

/// Servicio para segmentación corporal usando ML Kit Selfie Segmentation
class BodySegmentationService {
  static final BodySegmentationService _instance = BodySegmentationService._internal();
  SelfieSegmenter? _segmenter;
  bool _isInitialized = false;

  factory BodySegmentationService() => _instance;

  BodySegmentationService._internal();

  /// Inicializa el segmentador
  Future<void> initialize() async {
    if (_isInitialized) return;
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.stream, // Más rápido para tiempo real
    );
    _isInitialized = true;
  }

  /// Segmenta el cuerpo de una imagen
  /// Retorna un mapa de bytes donde alpha=255 es cuerpo y alpha=0 es fondo
  Future<SegmentationMask?> segmentBody(File imageFile) async {
    if (!_isInitialized) await initialize();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final mask = await _segmenter?.processImage(inputImage);
      return mask;
    } catch (e) {
      debugPrint('Error segmentando imagen: $e');
      return null;
    }
  }

  /// Aplica la máscara a una imagen, haciendo transparente el fondo
  Future<File?> applyMaskToImage(File imageFile, SegmentationMask mask) async {
    try {
      // Leer imagen original
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convertir máscara a bitmap
      final maskBitmap = await _convertMaskToBitmap(mask, image.width, image.height);

      // Aplicar máscara
      final resultBytes = await _applyMask(image, maskBitmap);

      // Guardar imagen resultante
      final tempDir = await getTemporaryDirectory();
      final resultFile = File('${tempDir.path}/segmented_${DateTime.now().millisecondsSinceEpoch}.png');
      await resultFile.writeAsBytes(resultBytes);

      return resultFile;
    } catch (e) {
      debugPrint('Error aplicando máscara: $e');
      return null;
    }
  }

  /// Convierte la máscara a un bitmap de alpha channel
  Future<Uint8List> _convertMaskToBitmap(SegmentationMask mask, int width, int height) async {
    // La máscara viene en formato de confidence map (0-1)
    final maskData = mask.confidences; // Usar confidences (lista de doubles)
    final result = Uint8List(width * height);

    for (int i = 0; i < maskData.length && i < result.length; i++) {
      // Convertir confidence (0-1) a alpha (0-255)
      result[i] = (maskData[i] * 255).clamp(0, 255).toInt();
    }

    return result;
  }

  /// Aplica la máscara alpha a una imagen
  Future<Uint8List> _applyMask(ui.Image image, Uint8List maskAlpha) async {
    final width = image.width;
    final height = image.height;

    // Leer pixels de la imagen
    final byteData = await image.toByteData();
    if (byteData == null) return Uint8List(0);

    final pixels = byteData.buffer.asUint8List();
    final result = Uint8List(pixels.length);

    // Aplicar alpha mask a cada pixel RGBA
    for (int i = 0; i < pixels.length; i += 4) {
      final pixelIndex = i ~/ 4;
      final alphaIndex = pixelIndex < maskAlpha.length ? pixelIndex : 0;
      final maskAlphaValue = maskAlpha[alphaIndex];

      result[i] = pixels[i]; // R
      result[i + 1] = pixels[i + 1]; // G
      result[i + 2] = pixels[i + 2]; // B
      result[i + 3] = maskAlphaValue; // Alpha de la máscara
    }

    return result;
  }

  /// Extrae la silueta del cuerpo como contorno
  Future<List<Offset>?> extractBodyContour(SegmentationMask mask, Size imageSize) async {
    try {
      final contour = <Offset>[];
      final maskData = mask.confidences;
      final width = mask.width.toDouble();
      final height = mask.height.toDouble();

      // Escalar factores
      final scaleX = imageSize.width / width;
      final scaleY = imageSize.height / height;

      // Encontrar contorno usando edge detection simple
      for (int y = 0; y < mask.height; y++) {
        for (int x = 0; x < mask.width; x++) {
          final idx = y * mask.width + x;
          if (idx >= maskData.length) continue;
          final confidence = maskData[idx];

          // Si es borde (transición de fondo a cuerpo)
          if (confidence > 0.5) {
            // Verificar vecinos
            final left = x > 0 ? maskData[idx - 1] : 0;
            final top = y > 0 ? maskData[idx - mask.width] : 0;

            if (left < 0.5 || top < 0.5) {
              contour.add(Offset(x.toDouble() * scaleX, y.toDouble() * scaleY));
            }
          }
        }
      }

      return contour;
    } catch (e) {
      debugPrint('Error extrayendo contorno: $e');
      return null;
    }
  }

  /// Ajusta una prenda a la silueta del cuerpo
  /// Retorna los puntos de anclaje para la prenda
  Map<String, Offset> getClothingAnchorPoints(
    SegmentationMask mask,
    Size imageSize,
    ClothingType type,
  ) {
    final anchors = <String, Offset>{};
    final maskData = mask.confidences;
    final width = mask.width.toDouble();
    final height = mask.height.toDouble();

    final scaleX = imageSize.width / width;
    final scaleY = imageSize.height / height;

    // Encontrar puntos clave de la silueta
    double minX = width, maxX = 0, minY = height, maxY = 0;

    for (int i = 0; i < maskData.length; i++) {
      if (maskData[i] > 0.5) {
        final x = (i % mask.width).toDouble();
        final y = (i ~/ mask.width).toDouble();
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    // Centro general
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    switch (type) {
      case ClothingType.top:
        anchors['topLeft'] = Offset(minX * scaleX, minY * scaleY);
        anchors['topRight'] = Offset(maxX * scaleX, minY * scaleY);
        anchors['bottomLeft'] = Offset(minX * scaleX, centerY * scaleY);
        anchors['bottomRight'] = Offset(maxX * scaleX, centerY * scaleY);
        anchors['center'] = Offset(centerX * scaleX, centerY * scaleY);
        break;

      case ClothingType.bottom:
        anchors['topLeft'] = Offset(minX * scaleX, centerY * scaleY);
        anchors['topRight'] = Offset(maxX * scaleX, centerY * scaleY);
        anchors['bottomLeft'] = Offset(minX * scaleX, maxY * scaleY);
        anchors['bottomRight'] = Offset(maxX * scaleX, maxY * scaleY);
        anchors['center'] = Offset(centerX * scaleX, (centerY + maxY) / 2 * scaleY);
        break;

      case ClothingType.headwear:
        anchors['center'] = Offset(centerX * scaleX, minY * scaleY * 0.8);
        anchors['left'] = Offset(minX * scaleX, minY * scaleY * 0.8);
        anchors['right'] = Offset(maxX * scaleX, minY * scaleY * 0.8);
        break;

      case ClothingType.footwear:
        anchors['left'] = Offset(minX * scaleX, maxY * scaleY);
        anchors['right'] = Offset(maxX * scaleX, maxY * scaleY);
        anchors['center'] = Offset(centerX * scaleX, maxY * scaleY);
        break;

      case ClothingType.neckwear:
        anchors['center'] = Offset(centerX * scaleX, (minY + centerY) / 2 * scaleY);
        anchors['top'] = Offset(centerX * scaleX, minY * scaleY);
        anchors['bottom'] = Offset(centerX * scaleX, centerY * scaleY);
        break;
    }

    return anchors;
  }

  /// Libera recursos
  Future<void> dispose() async {
    if (_isInitialized && _segmenter != null) {
      await _segmenter!.close();
      _isInitialized = false;
    }
  }
}
