import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_measurements.dart';
import '../models/multi_angle_avatar.dart';

/// Servicio para persistir el avatar y medidas del usuario
/// Garantiza que el usuario solo necesite crear su avatar una vez
class AvatarStorageService {
  static final AvatarStorageService _instance = AvatarStorageService._internal();
  factory AvatarStorageService() => _instance;
  AvatarStorageService._internal();

  static const String _avatarImageKey = 'avatar_image_path';
  static const String _measurementsKey = 'user_measurements';
  static const String _hasCompletedSetupKey = 'has_completed_avatar_setup';
  static const String _avatarCreatedAtKey = 'avatar_created_at';
  static const String _multiAngleAvatarKey = 'multi_angle_avatar';
  static const String _frontImageKey = 'avatar_front_image';
  static const String _rightSideImageKey = 'avatar_right_side_image';
  static const String _backImageKey = 'avatar_back_image';
  static const String _leftSideImageKey = 'avatar_left_side_image';
  static const String _sideImageKey = 'avatar_side_image'; // Legacy

  /// Si se activa, el setup del avatar se considerará completo solo cuando
  /// existan todas las vistas multi-ángulo (frente, lateral derecho, trasera, lateral izquierdo).
  /// Puedes desactivarlo para permitir la creación con una sola foto.
  static const bool requireMultiAngleSetup = true;

