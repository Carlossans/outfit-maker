import 'dart:convert';
import 'dart:io';

import 'clothing_item.dart';

/// Representa una prenda con múltiples vistas (frente y reverso)
/// para mejorar la generación de outfits realistas
class MultiAngleClothing {
  final String id;
  final String name;
  final ClothingType type;
  final String frontImagePath;
  final String? backImagePath;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  MultiAngleClothing({
    required this.id,
    required this.name,
    required this.type,
    required this.frontImagePath,
    this.backImagePath,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory MultiAngleClothing.fromJson(Map<String, dynamic> json) {
    return MultiAngleClothing(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ClothingType.values.byName(json['type'] as String),
      frontImagePath: json['frontImagePath'] as String,
      backImagePath: json['backImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory MultiAngleClothing.fromJsonString(String jsonString) {
    return MultiAngleClothing.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Verifica si tiene vista frontal
  bool get hasFront => frontImagePath.isNotEmpty;

  /// Verifica si tiene vista trasera
  bool get hasBack => backImagePath != null && backImagePath!.isNotEmpty;

  /// Verifica si es una prenda completa (ambas vistas)
  bool get isComplete => hasFront && hasBack;

  /// Retorna el número de vistas disponibles
  int get viewCount {
    int count = 0;
    if (hasFront) count++;
    if (hasBack) count++;
    return count;
  }

  /// Obtiene la imagen para un ángulo específico
  File? getImageForAngle(ClothingAngle angle) {
    switch (angle) {
      case ClothingAngle.front:
        return File(frontImagePath);
      case ClothingAngle.back:
        return backImagePath != null ? File(backImagePath!) : null;
    }
  }

  MultiAngleClothing copyWith({
    String? id,
    String? name,
    ClothingType? type,
    String? frontImagePath,
    String? backImagePath,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return MultiAngleClothing(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convierte a ClothingItem básico
  ClothingItem toClothingItem({
    String? category,
    String? size,
    String? imagePath,
    String? assetPath,
  }) {
    return ClothingItem(
      id: id,
      name: name,
      category: category ?? type.name,
      size: size ?? 'M',
      imagePath: imagePath ?? frontImagePath,
      assetPath: assetPath ?? '',
      type: type,
    );
  }
}

/// Enum para los diferentes ángulos de captura de prendas
enum ClothingAngle {
  front,
  back,
}

extension ClothingAngleExtension on ClothingAngle {
  String get displayName {
    switch (this) {
      case ClothingAngle.front:
        return 'Frente';
      case ClothingAngle.back:
        return 'Reverso';
    }
  }

  String get description {
    switch (this) {
      case ClothingAngle.front:
        return 'La parte frontal de la prenda visible';
      case ClothingAngle.back:
        return 'La parte trasera de la prenda (etiqueta, costuras)';
    }
  }

  String get icon {
    switch (this) {
      case ClothingAngle.front:
        return '👕';
      case ClothingAngle.back:
        return '🔙';
    }
  }

  String get instruction {
    switch (this) {
      case ClothingAngle.front:
        return 'Coloca la prenda sobre una superficie plana, parte frontal hacia arriba';
      case ClothingAngle.back:
        return 'Voltea la prenda para mostrar la parte trasera';
    }
  }

  String get tips {
    switch (this) {
      case ClothingAngle.front:
        return 'Asegúrate de que se vean los detalles, bolsillos y cierres frontales';
      case ClothingAngle.back:
        return 'Captura etiquetas, costuras y detalles traseros';
    }
  }
}

/// Modelo para instrucciones de captura específicas por tipo de prenda
class ClothingCaptureInstructions {
  static List<String> getInstructions(ClothingType type, ClothingAngle angle) {
    final baseInstructions = [
      'Usa buena iluminación natural o artificial',
      'Fondo neutro y limpio (mesa blanca o similar)',
      'Evita sombras fuertes',
      'Mantén la cámara paralela a la prenda',
    ];

    final typeSpecific = _getTypeSpecificInstructions(type, angle);

    return [...baseInstructions, ...typeSpecific];
  }

  static List<String> _getTypeSpecificInstructions(ClothingType type, ClothingAngle angle) {
    switch (type) {
      case ClothingType.top:
        return angle == ClothingAngle.front
            ? [
                'Extiende la prenda completamente',
                'Mangas ligeramente separadas del cuerpo',
                'Captura cuello y hombros claramente',
              ]
            : [
                'Muestra la etiqueta de talla si es visible',
                'Captura la parte superior de la espalda',
              ];

      case ClothingType.bottom:
        return angle == ClothingAngle.front
            ? [
                'Extiende la cintura completamente',
                'Piernas/jareta extendidas sin arrugas',
                'Captura bolsillos y cierres frontales',
              ]
            : [
                'Muestra la parte trasera de la cintura',
                'Captura costuras traseras si las hay',
              ];

      case ClothingType.headwear:
        return angle == ClothingAngle.front
            ? [
                'Coloca la prenda en posición de uso',
                'Captura visera o parte frontal',
              ]
            : [
                'Muestra la parte trasera o cierre',
                'Captura etiqueta interior si existe',
              ];

      case ClothingType.footwear:
        return angle == ClothingAngle.front
            ? [
                'Punta del zapato hacia la cámara',
                'Captura detalles frontales (cordones, hebillas)',
              ]
            : [
                'Muestra la suela o parte trasera',
                'Captura etiqueta interior si existe',
              ];

      case ClothingType.neckwear:
        return angle == ClothingAngle.front
            ? [
                'Extiende completamente',
                'Muestra el patrón frontal',
              ]
            : [
                'Muestra el reverso del tejido',
                'Captura etiqueta si existe',
              ];
    }
  }

  static double getRecommendedPadding(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return 0.15; // 15% de padding
      case ClothingType.bottom:
        return 0.12;
      case ClothingType.headwear:
        return 0.20;
      case ClothingType.footwear:
        return 0.18;
      case ClothingType.neckwear:
        return 0.25;
    }
  }
}
