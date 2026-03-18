import 'dart:convert';
import 'dart:ui';

/// Categorías de prendas simplificadas
enum ClothingCategory {
  tops,      // Parte superior: camisetas, camisas, jerseys
  bottoms,   // Parte inferior: pantalones, faldas, shorts
  shoes,     // Calzado: zapatos, zapatillas, botas
  accessories, // Accesorios: gorros, bufandas, cinturones
}

extension ClothingCategoryExtension on ClothingCategory {
  String get displayName {
    switch (this) {
      case ClothingCategory.tops:
        return 'Parte Superior';
      case ClothingCategory.bottoms:
        return 'Parte Inferior';
      case ClothingCategory.shoes:
        return 'Calzado';
      case ClothingCategory.accessories:
        return 'Accesorios';
    }
  }

  String get icon {
    switch (this) {
      case ClothingCategory.tops:
        return '👕';
      case ClothingCategory.bottoms:
        return '👖';
      case ClothingCategory.shoes:
        return '👟';
      case ClothingCategory.accessories:
        return '🧢';
    }
  }

  /// Zona del cuerpo donde va esta categoría (0-1 relativo al cuerpo)
  BodyZone get bodyZone {
    switch (this) {
      case ClothingCategory.tops:
        return BodyZone.torso;
      case ClothingCategory.bottoms:
        return BodyZone.legs;
      case ClothingCategory.shoes:
        return BodyZone.feet;
      case ClothingCategory.accessories:
        return BodyZone.head;
    }
  }

  /// Orden de capa (menor = más abajo)
  int get layerOrder {
    switch (this) {
      case ClothingCategory.shoes:
        return 1;
      case ClothingCategory.bottoms:
        return 2;
      case ClothingCategory.tops:
        return 3;
      case ClothingCategory.accessories:
        return 4;
    }
  }
}

/// Zonas del cuerpo para posicionar prendas
enum BodyZone {
  head,    // 0.0 - 0.15
  torso,   // 0.15 - 0.50
  legs,    // 0.50 - 0.85
  feet,    // 0.85 - 1.0
}

extension BodyZoneExtension on BodyZone {
  /// Posición Y relativa (0 = arriba, 1 = abajo)
  double get relativeY {
    switch (this) {
      case BodyZone.head:
        return 0.08;
      case BodyZone.torso:
        return 0.35;
      case BodyZone.legs:
        return 0.68;
      case BodyZone.feet:
        return 0.92;
    }
  }

  /// Altura relativa de la zona
  double get relativeHeight {
    switch (this) {
      case BodyZone.head:
        return 0.15;
      case BodyZone.torso:
        return 0.35;
      case BodyZone.legs:
        return 0.35;
      case BodyZone.feet:
        return 0.15;
    }
  }

  /// Ancho relativo para prendas en esta zona
  double get relativeWidth {
    switch (this) {
      case BodyZone.head:
        return 0.35;
      case BodyZone.torso:
        return 0.70;
      case BodyZone.legs:
        return 0.60;
      case BodyZone.feet:
        return 0.45;
    }
  }
}

/// Modelo simplificado de prenda de ropa
class ClothingItem {
  final String id;
  final String name;
  final ClothingCategory category;
  final String imagePath;
  final String? color;
  final DateTime createdAt;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    this.color,
    required this.createdAt,
  });

  /// Crea una copia con valores modificados
  ClothingItem copyWith({
    String? id,
    String? name,
    ClothingCategory? category,
    String? imagePath,
    String? color,
    DateTime? createdAt,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'imagePath': imagePath,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: ClothingCategory.values.byName(json['category'] as String),
    imagePath: json['imagePath'] as String,
    color: json['color'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ClothingItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClothingItem($name, $category)';
}

/// Modelo de outfit/outfit guardado
class Outfit {
  final String id;
  final String name;
  final List<ClothingItem> items;
  final DateTime createdAt;
  final DateTime? wornAt;

  const Outfit({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.wornAt,
  });

  /// Obtiene items por categoría
  Map<ClothingCategory, ClothingItem?> get itemsByCategory {
    final result = <ClothingCategory, ClothingItem?>{};
    for (final category in ClothingCategory.values) {
      result[category] = items.where((i) => i.category == category).firstOrNull;
    }
    return result;
  }

  /// Verifica si tiene una categoría
  bool hasCategory(ClothingCategory category) {
    return items.any((i) => i.category == category);
  }

  ClothingItem copyWith({
    String? id,
    String? name,
    List<ClothingItem>? items,
    DateTime? createdAt,
    DateTime? wornAt,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: items as ClothingCategory ?? this.items as ClothingCategory,
      imagePath: '',
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'wornAt': wornAt?.toIso8601String(),
  };

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
    id: json['id'] as String,
    name: json['name'] as String,
    items: (json['items'] as List)
        .map((i) => ClothingItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    wornAt: json['wornAt'] != null
        ? DateTime.parse(json['wornAt'] as String)
        : null,
  );
}

/// Modelo del avatar/maniquí
class AvatarModel {
  final String? imagePath;
  final String? gender; // 'male', 'female', null
  final DateTime? createdAt;

  const AvatarModel({
    this.imagePath,
    this.gender,
    this.createdAt,
  });

  bool get hasCustomImage => imagePath != null && imagePath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'gender': gender,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory AvatarModel.fromJson(Map<String, dynamic> json) => AvatarModel(
    imagePath: json['imagePath'] as String?,
    gender: json['gender'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );
}
