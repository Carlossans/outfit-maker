import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Servicio de clima que obtiene datos de OpenWeatherMap
class WeatherService {
  // ============================================
  // CONFIGURACIÓN - REEMPLAZA CON TU API KEY
  // Obtén tu key gratuita en: https://openweathermap.org/
  // ============================================
  final String apiKey = "297e200ce54dba7c1f447949cc2ebc19";

  /// Verifica si la API key está configurada
  bool get isConfigured => apiKey != "297e200ce54dba7c1f447949cc2ebc19" && apiKey.isNotEmpty;

  /// Obtiene la temperatura actual usando geolocalización
  Future<double?> getCurrentLocationTemperature() async {
    if (!isConfigured) {
      debugPrint('❌ Weather API key not configured');
      return null;
    }

    try {
      // Verificar permisos de ubicación
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ Location permission denied');
        return null;
      }

      // Obtener posición actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      return await getTemperature(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// Obtiene la temperatura actual en grados Celsius para coordenadas específicas
  Future<double?> getTemperature(double lat, double lon) async {
    if (!isConfigured) {
      debugPrint('❌ Weather API key not configured');
      return null;
    }

    try {
      final url = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'appid': apiKey,
          'units': 'metric',
          'lang': 'es',
        },
      );

      debugPrint('🌤️ Fetching weather for: $lat, $lon');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final temp = data['main']?['temp'];
        final description = data['weather']?[0]?['description'] ?? 'Unknown';

        debugPrint('✅ Weather: $temp°C - $description');

        return temp != null ? (temp as num).toDouble() : null;
      } else if (response.statusCode == 401) {
        debugPrint('❌ Invalid API key. Please check your OpenWeatherMap API key.');
        return null;
      } else {
        debugPrint('❌ Weather API error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting temperature: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  /// Obtiene información completa del clima
  Future<WeatherData?> getWeatherData(double lat, double lon) async {
    if (!isConfigured) {
      debugPrint('❌ Weather API key not configured');
      return null;
    }

    try {
      final url = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'appid': apiKey,
          'units': 'metric',
          'lang': 'es',
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherData.fromJson(data);
      } else {
        debugPrint('❌ Weather API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting weather: $e');
      return null;
    }
  }

  /// Obtiene el clima usando geolocalización actual
  Future<WeatherData?> getCurrentLocationWeather() async {
    if (!isConfigured) return null;

    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      return await getWeatherData(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  /// Verifica y solicita permisos de ubicación
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission denied forever');
      return false;
    }

    return true;
  }

  /// Sugiere el tipo de ropa según la temperatura
  static String getClothingSuggestionForTemperature(double temp) {
    if (temp < 5) {
      return '❄️ Muy frío - Usa abrigo grueso, bufanda y guantes';
    } else if (temp < 10) {
      return '🧥 Frío - Usa chaqueta o sudadera';
    } else if (temp < 18) {
      return '🧣 Fresco - Ropa de entretiempo recomendada';
    } else if (temp < 25) {
      return '👕 Agradable - Camiseta o camisa cómoda';
    } else if (temp < 30) {
      return '☀️ Calor - Ropa ligera y fresca';
    } else {
      return '🔥 Mucho calor - Ropa muy ligera, protege del sol';
    }
  }

  /// Obtiene el icono apropiado según la temperatura
  static IconData getIconForTemperature(double temp) {
    if (temp < 5) return Icons.ac_unit; // Nieve
    if (temp < 15) return Icons.cloud; // Nublado
    if (temp < 25) return Icons.wb_sunny; // Soleado
    return Icons.wb_sunny_outlined; // Muy soleado
  }

  /// Obtiene el color apropiado según la temperatura
  static Color getColorForTemperature(double temp) {
    if (temp < 5) return Colors.blue.shade700;
    if (temp < 15) return Colors.blue.shade400;
    if (temp < 25) return Colors.orange;
    return Colors.red;
  }
}

/// Modelo de datos del clima
class WeatherData {
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final String description;
  final String icon;
  final String cityName;
  final String mainCondition;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.cityName,
    required this.mainCondition,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      tempMin: (json['main']['temp_min'] as num).toDouble(),
      tempMax: (json['main']['temp_max'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      cityName: json['name'] as String,
      mainCondition: json['weather'][0]['main'] as String,
    );
  }

  /// URL del icono del clima
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  @override
  String toString() {
    return 'WeatherData($cityName: ${temperature.toStringAsFixed(1)}°C, $description)';
  }
}
