import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outfit.dart';

/// Representa un outfit planificado para un día específico
class PlannedOutfit {
  final String id;
  final String outfitId;
  final DateTime date;
  final String? notes;
  final bool isCompleted;

  const PlannedOutfit({
    required this.id,
    required this.outfitId,
    required this.date,
    this.notes,
    this.isCompleted = false,
  });

  PlannedOutfit copyWith({
    String? id,
    String? outfitId,
    DateTime? date,
    String? notes,
    bool? isCompleted,
  }) {
    return PlannedOutfit(
      id: id ?? this.id,
      outfitId: outfitId ?? this.outfitId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outfitId': outfitId,
      'date': date.toIso8601String(),
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  factory PlannedOutfit.fromJson(Map<String, dynamic> json) {
    return PlannedOutfit(
      id: json['id'] as String,
      outfitId: json['outfitId'] as String,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// Servicio para planificar outfits en el calendario
class CalendarOutfitService {
  static const String _plannedOutfitsKey = 'planned_outfits';
  static final CalendarOutfitService _instance = CalendarOutfitService._internal();
  factory CalendarOutfitService() => _instance;
  CalendarOutfitService._internal();

  final List<PlannedOutfit> _plannedOutfits = [];
  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadPlannedOutfits();
    _isInitialized = true;
  }

  /// Planifica un outfit para una fecha específica
  Future<PlannedOutfit> planOutfit({
    required String outfitId,
    required DateTime date,
    String? notes,
  }) async {
    // Eliminar planificación previa para esta fecha si existe
    _plannedOutfits.removeWhere((p) =>
        p.date.year == date.year &&
        p.date.month == date.month &&
        p.date.day == date.day);

    final planned = PlannedOutfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      outfitId: outfitId,
      date: date,
      notes: notes,
    );

    _plannedOutfits.add(planned);
    await _saveToStorage();

    debugPrint('✅ Outfit planificado para ${date.toIso8601String()}');
    return planned;
  }

  /// Obtiene el outfit planificado para una fecha específica
  PlannedOutfit? getPlannedOutfitForDate(DateTime date) {
    try {
      return _plannedOutfits.firstWhere((p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el outfit completo planificado para una fecha
  Outfit? getOutfitForDate(DateTime date, List<Outfit> allOutfits) {
    final planned = getPlannedOutfitForDate(date);
    if (planned == null) return null;

    try {
      return allOutfits.firstWhere((o) => o.id == planned.outfitId);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene todas las planificaciones para un rango de fechas
  List<PlannedOutfit> getPlannedOutfitsForRange(DateTime start, DateTime end) {
    return _plannedOutfits.where((p) =>
        p.date.isAfter(start.subtract(const Duration(days: 1))) &&
        p.date.isBefore(end.add(const Duration(days: 1)))).toList();
  }

  /// Obtiene todas las planificaciones
  List<PlannedOutfit> getAllPlannedOutfits() {
    return List.unmodifiable(_plannedOutfits);
  }

  /// Elimina una planificación
  Future<bool> removePlannedOutfit(String id) async {
    final initialLength = _plannedOutfits.length;
    _plannedOutfits.removeWhere((p) => p.id == id);
    if (_plannedOutfits.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Elimina la planificación de una fecha específica
  Future<bool> removePlannedOutfitForDate(DateTime date) async {
    final initialLength = _plannedOutfits.length;
    _plannedOutfits.removeWhere((p) =>
        p.date.year == date.year &&
        p.date.month == date.month &&
        p.date.day == date.day);
    if (_plannedOutfits.length < initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Marca un outfit como usado/completado
  Future<bool> markAsCompleted(String id, {bool completed = true}) async {
    final index = _plannedOutfits.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plannedOutfits[index] = _plannedOutfits[index].copyWith(isCompleted: completed);
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Actualiza las notas de una planificación
  Future<bool> updateNotes(String id, String? notes) async {
    final index = _plannedOutfits.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plannedOutfits[index] = _plannedOutfits[index].copyWith(notes: notes);
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Obtiene estadísticas de uso
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final completed = _plannedOutfits.where((p) => p.isCompleted).length;
    final upcoming = _plannedOutfits.where((p) =>
        p.date.isAfter(today.subtract(const Duration(days: 1)))).length;
    final past = _plannedOutfits.where((p) => p.date.isBefore(today)).length;

    return {
      'totalPlanned': _plannedOutfits.length,
      'completed': completed,
      'upcoming': upcoming,
      'past': past,
    };
  }

  /// Planifica outfits automáticamente para la semana
  Future<List<PlannedOutfit>> planWeekAutomatically(
    List<Outfit> availableOutfits, {
    DateTime? startDate,
  }) async {
    final start = startDate ?? DateTime.now();
    final planned = <PlannedOutfit>[];

    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));

      // Seleccionar outfit aleatorio (en el futuro se puede usar IA)
      if (availableOutfits.isNotEmpty) {
        final outfit = availableOutfits[i % availableOutfits.length];

        // Verificar si ya hay planificación para esta fecha
        final existing = getPlannedOutfitForDate(date);
        if (existing == null) {
          final plannedOutfit = await planOutfit(
            outfitId: outfit.id,
            date: date,
            notes: 'Planificado automáticamente',
          );
          planned.add(plannedOutfit);
        }
      }
    }

    return planned;
  }

  /// Limpia todas las planificaciones
  Future<void> clearAllPlannedOutfits() async {
    _plannedOutfits.clear();
    await _saveToStorage();
  }

  /// Guarda en SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _plannedOutfits.map((p) => p.toJson()).toList();
      await prefs.setString(_plannedOutfitsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving planned outfits: $e');
    }
  }

  /// Carga desde SharedPreferences
  Future<void> _loadPlannedOutfits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_plannedOutfitsKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _plannedOutfits.clear();
        _plannedOutfits.addAll(
          jsonList.map((json) => PlannedOutfit.fromJson(json as Map<String, dynamic>)),
        );
        debugPrint('✅ ${_plannedOutfits.length} outfits planificados cargados');
      }
    } catch (e) {
      debugPrint('Error loading planned outfits: $e');
    }
  }
}
