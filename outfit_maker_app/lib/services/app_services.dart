import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_models.dart';

// ==================== WARDROBE SERVICE ====================

/// Servicio simplificado para gestionar el armario de prendas
class WardrobeService {
  static const String _storageKey = 'wardrobe_v2';
  static final WardrobeService _instance = WardrobeService._internal();

  factory WardrobeService() => _instance;
  WardrobeService._internal();

  final List<ClothingItem> _items = [];
  bool _initialized = false;

  /// Inicializa el servicio cargando datos guardados
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  /// Añade una prenda al armario
  Future<void> addItem(ClothingItem item) async {
    _items.add(item);
    await _saveToStorage();
  }

  /// Elimina una prenda del armario
  Future<bool> removeItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      // Eliminar archivo de imagen si existe
      try {
        final item = _items[index];
        final file = File(item.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error eliminando imagen: $e');
      }

      _items.removeAt(index);
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Obtiene todas las prendas
  List<ClothingItem> getAllItems() => List.unmodifiable(_items);

  /// Obtiene prendas por categoría
  List<ClothingItem> getItemsByCategory(ClothingCategory category) {
    return _items.where((item) => item.category == category).toList();
  }

  /// Organiza prendas por categoría
  Map<ClothingCategory, List<ClothingItem>> getItemsByCategories() {
    final result = <ClothingCategory, List<ClothingItem>>{};
    for (final category in ClothingCategory.values) {
      result[category] = getItemsByCategory(category);
    }
    return result;
  }

  /// Busca prendas por nombre
  List<ClothingItem> searchItems(String query) {
    final lowerQuery = query.toLowerCase();
    return _items
        .where((item) => item.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Obtiene una prenda por ID
  ClothingItem? getItemById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza una prenda existente
  Future<bool> updateItem(ClothingItem updatedItem) async {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Limpia todas las prendas
  Future<void> clearAll() async {
    _items.clear();
    await _saveToStorage();
  }

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving wardrobe: $e');
    }
  }

  /// Carga desde SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _items.clear();
        _items.addAll(
          jsonList.map((json) => ClothingItem.fromJson(json as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Error loading wardrobe: $e');
    }
  }

  /// Número total de prendas
  int get count => _items.length;

  /// Verifica si hay prendas
  bool get hasItems => _items.isNotEmpty;
}

// ==================== OUTFIT SERVICE ====================

/// Servicio simplificado para gestionar outfits guardados
class OutfitService {
  static const String _storageKey = 'outfits_v2';
  static final OutfitService _instance = OutfitService._internal();

  factory OutfitService() => _instance;
  OutfitService._internal();

  final List<Outfit> _outfits = [];
  bool _initialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  /// Guarda un nuevo outfit
  Future<Outfit> saveOutfit({
    required String name,
    required List<ClothingItem> items,
  }) async {
    final outfit = Outfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      items: items,
      createdAt: DateTime.now(),
    );

    _outfits.add(outfit);
    await _saveToStorage();
    return outfit;
  }

  /// Elimina un outfit
  Future<bool> deleteOutfit(String id) async {
    final initialLength = _outfits.length;
    _outfits.removeWhere((outfit) => outfit.id == id);
    if (_outfits.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Obtiene todos los outfits
  List<Outfit> getAllOutfits() => List.unmodifiable(_outfits);

  /// Obtiene un outfit por ID
  Outfit? getOutfitById(String id) {
    try {
      return _outfits.firstWhere((outfit) => outfit.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza un outfit existente
  Future<bool> updateOutfit(Outfit updatedOutfit) async {
    final index = _outfits.indexWhere((o) => o.id == updatedOutfit.id);
    if (index != -1) {
      _outfits[index] = updatedOutfit;
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Marca un outfit como usado hoy
  Future<bool> markAsWorn(String id) async {
    final outfit = getOutfitById(id);
    if (outfit != null) {
      final updated = Outfit(
        id: outfit.id,
        name: outfit.name,
        items: outfit.items,
        createdAt: outfit.createdAt,
        wornAt: DateTime.now(),
      );
      return await updateOutfit(updated);
    }
    return false;
  }

  /// Obtiene outfits recientes (últimos 7 días)
  List<Outfit> getRecentOutfits() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _outfits
        .where((outfit) => outfit.createdAt.isAfter(weekAgo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Limpia todos los outfits
  Future<void> clearAll() async {
    _outfits.clear();
    await _saveToStorage();
  }

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _outfits.map((outfit) => outfit.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving outfits: $e');
    }
  }

  /// Carga desde SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _outfits.clear();
        _outfits.addAll(
          jsonList.map((json) => Outfit.fromJson(json as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Error loading outfits: $e');
    }
  }

  /// Número total de outfits
  int get count => _outfits.length;
}

// ==================== AVATAR SERVICE ====================

/// Servicio simplificado para gestionar el avatar/maniquí
class AvatarService {
  static const String _avatarKey = 'avatar_v2';
  static const String _hasSetupKey = 'has_completed_setup_v2';
  static final AvatarService _instance = AvatarService._internal();

  factory AvatarService() => _instance;
  AvatarService._internal();

  AvatarModel? _avatar;
  bool _initialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  /// Verifica si el usuario completó el setup
  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSetupKey) ?? false;
  }

  /// Guarda el avatar
  Future<void> saveAvatar(AvatarModel avatar) async {
    _avatar = avatar;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, jsonEncode(avatar.toJson()));
    await prefs.setBool(_hasSetupKey, true);
  }

  /// Guarda una imagen de avatar permanentemente
  Future<String?> saveAvatarImage(File image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${appDir.path}/avatar');

      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_$timestamp.jpg';
      final destPath = '${avatarDir.path}/$fileName';

      await image.copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving avatar image: $e');
      return null;
    }
  }

  /// Obtiene el avatar actual
  AvatarModel? getAvatar() => _avatar;

  /// Obtiene la ruta de la imagen del avatar
  String? getAvatarImagePath() => _avatar?.imagePath;

  /// Obtiene el archivo de imagen del avatar
  Future<File?> getAvatarImageFile() async {
    final path = _avatar?.imagePath;
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Actualiza la imagen del avatar
  Future<void> updateAvatarImage(File newImage) async {
    // Eliminar imagen anterior si existe
    if (_avatar?.imagePath != null) {
      try {
        final oldFile = File(_avatar!.imagePath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting old avatar: $e');
      }
    }

    // Guardar nueva imagen
    final newPath = await saveAvatarImage(newImage);
    if (newPath != null) {
      _avatar = AvatarModel(
        imagePath: newPath,
        gender: _avatar?.gender,
        createdAt: DateTime.now(),
      );
      await _saveToStorage();
    }
  }

  /// Elimina el avatar
  Future<void> clearAvatar() async {
    if (_avatar?.imagePath != null) {
      try {
        final file = File(_avatar!.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting avatar: $e');
      }
    }

    _avatar = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarKey);
    await prefs.setBool(_hasSetupKey, false);
  }

  Future<void> _saveToStorage() async {
    if (_avatar == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarKey, jsonEncode(_avatar!.toJson()));
    } catch (e) {
      debugPrint('Error saving avatar: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_avatarKey);
      if (jsonString != null) {
        _avatar = AvatarModel.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }
}

// ==================== IMAGE SERVICE ====================

/// Servicio para gestionar imágenes de prendas
class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

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

  /// Elimina una imagen de prenda
  Future<void> deleteClothingImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting clothing image: $e');
    }
  }
}
