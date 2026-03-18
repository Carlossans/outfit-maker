import 'clothing_item.dart';

/// Representa un outfit completo con capas de prendas
class Outfit {
  final String id;
  final String name;
  final List<OutfitLayer> layers;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? thumbnailPath;

  const Outfit({
    required this.id,
    required this.name,
    required this.layers,
    required this.createdAt,
    this.updatedAt,
    this.thumbnailPath,
  });

  /// Obtiene las prendas del outfit
  List<ClothingItem> get clothes =>
      layers.where((l) => l.isVisible).map((l) => l.item).toList();

  /// Obtiene prendas por categoría
  List<ClothingItem> getItemsByCategory(ClothingCategory category) {
    return layers
        .where((l) => l.isVisible && l.item.category == category)
        .map((l) => l.item)
        .toList();
  }

  /// Obtiene una prenda de una categoría específica (la primera si hay varias)
  ClothingItem? getItemByCategory(ClothingCategory category) {
    try {
      return layers
          .firstWhere((l) => l.isVisible && l.item.category == category)
          .item;
    } catch (e) {
      return null;
    }
  }

  /// Verifica si tiene una prenda de cierta categoría
  bool hasCategory(ClothingCategory category) {
    return layers.any((l) => l.item.category == category && l.isVisible);
  }

  /// Crea una copia con valores modificados
  Outfit copyWith({
    String? id,
    String? name,
    List<OutfitLayer>? layers,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailPath,
  }) {
    return Outfit(
      id: id ?? this.id,
      name: name ?? this.name,
      layers: layers ?? this.layers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'layers': layers.map((l) => l.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Crea desde JSON
  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String,
      name: json['name'] as String,
      layers: (json['layers'] as List)
          .map((l) => OutfitLayer.fromJson(l as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Outfit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Outfit(id: $id, name: $name, layers: ${layers.length})';
}
