import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing_item.dart';

class WardrobeService {
  static const String _storageKey = 'wardrobe_items';
  static final WardrobeService _instance = WardrobeService._internal();

  factory WardrobeService() => _instance;

  WardrobeService._internal();

  final List<ClothingItem> _clothes = [];
  bool _isInitialized = false;

  /// Inicializa el servicio cargando datos guardados
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
  }

  /// Añade una prenda al armario
  Future<void> addClothing(ClothingItem item) async {
    _clothes.add(item);
    await _saveToStorage();
  }

  /// Elimina una prenda del armario
  Future<bool> removeClothing(String id) async {
    final initialLength = _clothes.length;
    _clothes.removeWhere((item) => item.id == id);
    if (_clothes.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Obtiene todas las prendas
  List<ClothingItem> getClothes() {
    return List.unmodifiable(_clothes);
  }

  /// Obtiene prendas por categoría
  List<ClothingItem> getClothesByCategory(ClothingCategory category) {
    return _clothes.where((item) => item.category == category).toList();
  }

  /// Organiza prendas por categoría
  Map<ClothingCategory, List<ClothingItem>> getClothesByCategories() {
    final result = <ClothingCategory, List<ClothingItem>>{};
    for (final category in ClothingCategory.values) {
      result[category] = getClothesByCategory(category);
    }
    return result;
  }

  /// Busca prendas por nombre
  List<ClothingItem> searchClothes(String query) {
    final lowerQuery = query.toLowerCase();
    return _clothes
        .where((item) => item.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Obtiene una prenda por ID
  ClothingItem? getClothingById(String id) {
    try {
      return _clothes.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza una prenda existente
  Future<bool> updateClothing(ClothingItem updatedItem) async {
    final index = _clothes.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _clothes[index] = updatedItem;
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Limpia todas las prendas
  Future<void> clearAll() async {
    _clothes.clear();
    await _saveToStorage();
  }

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _clothes.map((item) => item.toJson()).toList();
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
        _clothes.clear();
        _clothes.addAll(
          jsonList.map((json) => ClothingItem.fromJson(json as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Error loading wardrobe: $e');
    }
  }

  /// Obtiene el número total de prendas
  int get count => _clothes.length;
}