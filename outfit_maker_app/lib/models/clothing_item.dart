// /lib/models/clothing_item.dart
enum ClothingType {
  top,        // superior
  bottom,     // inferior
  headwear,   // cabeza
  footwear,   // pies
  neckwear    // cuello
}

class ClothingItem {
  final String id;
  final String name;
  final String category;
  final String size;
  final String imagePath;
  final String assetPath;
  final ClothingType type;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.size,
    required this.imagePath,
    required this.assetPath,
    required this.type,
  });

  /// Crea una copia con valores modificados
  ClothingItem copyWith({
    String? id,
    String? name,
    String? category,
    String? size,
    String? imagePath,
    String? assetPath,
    ClothingType? type,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      size: size ?? this.size,
      imagePath: imagePath ?? this.imagePath,
      assetPath: assetPath ?? this.assetPath,
      type: type ?? this.type,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'size': size,
      'imagePath': imagePath,
      'assetPath': assetPath,
      'type': type.name,
    };
  }

  /// Crea desde JSON
  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      size: json['size'] as String,
      imagePath: json['imagePath'] as String,
      assetPath: json['assetPath'] as String,
      type: ClothingType.values.byName(json['type'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClothingItem &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.size == size &&
        other.imagePath == imagePath &&
        other.assetPath == assetPath &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, category, size, imagePath, assetPath, type);
  }

  @override
  String toString() {
    return 'ClothingItem(id: $id, name: $name, type: $type, size: $size)';
  }
}