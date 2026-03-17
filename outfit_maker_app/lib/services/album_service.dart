import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outfit.dart';

/// Representa un álbum/colección de outfits
class OutfitAlbum {
  final String id;
  final String name;
  final String description;
  final String? coverImagePath;
  final List<String> outfitIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? season; // verano, invierno, primavera, otoño

  const OutfitAlbum({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImagePath,
    required this.outfitIds,
    required this.createdAt,
    this.updatedAt,
    this.season,
  });

  /// Crea una copia con valores modificados
  OutfitAlbum copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImagePath,
    List<String>? outfitIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? season,
  }) {
    return OutfitAlbum(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      outfitIds: outfitIds ?? this.outfitIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      season: season ?? this.season,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImagePath': coverImagePath,
      'outfitIds': outfitIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'season': season,
    };
  }

  /// Crea desde JSON
  factory OutfitAlbum.fromJson(Map<String, dynamic> json) {
    return OutfitAlbum(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverImagePath: json['coverImagePath'] as String?,
      outfitIds: (json['outfitIds'] as List).map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      season: json['season'] as String?,
    );
  }

  /// Obtiene el número de outfits en el álbum
  int get outfitCount => outfitIds.length;

  @override
  String toString() => 'OutfitAlbum($name: $outfitCount outfits)';
}

/// Servicio para gestionar álbumes/colecciones de outfits
class AlbumService {
  static const String _albumsKey = 'outfit_albums';
  static final AlbumService _instance = AlbumService._internal();
  factory AlbumService() => _instance;
  AlbumService._internal();

  final List<OutfitAlbum> _albums = [];
  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadAlbums();
    _isInitialized = true;
  }

  /// Crea un nuevo álbum
  Future<OutfitAlbum> createAlbum({
    required String name,
    String description = '',
    String? season,
    String? coverImagePath,
  }) async {
    final album = OutfitAlbum(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      season: season,
      coverImagePath: coverImagePath,
      outfitIds: [],
      createdAt: DateTime.now(),
    );

    _albums.add(album);
    await _saveToStorage();

    debugPrint('✅ Álbum creado: ${album.name}');
    return album;
  }

  /// Obtiene todos los álbumes
  List<OutfitAlbum> getAllAlbums() {
    return List.unmodifiable(_albums);
  }

  /// Obtiene un álbum por ID
  OutfitAlbum? getAlbumById(String id) {
    try {
      return _albums.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene álbumes por temporada
  List<OutfitAlbum> getAlbumsBySeason(String season) {
    return _albums.where((a) => a.season == season).toList();
  }

  /// Añade un outfit a un álbum
  Future<bool> addOutfitToAlbum(String albumId, String outfitId) async {
    final index = _albums.indexWhere((a) => a.id == albumId);
    if (index == -1) return false;

    final album = _albums[index];
    if (album.outfitIds.contains(outfitId)) return true; // Ya está

    final updatedIds = List<String>.from(album.outfitIds)..add(outfitId);
    _albums[index] = album.copyWith(
      outfitIds: updatedIds,
      updatedAt: DateTime.now(),
    );

    await _saveToStorage();
    return true;
  }

  /// Elimina un outfit de un álbum
  Future<bool> removeOutfitFromAlbum(String albumId, String outfitId) async {
    final index = _albums.indexWhere((a) => a.id == albumId);
    if (index == -1) return false;

    final album = _albums[index];
    final updatedIds = List<String>.from(album.outfitIds)..remove(outfitId);

    _albums[index] = album.copyWith(
      outfitIds: updatedIds,
      updatedAt: DateTime.now(),
    );

    await _saveToStorage();
    return true;
  }

  /// Actualiza un álbum
  Future<bool> updateAlbum(OutfitAlbum updatedAlbum) async {
    final index = _albums.indexWhere((a) => a.id == updatedAlbum.id);
    if (index != -1) {
      _albums[index] = updatedAlbum.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Elimina un álbum
  Future<bool> deleteAlbum(String id) async {
    final initialLength = _albums.length;
    _albums.removeWhere((a) => a.id == id);
    if (_albums.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Crea álbumes predefinidos por temporada
  Future<void> createDefaultSeasonalAlbums() async {
    final seasons = [
      {'name': 'Outfits Verano', 'season': 'verano', 'desc': 'Looks frescos para el calor'},
      {'name': 'Outfits Invierno', 'season': 'invierno', 'desc': 'Ropa abrigada para el frío'},
      {'name': 'Outfits Primavera', 'season': 'primavera', 'desc': 'Estilos de entretiempo'},
      {'name': 'Outfits Otoño', 'season': 'otoño', 'desc': 'Combinaciones otoñales'},
    ];

    for (final season in seasons) {
      // Verificar si ya existe
      final exists = _albums.any((a) => a.season == season['season']);
      if (!exists) {
        await createAlbum(
          name: season['name']!,
          description: season['desc']!,
          season: season['season'],
        );
      }
    }

    debugPrint('✅ Álbumes por temporada creados');
  }

  /// Busca álbumes por nombre
  List<OutfitAlbum> searchAlbums(String query) {
    final lowerQuery = query.toLowerCase();
    return _albums.where((a) =>
        a.name.toLowerCase().contains(lowerQuery) ||
        a.description.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Obtiene outfits de un álbum (requiere OutfitService para obtener los outfits completos)
  List<Outfit> getOutfitsInAlbum(String albumId, List<Outfit> allOutfits) {
    final album = getAlbumById(albumId);
    if (album == null) return [];

    return allOutfits.where((o) => album.outfitIds.contains(o.id)).toList();
  }

  /// Limpia todos los álbumes
  Future<void> clearAllAlbums() async {
    _albums.clear();
    await _saveToStorage();
  }

  /// Obtiene estadísticas
  Map<String, dynamic> getStats() {
    return {
      'totalAlbums': _albums.length,
      'totalOutfitsInAlbums': _albums.fold<int>(0, (sum, a) => sum + a.outfitCount),
      'seasons': _albums.where((a) => a.season != null).map((a) => a.season).toSet().toList(),
    };
  }

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _albums.map((a) => a.toJson()).toList();
      await prefs.setString(_albumsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving albums: $e');
    }
  }

  /// Carga desde SharedPreferences
  Future<void> _loadAlbums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_albumsKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _albums.clear();
        _albums.addAll(
          jsonList.map((json) => OutfitAlbum.fromJson(json as Map<String, dynamic>)),
        );
        debugPrint('✅ ${_albums.length} álbumes cargados');
      }
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
  }
}
