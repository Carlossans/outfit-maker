import 'dart:ui';

/// Zonas del cuerpo donde se pueden colocar prendas
/// Cada zona tiene posición y tamaño estandarizados
enum BodyZone {
  head,      // Cabeza - gorros, sombreros
  neck,      // Cuello - bufandas
  shoulders, // Hombros
  chest,     // Pecho/torso superior
  torso,     // Torso completo - camisetas, camisas
  waist,     // Cintura
  hips,      // Caderas
  legs,      // Piernas - pantalones
  feet,      // Pies - zapatos
}

/// Extensión con propiedades de cada zona del cuerpo
extension BodyZoneExtension on BodyZone {
  /// Nombre legible
  String get displayName {
    switch (this) {
      case BodyZone.head:
        return 'Cabeza';
      case BodyZone.neck:
        return 'Cuello';
      case BodyZone.shoulders:
        return 'Hombros';
      case BodyZone.chest:
        return 'Pecho';
      case BodyZone.torso:
        return 'Torso';
      case BodyZone.waist:
        return 'Cintura';
      case BodyZone.hips:
        return 'Caderas';
      case BodyZone.legs:
        return 'Piernas';
      case BodyZone.feet:
        return 'Pies';
    }
  }

  /// Icono representativo
  String get icon {
    switch (this) {
      case BodyZone.head:
        return '🧢';
      case BodyZone.neck:
        return '🧣';
      case BodyZone.shoulders:
        return '💪';
      case BodyZone.chest:
        return '👕';
      case BodyZone.torso:
        return '👔';
      case BodyZone.waist:
        return '〰️';
      case BodyZone.hips:
        return '🩳';
      case BodyZone.legs:
        return '👖';
      case BodyZone.feet:
        return '👟';
    }
  }
}

/// Categorías de prendas que el usuario selecciona
enum ClothingCategory {
  headwear,   // Gorros, sombreros
  top,        // Parte superior (camisetas, camisas, jerseys)
  bottom,     // Parte inferior (pantalones, faldas)
  footwear,   // Calzado
  accessory,  // Accesorios (bufandas, cinturones)
}

extension ClothingCategoryExtension on ClothingCategory {
  String get displayName {
    switch (this) {
      case ClothingCategory.headwear:
        return 'Cabeza';
      case ClothingCategory.top:
        return 'Parte Superior';
      case ClothingCategory.bottom:
        return 'Parte Inferior';
      case ClothingCategory.footwear:
        return 'Calzado';
      case ClothingCategory.accessory:
        return 'Accesorios';
    }
  }

  String get icon {
    switch (this) {
      case ClothingCategory.headwear:
        return '🧢';
      case ClothingCategory.top:
        return '👕';
      case ClothingCategory.bottom:
        return '👖';
      case ClothingCategory.footwear:
        return '👟';
      case ClothingCategory.accessory:
        return '✨';
    }
  }

  /// Zona(s) del cuerpo que cubre esta categoría
  List<BodyZone> get coveredZones {
    switch (this) {
      case ClothingCategory.headwear:
        return [BodyZone.head];
      case ClothingCategory.top:
        return [BodyZone.shoulders, BodyZone.chest, BodyZone.torso];
      case ClothingCategory.bottom:
        return [BodyZone.waist, BodyZone.hips, BodyZone.legs];
      case ClothingCategory.footwear:
        return [BodyZone.feet];
      case ClothingCategory.accessory:
        return [BodyZone.neck];
    }
  }
}

/// Definición de posición de una prenda sobre el avatar
/// Todas las medidas son porcentajes (0.0 - 1.0) relativos al tamaño del avatar
class ClothingPosition {
  /// Zona principal donde se coloca
  final BodyZone primaryZone;

  /// Posición horizontal (0.0 = izquierda, 0.5 = centro, 1.0 = derecha)
  final double anchorX;

  /// Posición vertical (0.0 = arriba, 1.0 = abajo)
  final double anchorY;

  /// Ancho como porcentaje del ancho del avatar (0.0 - 1.0)
  final double widthPercent;

  /// Alto como porcentaje del alto del avatar (0.0 - 1.0)
  final double heightPercent;

  /// Orden de capa (mayor = más arriba)
  final int layerOrder;

  /// Rotación en grados
  final double rotation;

  const ClothingPosition({
    required this.primaryZone,
    this.anchorX = 0.5,
    this.anchorY = 0.5,
    this.widthPercent = 0.3,
    this.heightPercent = 0.2,
    this.layerOrder = 0,
    this.rotation = 0,
  });

