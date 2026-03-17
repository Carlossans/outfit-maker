import 'package:flutter/foundation.dart';
import 'clothing_item.dart';

class Outfit {
  final String id;
  final String name;
  final List<ClothingItem> clothes;
  final DateTime? createdAt;

  const Outfit({
    required this.id,
    required this.name,
    required this.clothes,
    this.createdAt,
  });

  /// Crea una copia con valores modificados
  Outfit copyWith({
    String? id,
    String? name,
    List<ClothingItem>? clothes,
    DateTime? createdAt,
  }) {
    return Outfit(
      id: id ?? this.id,
      name: name ?? this.name,
      clothes: clothes ?? this.clothes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clothes': clothes.map((c) => c.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Crea desde JSON
  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String,
      name: json['name'] as String,
      clothes: (json['clothes'] as List)
          .map((c) => ClothingItem.fromJson(c as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Outfit &&
        other.id == id &&
        other.name == name &&
        listEquals(other.clothes, clothes);
  }

  @override
  int get hashCode => Object.hash(id, name, clothes);

  @override
  String toString() => 'Outfit(id: $id, name: $name, items: ${clothes.length})';
}