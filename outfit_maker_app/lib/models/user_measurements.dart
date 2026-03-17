import 'package:flutter/foundation.dart';

@immutable
class UserMeasurements {
  final double height;    // cm
  final double weight;    // kg
  final double shoulders; // cm
  final double waist;     // cm
  final double? chest;    // cm (opcional)
  final double? hips;     // cm (opcional)
  final double? inseam;   // cm (opcional)

  const UserMeasurements({
    required this.height,
    required this.weight,
    required this.shoulders,
    required this.waist,
    this.chest,
    this.hips,
    this.inseam,
  });

  /// Calcula el IMC
  double get bmi {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  /// Crea una copia con valores modificados
  UserMeasurements copyWith({
    double? height,
    double? weight,
    double? shoulders,
    double? waist,
    double? chest,
    double? hips,
    double? inseam,
  }) {
    return UserMeasurements(
      height: height ?? this.height,
      weight: weight ?? this.weight,
      shoulders: shoulders ?? this.shoulders,
      waist: waist ?? this.waist,
      chest: chest ?? this.chest,
      hips: hips ?? this.hips,
      inseam: inseam ?? this.inseam,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'weight': weight,
      'shoulders': shoulders,
      'waist': waist,
      'chest': chest,
      'hips': hips,
      'inseam': inseam,
    };
  }

  /// Crea desde JSON
  factory UserMeasurements.fromJson(Map<String, dynamic> json) {
    return UserMeasurements(
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      shoulders: (json['shoulders'] as num).toDouble(),
      waist: (json['waist'] as num).toDouble(),
      chest: json['chest'] != null ? (json['chest'] as num).toDouble() : null,
      hips: json['hips'] != null ? (json['hips'] as num).toDouble() : null,
      inseam: json['inseam'] != null ? (json['inseam'] as num).toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserMeasurements &&
        other.height == height &&
        other.weight == weight &&
        other.shoulders == shoulders &&
        other.waist == waist &&
        other.chest == chest &&
        other.hips == hips &&
        other.inseam == inseam;
  }

  @override
  int get hashCode =>
      Object.hash(height, weight, shoulders, waist, chest, hips, inseam);

  @override
  String toString() {
    return 'UserMeasurements(height: $height, weight: $weight, waist: $waist)';
  }
}