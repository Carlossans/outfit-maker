// /lib/models/outfit_album.dart

/// Representa una colección de outfits organizados por temporada u ocasión
class OutfitAlbum {
  final String id;
  final String name;
  final String? description;
  final String? coverImagePath;
  final List<String> outfitIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? season; // 'verano', 'invierno', 'primavera', 'otoño', 'casual', 'formal'

  const OutfitAlbum({
    required this.id,
    required this.name,
    this.description,
    this.coverImagePath,
    required this.outfitIds,
    this.createdAt,
    this.updatedAt,
    this.season,
  });

  /// Crea una copia con valores modificados
  OutfitAlbum copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImagePath,
    List<String>? outfitIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? season,
  }) {
    return OutfitAlbum(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      outfitIds: outfitIds ?? this.outfitIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      season: season ?? this.season,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImagePath': coverImagePath,
      'outfitIds': outfitIds,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'season': season,
    };
  }

  /// Crea desde JSON
  factory OutfitAlbum.fromJson(Map<String, dynamic> json) {
    return OutfitAlbum(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverImagePath: json['coverImagePath'] as String?,
      outfitIds: (json['outfitIds'] as List?)?.map((e) => e as String).toList() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      season: json['season'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OutfitAlbum &&
        other.id == id &&
        other.name == name &&
        other.outfitIds.equals(outfitIds);
  }

  @override
  int get hashCode => Object.hash(id, name, outfitIds);

  @override
  String toString() => 'OutfitAlbum(id: $id, name: $name, outfits: ${outfitIds.length})';

  /// Obtiene el número de outfits en el álbum
  int get outfitCount => outfitIds.length;

  /// Verifica si un outfit está en el álbum
  bool containsOutfit(String outfitId) => outfitIds.contains(outfitId);

  /// Añade un outfit a la lista (para uso en memoria)
  void addOutfit(String outfitId) {
    if (!outfitIds.contains(outfitId)) {
      outfitIds.add(outfitId);
    }
  }

  /// Elimina un outfit de la lista (para uso en memoria)
  void removeOutfit(String outfitId) {
    outfitIds.remove(outfitId);
  }
}

// Extensión para comparar listas
extension<T> on List<T> {
  bool equals(List<T> other) {
    if (identical(this, other)) return true;
    if (length != other.length) return false;
    for (int i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}
