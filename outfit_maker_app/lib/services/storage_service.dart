import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de almacenamiento para datos persistentes
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// Guarda un string
  Future<bool> setString(String key, String value) async {
    _checkInitialized();
    return await _prefs!.setString(key, value);
  }

  /// Obtiene un string
  String? getString(String key) {
    _checkInitialized();
    return _prefs!.getString(key);
  }

  /// Guarda un entero
  Future<bool> setInt(String key, int value) async {
    _checkInitialized();
    return await _prefs!.setInt(key, value);
  }

  /// Obtiene un entero
  int? getInt(String key) {
    _checkInitialized();
    return _prefs!.getInt(key);
  }

  /// Guarda un booleano
  Future<bool> setBool(String key, bool value) async {
    _checkInitialized();
    return await _prefs!.setBool(key, value);
  }

  /// Obtiene un booleano
  bool? getBool(String key) {
    _checkInitialized();
    return _prefs!.getBool(key);
  }

  /// Guarda un objeto JSON
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await setString(key, jsonEncode(value));
  }

  /// Obtiene un objeto JSON
  Map<String, dynamic>? getJson(String key) {
    final string = getString(key);
    if (string == null) return null;
    try {
      return jsonDecode(string) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return null;
    }
  }

  /// Elimina una clave
  Future<bool> remove(String key) async {
    _checkInitialized();
    return await _prefs!.remove(key);
  }

  /// Limpia todo el almacenamiento
  Future<bool> clear() async {
    _checkInitialized();
    return await _prefs!.clear();
  }

  /// Obtiene el directorio de documentos de la app
  Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Obtiene el directorio temporal
  Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Guarda un archivo en el directorio de documentos
  Future<File> saveFile(String fileName, List<int> bytes) async {
    final dir = await getDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    return await file.writeAsBytes(bytes);
  }

  /// Verifica si existe un archivo
  Future<bool> fileExists(String fileName) async {
    final dir = await getDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    return await file.exists();
  }

  /// Elimina un archivo
  Future<void> deleteFile(String fileName) async {
    final dir = await getDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('StorageService not initialized. Call initialize() first.');
    }
  }

  bool get isInitialized => _isInitialized;
}
