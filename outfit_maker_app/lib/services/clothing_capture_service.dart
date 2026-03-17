import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/multi_angle_clothing.dart';

/// Servicio para validar y procesar la captura multi-ángulo de prendas
class ClothingCaptureService {
  static final ClothingCaptureService _instance = ClothingCaptureService._internal();
  factory ClothingCaptureService() => _instance;
  ClothingCaptureService._internal();

  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Valida que la imagen contenga una prenda válida
  Future<CaptureValidationResult> validateClothingImage(
    File imageFile,
    ClothingType expectedType,
    ClothingAngle angle,
  ) async {
    try {
      // Verificar que el archivo existe y es válido
      if (!await imageFile.exists()) {
        return CaptureValidationResult.notValid('La imagen no existe o está corrupta');
      }

      // Validar tamaño mínimo
      final stat = await imageFile.stat();
      if (stat.size < 1024) {
        return CaptureValidationResult.notValid('La imagen es demasiado pequeña');
      }

      // Verificar que es una imagen válida
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        return CaptureValidationResult.notValid('No se pudo leer la imagen');
      }

      // Validaciones específicas según el tipo de prenda
      final typeValidation = _validateForClothingType(expectedType, angle);
      if (!typeValidation.isValid) {
        return typeValidation;
      }

      // Si pasa todas las validaciones básicas
      return CaptureValidationResult.valid(
        confidence: 0.85,
        message: '${expectedType.name.capitalize()} ${angle.displayName.toLowerCase()} capturado correctamente',
        metadata: {
          'fileSize': stat.size,
          'angle': angle.name,
          'type': expectedType.name,
        },
      );

    } catch (e) {
      return CaptureValidationResult.notValid('Error validando imagen: $e');
    }
  }

  /// Validaciones específicas por tipo de prenda
  CaptureValidationResult _validateForClothingType(
    ClothingType type,
    ClothingAngle angle,
  ) {
    // En una implementación real, aquí usaríamos ML para detectar:
    // - Que la prenda está completamente visible
    // - Que no hay arrugas excesivas
    // - Que el fondo es adecuado
    // - Que la prenda está bien iluminada

    switch (type) {
      case ClothingType.top:
        return CaptureValidationResult.valid(
          confidence: 0.9,
          message: 'Parte superior lista',
        );
      case ClothingType.bottom:
        return CaptureValidationResult.valid(
          confidence: 0.9,
          message: 'Parte inferior lista',
        );
      case ClothingType.headwear:
        return CaptureValidationResult.valid(
          confidence: 0.85,
          message: 'Accesorio de cabeza listo',
        );
      case ClothingType.footwear:
        return CaptureValidationResult.valid(
          confidence: 0.85,
          message: 'Calzado listo',
        );
      case ClothingType.neckwear:
        return CaptureValidationResult.valid(
          confidence: 0.8,
          message: 'Accesorio de cuello listo',
        );
    }
  }

  /// Procesa la imagen para mejorar calidad antes de guardar
  Future<File?> processClothingImage(
    File sourceImage, {
    bool removeBackground = false,
    double targetPadding = 0.15,
  }) async {
    try {
      // Copiar a directorio temporal de la app
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = '${tempDir.path}/clothing_processed_$timestamp.jpg';

      // En una implementación avanzada, aquí:
      // 1. Removería fondo si está habilitado
      // 2. Aplicaría corrección de color
      // 3. Recortaría con padding adecuado
      // 4. Optimizaría para tamaño

      // Por ahora, simplemente copiamos
      await sourceImage.copy(processedPath);

      return File(processedPath);
    } catch (e) {
      debugPrint('Error procesando imagen de prenda: $e');
      return null;
    }
  }

  /// Guarda las imágenes de una prenda multi-ángulo permanentemente
  Future<MultiAngleClothing?> saveMultiAngleClothing({
    required String id,
    required String name,
    required ClothingType type,
    required File frontImage,
    File? backImage,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final clothingDir = Directory('${appDir.path}/clothing/$id');

      if (!await clothingDir.exists()) {
        await clothingDir.create(recursive: true);
      }

      // Guardar imagen frontal
      final frontPath = '${clothingDir.path}/front.jpg';
      await frontImage.copy(frontPath);

      // Guardar imagen trasera si existe
      String? backPath;
      if (backImage != null) {
        backPath = '${clothingDir.path}/back.jpg';
        await backImage.copy(backPath);
      }

      return MultiAngleClothing(
        id: id,
        name: name,
        type: type,
        frontImagePath: frontPath,
        backImagePath: backPath,
        createdAt: DateTime.now(),
        metadata: {
          'hasCompleteViews': backImage != null,
          'savedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error guardando prenda multi-ángulo: $e');
      return null;
    }
  }

  /// Obtiene una prenda multi-ángulo guardada
  Future<MultiAngleClothing?> loadMultiAngleClothing(String id) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final clothingDir = Directory('${appDir.path}/clothing/$id');

      if (!await clothingDir.exists()) {
        return null;
      }

      final frontFile = File('${clothingDir.path}/front.jpg');
      final backFile = File('${clothingDir.path}/back.jpg');

      if (!await frontFile.exists()) {
        return null;
      }

      return MultiAngleClothing(
        id: id,
        name: 'Prenda $id', // Se debería cargar de metadata
        type: ClothingType.top, // Se debería cargar de metadata
        frontImagePath: frontFile.path,
        backImagePath: await backFile.exists() ? backFile.path : null,
        createdAt: await frontFile.stat().then((s) => s.changed),
      );
    } catch (e) {
      debugPrint('Error cargando prenda multi-ángulo: $e');
      return null;
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}

/// Resultado de validación de captura
class CaptureValidationResult {
  final bool isValid;
  final double confidence;
  final String message;
  final Map<String, dynamic>? metadata;

  CaptureValidationResult({
    required this.isValid,
    required this.confidence,
    required this.message,
    this.metadata,
  });

  factory CaptureValidationResult.valid({
    required double confidence,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    return CaptureValidationResult(
      isValid: true,
      confidence: confidence,
      message: message,
      metadata: metadata,
    );
  }

  factory CaptureValidationResult.notValid(String message) {
    return CaptureValidationResult(
      isValid: false,
      confidence: 0.0,
      message: message,
    );
  }
}

/// Extensión para capitalizar strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
