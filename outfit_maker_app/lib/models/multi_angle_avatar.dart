import 'dart:convert';

/// Representa un avatar completo con múltiples vistas (frente, derecha, trasera, izquierda)
class MultiAngleAvatar {
  final String frontImagePath;
  final String? rightSideImagePath;
  final String? backImagePath;
  final String? leftSideImagePath;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  // Mantener compatibilidad con versiones anteriores
  final String? sideImagePath;

  MultiAngleAvatar({
    required this.frontImagePath,
    this.rightSideImagePath,
    this.backImagePath,
    this.leftSideImagePath,
    this.sideImagePath, // Legacy
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'frontImagePath': frontImagePath,
      'rightSideImagePath': rightSideImagePath,
      'backImagePath': backImagePath,
      'leftSideImagePath': leftSideImagePath,
      'sideImagePath': sideImagePath, // Legacy
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory MultiAngleAvatar.fromJson(Map<String, dynamic> json) {
    return MultiAngleAvatar(
      frontImagePath: json['frontImagePath'] as String,
      rightSideImagePath: json['rightSideImagePath'] as String? ?? json['sideImagePath'] as String?,
      backImagePath: json['backImagePath'] as String?,
      leftSideImagePath: json['leftSideImagePath'] as String?,
      sideImagePath: json['sideImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory MultiAngleAvatar.fromJsonString(String jsonString) {
    return MultiAngleAvatar.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Verifica si tiene al menos la vista frontal
  bool get hasFront => frontImagePath.isNotEmpty;

  /// Verifica si tiene vista lateral (legacy - cualquier lado)
  bool get hasSide => rightSideImagePath != null && rightSideImagePath!.isNotEmpty;

  /// Verifica si tiene vista lateral derecha
  bool get hasRightSide => rightSideImagePath != null && rightSideImagePath!.isNotEmpty;

  /// Verifica si tiene vista lateral izquierda
  bool get hasLeftSide => leftSideImagePath != null && leftSideImagePath!.isNotEmpty;

  /// Verifica si tiene vista trasera
  bool get hasBack => backImagePath != null && backImagePath!.isNotEmpty;

  /// Retorna el número de vistas disponibles
  int get viewCount {
    int count = 0;
    if (hasFront) count++;
    if (hasRightSide) count++;
    if (hasBack) count++;
    if (hasLeftSide) count++;
    return count;
  }

  /// Verifica si es un avatar completo (4 vistas)
  bool get isComplete => hasFront && hasRightSide && hasBack && hasLeftSide;

  /// Verifica si tiene vistas laterales (al menos una)
  bool get hasAnySideView => hasRightSide || hasLeftSide;

  MultiAngleAvatar copyWith({
    String? frontImagePath,
    String? rightSideImagePath,
    String? backImagePath,
    String? leftSideImagePath,
    String? sideImagePath,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return MultiAngleAvatar(
      frontImagePath: frontImagePath ?? this.frontImagePath,
      rightSideImagePath: rightSideImagePath ?? this.rightSideImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      leftSideImagePath: leftSideImagePath ?? this.leftSideImagePath,
      sideImagePath: sideImagePath ?? this.sideImagePath,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Enum para los diferentes ángulos de captura (4 vistas)
enum AvatarAngle {
  front,
  rightSide,
  back,
  leftSide,
}

extension AvatarAngleExtension on AvatarAngle {
  String get displayName {
    switch (this) {
      case AvatarAngle.front:
        return 'Frente';
      case AvatarAngle.rightSide:
        return 'Lado Derecho';
      case AvatarAngle.back:
        return 'Trasera';
      case AvatarAngle.leftSide:
        return 'Lado Izquierdo';
    }
  }

  String get shortName {
    switch (this) {
      case AvatarAngle.front:
        return 'Frente';
      case AvatarAngle.rightSide:
        return 'Derecho';
      case AvatarAngle.back:
        return 'Espalda';
      case AvatarAngle.leftSide:
        return 'Izquierdo';
    }
  }

  String get description {
    switch (this) {
      case AvatarAngle.front:
        return 'De pie, mirando directamente a la cámara';
      case AvatarAngle.rightSide:
        return 'De pie, mostrando tu lado derecho a la cámara';
      case AvatarAngle.back:
        return 'De pie, de espaldas a la cámara';
      case AvatarAngle.leftSide:
        return 'De pie, mostrando tu lado izquierdo a la cámara';
    }
  }

  String get icon {
    switch (this) {
      case AvatarAngle.front:
        return '🧍';
      case AvatarAngle.rightSide:
        return '➡️';
      case AvatarAngle.back:
        return '🔙';
      case AvatarAngle.leftSide:
        return '⬅️';
    }
  }

  int get priority {
    switch (this) {
      case AvatarAngle.front:
        return 1;
      case AvatarAngle.rightSide:
        return 2;
      case AvatarAngle.back:
        return 3;
      case AvatarAngle.leftSide:
        return 4;
    }
  }

  AvatarAngle get next {
    switch (this) {
      case AvatarAngle.front:
        return AvatarAngle.rightSide;
      case AvatarAngle.rightSide:
        return AvatarAngle.back;
      case AvatarAngle.back:
        return AvatarAngle.leftSide;
      case AvatarAngle.leftSide:
        return AvatarAngle.front;
    }
  }

  AvatarAngle get previous {
    switch (this) {
      case AvatarAngle.front:
        return AvatarAngle.leftSide;
      case AvatarAngle.leftSide:
        return AvatarAngle.back;
      case AvatarAngle.back:
        return AvatarAngle.rightSide;
      case AvatarAngle.rightSide:
        return AvatarAngle.front;
    }
  }
}
