import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio simplificado para persistir el avatar del usuario
/// Garantiza que el usuario solo necesite crear su avatar una vez
class AvatarStorageService {
  static final AvatarStorageService _instance = AvatarStorageService._internal();
  factory AvatarStorageService() => _instance;
  AvatarStorageService._internal();

  static const String _avatarImageKey = 'avatar_image_path';
  static const String _hasCompletedSetupKey = 'has_completed_avatar_setup';
  static const String _avatarCreatedAtKey = 'avatar_created_at';

  /// Verifica si el usuario ya completó el setup del avatar
  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedSetupKey) ?? false;
  }

  /// Guarda el avatar simplificado (solo imagen)
  Future<void> saveAvatarSimple({required File avatarImage}) async {
    final prefs = await SharedPreferences.getInstance();

    // Copiar imagen a almacenamiento permanente de la app
    final permanentImagePath = await _saveAvatarImagePermanently(avatarImage);

    // Guardar path de la imagen
    await prefs.setString(_avatarImageKey, permanentImagePath);

    // Marcar setup como completado
    await prefs.setBool(_hasCompletedSetupKey, true);
    await prefs.setString(_avatarCreatedAtKey, DateTime.now().toIso8601String());

    debugPrint('Avatar guardado exitosamente en: $permanentImagePath');
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

  /// Obtiene la fecha de creación del avatar
  Future<DateTime?> getAvatarCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_avatarCreatedAtKey);
    if (dateString == null) return null;
    return DateTime.tryParse(dateString);
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
    await prefs.remove(_hasCompletedSetupKey);
    await prefs.remove(_avatarCreatedAtKey);
  }

  /// Actualiza la imagen del avatar
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