  /// Verifica si el usuario ya completó el setup del avatar
  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedSetupKey) ?? false;
  }

  /// Guarda el avatar completo (imagen + medidas)
  /// Si requireMultiAngleSetup es verdadero, solo marcará el setup como completado
  /// cuando se haya proporcionado un avatar multi-ángulo completo.
  Future<void> saveAvatar({
    required File avatarImage,
    required UserMeasurements measurements,
    MultiAngleAvatar? multiAngleAvatar,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Copiar imagen a almacenamiento permanente de la app
    final permanentImagePath = await _saveAvatarImagePermanently(avatarImage);

    // Guardar path de la imagen
    await prefs.setString(_avatarImageKey, permanentImagePath);

    // Guardar medidas
    await prefs.setString(_measurementsKey, jsonEncode(measurements.toJson()));

    // Guardar avatar multi-ángulo si existe
    if (multiAngleAvatar != null) {
      await prefs.setString(_multiAngleAvatarKey, multiAngleAvatar.toJsonString());
    }

    // Marcar setup como completado solo si no se requiere multi-ángulo o
    // si el avatar_multi_ángulo está completo
    bool markComplete = true;
    if (requireMultiAngleSetup) {
      if (multiAngleAvatar == null) {
        markComplete = false;
      } else {
        markComplete = multiAngleAvatar.isComplete;
      }
    }

    if (markComplete) {
      await prefs.setBool(_hasCompletedSetupKey, true);
      await prefs.setString(_avatarCreatedAtKey, DateTime.now().toIso8601String());
      debugPrint('Avatar guardado exitosamente en: $permanentImagePath');
    } else {
      // Guardar sin marcar como completo
      await prefs.setString(_avatarCreatedAtKey, DateTime.now().toIso8601String());
      debugPrint('Avatar guardado pero multi-ángulo incompleto, no se marca como completo.');
    }
  }

  /// Obtiene la ruta de la imagen del avatar guardada
  Future<String?> getAvatarImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarImageKey);
  }

  /// Obtiene el archivo de imagen del avatar
  Future<File?> getAvatarImageFile() async {
    final path = await getAvatarImagePath();
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Obtiene las medidas guardadas del usuario
  Future<UserMeasurements?> getMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_measurementsKey);

    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserMeasurements.fromJson(json);
    } catch (e) {
      debugPrint('Error al cargar medidas: $e');
      return null;
    }
  }

  /// Obtiene la fecha de creación del avatar
  Future<DateTime?> getAvatarCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_avatarCreatedAtKey);
    if (dateString == null) return null;
    return DateTime.tryParse(dateString);
  }

  /// Guarda el avatar multi-ángulo
  Future<void> saveMultiAngleAvatar(MultiAngleAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_multiAngleAvatarKey, avatar.toJsonString());
  }

  /// Obtiene el avatar multi-ángulo
  Future<MultiAngleAvatar?> getMultiAngleAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_multiAngleAvatarKey);
    if (jsonString == null) return null;

    try {
      return MultiAngleAvatar.fromJsonString(jsonString);
    } catch (e) {
      debugPrint('Error cargando avatar multi-ángulo: $e');
      return null;
    }
  }

  /// Guarda una imagen para un ángulo específico
  Future<String?> saveAngleImage(File image, AvatarAngle angle) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/avatar');

    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_${angle.name}_$timestamp.jpg';
    final destPath = '${avatarDir.path}/$fileName';

    await image.copy(destPath);

    // Guardar referencia
    final prefs = await SharedPreferences.getInstance();
    switch (angle) {
      case AvatarAngle.front:
        await prefs.setString(_frontImageKey, destPath);
        break;
      case AvatarAngle.rightSide:
        await prefs.setString(_rightSideImageKey, destPath);
        // Legacy compatibility
        await prefs.setString(_sideImageKey, destPath);
        break;
      case AvatarAngle.back:
        await prefs.setString(_backImageKey, destPath);
        break;
      case AvatarAngle.leftSide:
        await prefs.setString(_leftSideImageKey, destPath);
        break;
    }

    return destPath;
  }

  /// Obtiene la imagen para un ángulo específico
  Future<File?> getAngleImage(AvatarAngle angle) async {
    final prefs = await SharedPreferences.getInstance();
    String? path;

    switch (angle) {
      case AvatarAngle.front:
        path = prefs.getString(_frontImageKey);
        break;
      case AvatarAngle.rightSide:
        path = prefs.getString(_rightSideImageKey) ?? prefs.getString(_sideImageKey);
        break;
      case AvatarAngle.back:
        path = prefs.getString(_backImageKey);
        break;
      case AvatarAngle.leftSide:
        path = prefs.getString(_leftSideImageKey);
        break;
    }

    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Verifica si tiene todas las vistas del avatar
  Future<bool> hasCompleteMultiAngleAvatar() async {
    final multiAngle = await getMultiAngleAvatar();
    return multiAngle?.isComplete ?? false;
  }

  /// Elimina el avatar y todas las preferencias relacionadas
  Future<void> clearAvatar() async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar archivo de imagen si existe
    final imagePath = await getAvatarImagePath();
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error eliminando imagen: $e');
      }
    }

    // Limpiar preferencias
    await prefs.remove(_avatarImageKey);
    await prefs.remove(_measurementsKey);
    await prefs.remove(_hasCompletedSetupKey);
    await prefs.remove(_avatarCreatedAtKey);
  }

  /// Actualiza las medidas manteniendo la misma imagen
  Future<void> updateMeasurements(UserMeasurements measurements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_measurementsKey, jsonEncode(measurements.toJson()));
  }

  /// Actualiza la imagen del avatar manteniendo las mismas medidas
  Future<void> updateAvatarImage(File newImage) async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar imagen anterior
    final oldPath = prefs.getString(_avatarImageKey);
    if (oldPath != null) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('Error eliminando imagen anterior: $e');
      }
    }

    // Guardar nueva imagen
    final newPath = await _saveAvatarImagePermanently(newImage);
    await prefs.setString(_avatarImageKey, newPath);
  }

  /// Guarda la imagen del avatar en almacenamiento permanente de la app
  Future<String> _saveAvatarImagePermanently(File sourceImage) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/avatar');

    // Crear directorio si no existe
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // Copiar archivo con timestamp para evitar conflictos
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_$timestamp.jpg';
    final destPath = '${avatarDir.path}/$fileName';

    await sourceImage.copy(destPath);
    return destPath;
  }
}
