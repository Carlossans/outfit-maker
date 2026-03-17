import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/clothing_item.dart';
import 'bg_removal_service.dart';
import 'wardrobe_service.dart';

/// Servicio para descargar imágenes de ropa desde URLs
class ImageDownloadService {
  final BgRemovalService _bgRemovalService = BgRemovalService();

  /// Descarga una imagen desde una URL
  Future<File?> downloadImage(String url, {String? customFileName}) async {
    try {
      debugPrint('⬇️ Descargando imagen desde: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('❌ Error descargando imagen: ${response.statusCode}');
        return null;
      }

      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();

      // Generar nombre de archivo
      final fileName = customFileName ??
          'downloaded_${DateTime.now().millisecondsSinceEpoch}.${_getExtension(url)}';

      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);

      // Guardar bytes
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('✅ Imagen descargada: $filePath');
      return file;
    } catch (e) {
      debugPrint('❌ Error descargando imagen: $e');
      return null;
    }
  }

  /// Descarga y procesa una imagen de ropa (elimina fondo)
  Future<ClothingItem?> downloadAndProcessClothing({
    required String imageUrl,
    required String name,
    required ClothingType type,
    required String size,
    String category = 'general',
  }) async {
    try {
      // Descargar imagen
      final downloadedFile = await downloadImage(imageUrl);
      if (downloadedFile == null) return null;

      // Procesar con remove.bg
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'clothing_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final processedFile = await _bgRemovalService.removeBackground(
        downloadedFile,
        outputPath,
      );

      if (processedFile == null) {
        debugPrint('⚠️ No se pudo eliminar el fondo, usando imagen original');
        // Usar imagen original si falla el procesamiento
        final item = ClothingItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          category: category,
          size: size,
          imagePath: downloadedFile.path,
          assetPath: '',
          type: type,
        );

        await WardrobeService().addClothing(item);
        return item;
      }

      // Crear item de ropa
      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        category: category,
        size: size,
        imagePath: processedFile.path,
        assetPath: '',
        type: type,
      );

      await WardrobeService().addClothing(item);
      debugPrint('✅ Prenda añadida al armario: ${item.name}');

      // Limpiar archivo temporal descargado
      await downloadedFile.delete().catchError((_) {});

      return item;
    } catch (e) {
      debugPrint('❌ Error procesando prenda: $e');
      return null;
    }
  }

  /// Descarga múltiples imágenes
  Future<List<File>> downloadMultipleImages(List<String> urls) async {
    final files = <File>[];

    for (final url in urls) {
      final file = await downloadImage(url);
      if (file != null) {
        files.add(file);
      }
    }

    return files;
  }

  /// Valida si una URL es una imagen válida
  Future<bool> validateImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode != 200) return false;

      final contentType = response.headers['content-type'];
      return contentType?.startsWith('image/') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene información básica de una imagen
  Future<Map<String, dynamic>?> getImageInfo(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode != 200) return null;

      return {
        'contentType': response.headers['content-type'],
        'contentLength': response.headers['content-length'],
        'lastModified': response.headers['last-modified'],
      };
    } catch (e) {
      return null;
    }
  }

  /// Extrae la extensión de archivo de una URL
  String _getExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final ext = path.split('.').last;

      // Validar extensiones comunes
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
      if (validExtensions.contains(ext.toLowerCase())) {
        return ext.toLowerCase();
      }
    } catch (e) {
      // Ignorar errores de parsing
    }

    return 'jpg'; // Default
  }

  /// Limpia archivos temporales de descargas
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File) {
          final name = path.basename(file.path);
          if (name.startsWith('downloaded_') || name.startsWith('clothing_')) {
            await file.delete().catchError((_) {});
          }
        }
      }

      debugPrint('🧹 Archivos temporales limpiados');
    } catch (e) {
      debugPrint('Error limpiando archivos: $e');
    }
  }
}

/// Modelo para representar una prenda de una URL con metadatos
class UrlClothingItem {
  final String url;
  final String name;
  final String? description;
  final String? brand;
  final String? price;
  final ClothingType type;
  final String size;
  final String category;

  const UrlClothingItem({
    required this.url,
    required this.name,
    this.description,
    this.brand,
    this.price,
    required this.type,
    required this.size,
    this.category = 'general',
  });

  /// Crea desde un mapa (útil para importar desde JSON)
  factory UrlClothingItem.fromJson(Map<String, dynamic> json) {
    return UrlClothingItem(
      url: json['url'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      brand: json['brand'] as String?,
      price: json['price'] as String?,
      type: ClothingType.values.byName(json['type'] as String),
      size: json['size'] as String,
      category: json['category'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      'description': description,
      'brand': brand,
      'price': price,
      'type': type.name,
      'size': size,
      'category': category,
    };
  }
}
