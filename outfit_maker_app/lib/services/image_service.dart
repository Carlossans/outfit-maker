import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio para gestionar imágenes
class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Selecciona una imagen de la galería
  Future<File?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return null;

    return File(image.path);
  }

  /// Toma una foto con la cámara
  Future<File?> pickFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null) return null;

    return File(image.path);
  }

  /// Guarda una imagen de prenda permanentemente
  Future<String?> saveClothingImage(File image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final clothesDir = Directory('${appDir.path}/clothes');

      if (!await clothesDir.exists()) {
        await clothesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'clothing_$timestamp.jpg';
      final destPath = '${clothesDir.path}/$fileName';

      await image.copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving clothing image: $e');
      return null;
    }
  }

  /// Elimina una imagen
  Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }
}