  /// Posición por defecto según la categoría
  factory ClothingPosition.forCategory(ClothingCategory category) {
    switch (category) {
      case ClothingCategory.headwear:
        return const ClothingPosition(
          primaryZone: BodyZone.head,
          anchorX: 0.5,
          anchorY: 0.08,
          widthPercent: 0.35,
          heightPercent: 0.18,
          layerOrder: 5,
        );
      case ClothingCategory.top:
        return const ClothingPosition(
          primaryZone: BodyZone.torso,
          anchorX: 0.5,
          anchorY: 0.38,
          widthPercent: 0.65,
          heightPercent: 0.32,
          layerOrder: 3,
        );
      case ClothingCategory.bottom:
        return const ClothingPosition(
          primaryZone: BodyZone.legs,
          anchorX: 0.5,
          anchorY: 0.72,
          widthPercent: 0.55,
          heightPercent: 0.35,
          layerOrder: 2,
        );
      case ClothingCategory.footwear:
        return const ClothingPosition(
          primaryZone: BodyZone.feet,
          anchorX: 0.5,
          anchorY: 0.92,
          widthPercent: 0.40,
          heightPercent: 0.12,
          layerOrder: 1,
        );
      case ClothingCategory.accessory:
        return const ClothingPosition(
          primaryZone: BodyZone.neck,
          anchorX: 0.5,
          anchorY: 0.22,
          widthPercent: 0.30,
          heightPercent: 0.15,
          layerOrder: 4,
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'primaryZone': primaryZone.name,
    'anchorX': anchorX,
    'anchorY': anchorY,
    'widthPercent': widthPercent,
    'heightPercent': heightPercent,
    'layerOrder': layerOrder,
    'rotation': rotation,
  };

  factory ClothingPosition.fromJson(Map<String, dynamic> json) {
    return ClothingPosition(
      primaryZone: BodyZone.values.byName(json['primaryZone']),
      anchorX: json['anchorX'] as double,
      anchorY: json['anchorY'] as double,
      widthPercent: json['widthPercent'] as double,
      heightPercent: json['heightPercent'] as double,
      layerOrder: json['layerOrder'] as int,
      rotation: json['rotation'] as double? ?? 0,
    );
  }

  ClothingPosition copyWith({
    BodyZone? primaryZone,
    double? anchorX,
    double? anchorY,
    double? widthPercent,
    double? heightPercent,
    int? layerOrder,
    double? rotation,
  }) {
    return ClothingPosition(
      primaryZone: primaryZone ?? this.primaryZone,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      widthPercent: widthPercent ?? this.widthPercent,
      heightPercent: heightPercent ?? this.heightPercent,
      layerOrder: layerOrder ?? this.layerOrder,
      rotation: rotation ?? this.rotation,
    );
  }
}

/// Representa una prenda de ropa en el armario
class ClothingItem {
  final String id;
  final String name;
  final ClothingCategory category;
  final String? size;
  final String imagePath;
  final String? thumbnailPath;
  final ClothingPosition position;
  final DateTime createdAt;
  final String? color;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    this.size,
    required this.imagePath,
    this.thumbnailPath,
    required this.position,
    required this.createdAt,
    this.color,
  });

  /// Crea una copia con valores modificados
  ClothingItem copyWith({
    String? id,
    String? name,
    ClothingCategory? category,
    String? size,
    String? imagePath,
    String? thumbnailPath,
    ClothingPosition? position,
    DateTime? createdAt,
    String? color,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      size: size ?? this.size,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'size': size,
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'position': position.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'color': color,
    };
  }

  /// Crea desde JSON
  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ClothingCategory.values.byName(json['category'] as String),
      size: json['size'] as String?,
      imagePath: json['imagePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      position: ClothingPosition.fromJson(json['position'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: json['color'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClothingItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClothingItem(id: $id, name: $name, category: $category)';
}

/// Capa de un outfit - representa una prenda posicionada
class OutfitLayer {
  final ClothingItem item;
  final bool isVisible;

  const OutfitLayer({
    required this.item,
    this.isVisible = true,
  });

  factory OutfitLayer.fromJson(Map<String, dynamic> json) {
    return OutfitLayer(
      item: ClothingItem.fromJson(json['item'] as Map<String, dynamic>),
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'isVisible': isVisible,
    };
  }

  OutfitLayer copyWith({
    ClothingItem? item,
    bool? isVisible,
  }) {
    return OutfitLayer(
      item: item ?? this.item,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}
