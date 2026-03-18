import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outfit.dart';
import '../models/clothing_item.dart';

/// Servicio para gestionar outfits guardados
class OutfitService {
  static const String _outfitsKey = 'saved_outfits_v2';
  static const String _outfitCounterKey = 'outfit_counter';

  static final OutfitService _instance = OutfitService._internal();
  factory OutfitService() => _instance;
  OutfitService._internal();

  final List<Outfit> _outfits = [];
  bool _isInitialized = false;

  /// Inicializa el servicio cargando outfits guardados
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadOutfits();
    _isInitialized = true;
  }

  /// Guarda un nuevo outfit con capas
  Future<Outfit> saveOutfit({
    required String name,
    required List<ClothingItem> clothes,
    String? thumbnailPath,
  }) async {
    // Crear capas ordenadas por categoría (layerOrder)
    final layers = clothes
        .map((item) => OutfitLayer(item: item))
        .toList()
      ..sort((a, b) => a.item.position.layerOrder.compareTo(b.item.position.layerOrder));

    final outfit = Outfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      layers: layers,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );

    _outfits.add(outfit);
    await _saveToStorage();
    await _incrementCounter();

    debugPrint('✅ Outfit guardado: ${outfit.name} (${layers.length} prendas)');
    return outfit;
  }

  /// Guarda un outfit completo con capas personalizadas
  Future<Outfit> saveOutfitWithLayers({
    required String name,
    required List<OutfitLayer> layers,
    String? thumbnailPath,
  }) async {
    final outfit = Outfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      layers: layers,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );

    _outfits.add(outfit);
    await _saveToStorage();
    await _incrementCounter();

    return outfit;
  }

  /// Obtiene todos los outfits guardados
  List<Outfit> getAllOutfits() {
    return List.unmodifiable(_outfits);
  }

  /// Obtiene un outfit por ID
  Outfit? getOutfitById(String id) {
    try {
      return _outfits.firstWhere((o) => o.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza un outfit existente
  Future<bool> updateOutfit(Outfit updatedOutfit) async {
    final index = _outfits.indexWhere((o) => o.id == updatedOutfit.id);
    if (index != -1) {
      _outfits[index] = updatedOutfit.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Elimina un outfit
  Future<bool> deleteOutfit(String id) async {
    final initialLength = _outfits.length;
    _outfits.removeWhere((o) => o.id == id);
    if (_outfits.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Busca outfits por nombre
  List<Outfit> searchOutfits(String query) {
    final lowerQuery = query.toLowerCase();
    return _outfits
        .where((o) => o.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Obtiene outfits por categoría de prenda
  List<Outfit> getOutfitsByCategory(ClothingCategory category) {
    return _outfits.where((o) => o.hasCategory(category)).toList();
  }

  /// Obtiene outfits recientes (últimos N días)
  List<Outfit> getRecentOutfits({int days = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _outfits
        .where((o) => o.createdAt.isAfter(cutoffDate))
        .toList();
  }

  /// Obtiene los outfits más recientes
  List<Outfit> getMostRecentOutfits({int limit = 5}) {
    final sorted = List<Outfit>.from(_outfits)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  /// Obtiene outfits que contienen una prenda específica
  List<Outfit> getOutfitsContainingClothing(String clothingId) {
    return _outfits.where((o) {
      return o.layers.any((l) => l.item.id == clothingId);
    }).toList();
  }

  /// Limpia todos los outfits
  Future<void> clearAllOutfits() async {
    _outfits.clear();
    await _saveToStorage();
  }

  /// Obtiene el número total de outfits
  int get outfitCount => _outfits.length;

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _outfits.map((o) => o.toJson()).toList();
      await prefs.setString(_outfitsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving outfits: $e');
    }
  }

  /// Carga desde SharedPreferences
  Future<void> _loadOutfits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_outfitsKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _outfits.clear();
        _outfits.addAll(
          jsonList.map((json) => Outfit.fromJson(json as Map<String, dynamic>)),
        );
        debugPrint('✅ ${_outfits.length} outfits cargados');
      }
    } catch (e) {
      debugPrint('Error loading outfits: $e');
    }
  }

  /// Incrementa el contador de outfits creados
  Future<void> _incrementCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_outfitCounterKey) ?? 0;
      await prefs.setInt(_outfitCounterKey, current + 1);
    } catch (e) {
      debugPrint('Error incrementing counter: $e');
    }
  }

  /// Obtiene estadísticas
  Map<String, dynamic> getStats() {
    if (_outfits.isEmpty) {
      return {
        'totalOutfits': 0,
        'totalItems': 0,
        'averageItemsPerOutfit': '0.0',
      };
    }

    final totalItems = _outfits.fold<int>(0, (sum, o) => sum + o.layers.length);

    return {
      'totalOutfits': _outfits.length,
      'totalItems': totalItems,
      'averageItemsPerOutfit': (totalItems / _outfits.length).toStringAsFixed(1),
    };
  }
}
