import 'dart:math';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../models/user_measurements.dart';
import '../utils/constants.dart';
import '../utils/color_utils.dart';

/// Servicio de IA avanzado para sugerir outfits
class OutfitAI {
  final Random _random = Random();

  /// Sugiere un outfit completo basado en múltiples criterios
  List<ClothingItem> suggestOutfit(
    List<ClothingItem> clothes, {
    double? temperature,
    String? occasion,
    UserMeasurements? userMeasurements,
    List<Color>? preferredColors,
    bool useColorMatching = true,
  }) {
    if (clothes.isEmpty) return [];

    // Filtrar por tipo
    final tops = clothes.where((c) => c.type == ClothingType.top).toList();
    final bottoms = clothes.where((c) => c.type == ClothingType.bottom).toList();
    final footwear = clothes.where((c) => c.type == ClothingType.footwear).toList();
    final headwear = clothes.where((c) => c.type == ClothingType.headwear).toList();
    final neckwear = clothes.where((c) => c.type == ClothingType.neckwear).toList();

    final outfit = <ClothingItem>[];

    // Seleccionar prenda superior según temperatura y medidas
    if (tops.isNotEmpty) {
      final selectedTop = _selectBestTop(
        tops,
        temperature: temperature,
        userMeasurements: userMeasurements,
      );
      outfit.add(selectedTop);
    }

    // Seleccionar prenda inferior que combine
    if (bottoms.isNotEmpty) {
      final selectedBottom = useColorMatching && outfit.isNotEmpty
          ? _selectBestMatchingBottom(bottoms, outfit.first, temperature: temperature)
          : _selectByTemperature(bottoms, temperature);
      outfit.add(selectedBottom);
    }

    // Seleccionar calzado que combine
    if (footwear.isNotEmpty) {
      final selectedFootwear = useColorMatching && outfit.isNotEmpty
          ? _selectBestMatchingFootwear(footwear, outfit, temperature: temperature)
          : _selectByTemperature(footwear, temperature);
      outfit.add(selectedFootwear);
    }

    // Opcional: accesorios basados en temperatura y estilo
    if (headwear.isNotEmpty && _shouldAddAccessory(temperature, occasion)) {
      outfit.add(_selectAccessory(headwear, outfit));
    }

    if (neckwear.isNotEmpty && _shouldAddNeckwear(temperature, occasion)) {
      outfit.add(_selectAccessory(neckwear, outfit));
    }

    return outfit;
  }

  /// Sugiere outfits inteligentes para una semana completa
  List<List<ClothingItem>> suggestWeeklyOutfits(
    List<ClothingItem> clothes, {
    List<double>? temperatures,
    UserMeasurements? userMeasurements,
  }) {
    final weeklyOutfits = <List<ClothingItem>>[];
    final usedItems = <String>{}; // Track para evitar repetición

    for (int i = 0; i < 7; i++) {
      final temp = temperatures != null && i < temperatures.length
          ? temperatures[i]
          : null;

      // Filtrar prendas no usadas recientemente
      var availableClothes = clothes.where((c) => !usedItems.contains(c.id)).toList();
      if (availableClothes.length < 3) {
        availableClothes = clothes; // Reset si quedan pocas
        usedItems.clear();
      }

      final outfit = suggestOutfit(
        availableClothes,
        temperature: temp,
        userMeasurements: userMeasurements,
      );

      // Marcar items como usados
      for (final item in outfit) {
        usedItems.add(item.id);
      }

      weeklyOutfits.add(outfit);
    }

    return weeklyOutfits;
  }

  /// Sugiere outfits basados en la temperatura actual
  List<ClothingItem> suggestOutfitForTemperature(
    List<ClothingItem> clothes,
    double temperature, {
    UserMeasurements? userMeasurements,
  }) {
    return suggestOutfit(
      clothes,
      temperature: temperature,
      userMeasurements: userMeasurements,
    );
  }

  /// Selecciona la mejor prenda superior
  ClothingItem _selectBestTop(
    List<ClothingItem> tops, {
    double? temperature,
    UserMeasurements? userMeasurements,
    List<Color>? preferredColors,
  }) {
    // Puntuar cada prenda
    final scoredTops = tops.map((top) {
      double score = 50; // Base

      // Puntuar por temperatura
      if (temperature != null) {
        score += _scoreForTemperature(top, temperature);
      }

      // Puntuar por ajuste a medidas
      if (userMeasurements != null) {
        score += _scoreForMeasurements(top, userMeasurements);
      }

      // Puntuar por color preferido
      if (preferredColors != null && preferredColors.isNotEmpty) {
        score += _scoreForColorPreference(top, preferredColors);
      }

      return MapEntry(top, score);
    }).toList();

    // Ordenar por puntuación y seleccionar de los mejores
    scoredTops.sort((a, b) => b.value.compareTo(a.value));

    // Seleccionar aleatoriamente de los top 3 (o menos si no hay tantos)
    final topCount = min(3, scoredTops.length);
    final selected = scoredTops[_random.nextInt(topCount)];
    return selected.key;
  }

  /// Selecciona la mejor prenda inferior que combine
  ClothingItem _selectBestMatchingBottom(
    List<ClothingItem> bottoms,
    ClothingItem top, {
    double? temperature,
    bool useColorMatching = true,
  }) {
    final scoredBottoms = bottoms.map((bottom) {
      double score = 50;

      // Puntuar por temperatura
      if (temperature != null) {
        score += _scoreForTemperature(bottom, temperature);
      }

      // Puntuar por compatibilidad de talla
      if (_areSizesCompatible(top.size, bottom.size)) {
        score += 15;
      }

      // Puntuar por categoría complementaria
      if (_areCategoriesComplementary(top.category, bottom.category)) {
        score += 10;
      }

      // Puntuar por matching de colores
      if (useColorMatching) {
        score += _scoreForColorMatching(top, bottom);
      }

      return MapEntry(bottom, score);
    }).toList();

    scoredBottoms.sort((a, b) => b.value.compareTo(a.value));
    final topCount = min(3, scoredBottoms.length);
    return scoredBottoms[_random.nextInt(topCount)].key;
  }

  /// Selecciona el mejor calzado que combine
  ClothingItem _selectBestMatchingFootwear(
    List<ClothingItem> footwear,
    List<ClothingItem> currentOutfit, {
    double? temperature,
    bool useColorMatching = true,
  }) {
    final scoredFootwear = footwear.map((shoe) {
      double score = 50;

      // Puntuar por temperatura
      if (temperature != null) {
        score += _scoreForTemperature(shoe, temperature);
      }

      // Puntuar por compatibilidad con el resto del outfit
      for (final item in currentOutfit) {
        if (_areSizesCompatible(item.size, shoe.size)) {
          score += 5;
        }

        // Puntuar por matching de colores con cada prenda
        if (useColorMatching) {
          score += _scoreForColorMatching(item, shoe) ~/ 2;
        }
      }

      return MapEntry(shoe, score);
    }).toList();

    scoredFootwear.sort((a, b) => b.value.compareTo(a.value));
    final topCount = min(2, scoredFootwear.length);
    return scoredFootwear[_random.nextInt(topCount)].key;
  }

  /// Puntúa una prenda según la temperatura
  double _scoreForTemperature(ClothingItem item, double temperature) {
    final name = item.name.toLowerCase();

    // Ropa de frío
    if (temperature < AppConstants.tempCold) {
      if (name.contains('abrigo')) return 30;
      if (name.contains('chaqueta')) return 25;
      if (name.contains('sudadera')) return 20;
      if (name.contains('jersey')) return 20;
      if (name.contains('camiseta')) return -20; // Penalizar camisetas en frío
    }

    // Ropa de entretiempo
    if (temperature >= AppConstants.tempCold && temperature < AppConstants.tempWarm) {
      if (name.contains('sudadera')) return 15;
      if (name.contains('camisa')) return 15;
      if (name.contains('chaqueta')) return 10;
    }

    // Ropa de calor
    if (temperature >= AppConstants.tempWarm) {
      if (name.contains('camiseta')) return 25;
      if (name.contains('camisa')) return 20;
      if (name.contains('short')) return 20;
      if (name.contains('falda')) return 15;
      if (name.contains('abrigo')) return -30; // Penalizar abrigos en calor
      if (name.contains('sudadera')) return -20;
    }

    return 0;
  }

  /// Puntúa una prenda según las medidas del usuario
  double _scoreForMeasurements(ClothingItem item, UserMeasurements measurements) {
    // Convertir talla de prenda a medida aproximada
    final size = item.size.toUpperCase();

    // Tallas europeas comunes
    final sizeMapping = {
      'XS': {'chest': 86, 'waist': 70},
      'S': {'chest': 92, 'waist': 76},
      'M': {'chest': 98, 'waist': 82},
      'L': {'chest': 106, 'waist': 90},
      'XL': {'chest': 114, 'waist': 98},
      'XXL': {'chest': 122, 'waist': 106},
    };

    // Tallas numéricas europeas (aproximadas)
    final numericMapping = {
      '36': 'XS',
      '38': 'S',
      '40': 'M',
      '42': 'L',
      '44': 'XL',
      '46': 'XXL',
    };

    var mappedSize = size;
    if (numericMapping.containsKey(size)) {
      mappedSize = numericMapping[size]!;
    }

    if (sizeMapping.containsKey(mappedSize)) {
      final expectedChest = sizeMapping[mappedSize]!['chest']!;
      final userChest = measurements.chest ?? measurements.shoulders * 2;

      // Calcular diferencia
      final diff = (userChest - expectedChest).abs();

      if (diff < 5) return 20; // Ajuste perfecto
      if (diff < 10) return 10; // Buen ajuste
      if (diff < 15) return 0; // Ajuste aceptable
      return -10; // Mal ajuste
    }

    return 0;
  }

  /// Verifica si dos tallas son compatibles
  bool _areSizesCompatible(String sizeA, String sizeB) {
    // Normalizar tallas
    final normalizedA = _normalizeSize(sizeA);
    final normalizedB = _normalizeSize(sizeB);

    // Tallas idénticas o adyacentes son compatibles
    if (normalizedA == normalizedB) return true;

    final sizeOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
    final indexA = sizeOrder.indexOf(normalizedA);
    final indexB = sizeOrder.indexOf(normalizedB);

    if (indexA == -1 || indexB == -1) return true; // Si no reconocemos, asumimos compatible

    // Permitir una talla de diferencia
    return (indexA - indexB).abs() <= 1;
  }

  /// Normaliza una talla a formato estándar
  String _normalizeSize(String size) {
    final upper = size.toUpperCase().trim();

    // Mapear tallas numéricas europeas
    final euMapping = {
      '36': 'XS',
      '38': 'S',
      '40': 'M',
      '42': 'L',
      '44': 'XL',
      '46': 'XXL',
      '48': 'XXL',
    };

    if (euMapping.containsKey(upper)) {
      return euMapping[upper]!;
    }

    return upper;
  }

  /// Verifica si dos categorías son complementarias
  bool _areCategoriesComplementary(String catA, String catB) {
    final complementary = {
      'formal': ['formal', 'elegante'],
      'casual': ['casual', 'sport'],
      'sport': ['sport', 'casual'],
      'elegante': ['elegante', 'formal'],
    };

    final a = catA.toLowerCase();
    final b = catB.toLowerCase();

    if (a == b) return true;
    return complementary[a]?.contains(b) ?? false;
  }

  /// Puntuación por matching de colores entre dos prendas (0-30 puntos)
  int _scoreForColorMatching(ClothingItem a, ClothingItem b) {
    // Extraer colores de las prendas
    final colorA = _extractColorFromClothing(a);
    final colorB = _extractColorFromClothing(b);

    if (colorA == null || colorB == null) return 0;

    // Colores neutrales combinan con todo
    final neutralColors = [Colors.black, Colors.white, Colors.grey, Colors.brown.shade100];
    final isANeutral = neutralColors.any((c) => _colorsSimilar(c, colorA));
    final isBNeutral = neutralColors.any((c) => _colorsSimilar(c, colorB));

    if (isANeutral || isBNeutral) return 20;

    // Categorías de color
    final categoryA = ColorUtils.getColorCategory(colorA);
    final categoryB = ColorUtils.getColorCategory(colorB);

    // Colores de misma categoría combinan bien
    if (categoryA == categoryB) return 25;

    // Colores complementarios
    final complementaries = ColorUtils.getComplementaryColors(colorA);
    if (complementaries.any((c) => _colorsSimilar(c, colorB))) return 30;

    // Colores análogos (cerca en el círculo cromático)
    if (_areAnalogousColors(colorA, colorB)) return 20;

    return 5; // Matching débil
  }

  /// Puntuación por preferencia de color del usuario (0-20 puntos)
  int _scoreForColorPreference(ClothingItem item, List<Color> preferredColors) {
    final itemColor = _extractColorFromClothing(item);
    if (itemColor == null) return 0;

    for (final preferredColor in preferredColors) {
      if (_colorsSimilar(itemColor, preferredColor)) {
        return 20; // Coincidencia directa
      }
    }

    // Colores análogos a los preferidos
    for (final preferredColor in preferredColors) {
      if (_areAnalogousColors(itemColor, preferredColor)) {
        return 10;
      }
    }

    return 0;
  }

  /// Extrae el color dominante de una prenda
  Color? _extractColorFromClothing(ClothingItem item) {
    // Si la prenda tiene color en el nombre, usarlo
    final colorNames = {
      'negro': Colors.black,
      'negra': Colors.black,
      'blanco': Colors.white,
      'blanca': Colors.white,
      'rojo': Colors.red,
      'roja': Colors.red,
      'azul': Colors.blue,
      'verde': Colors.green,
      'amarillo': Colors.yellow,
      'amarilla': Colors.yellow,
      'naranja': Colors.orange,
      'morado': Colors.purple,
      'morada': Colors.purple,
      'rosa': Colors.pink,
      'gris': Colors.grey,
      'marrón': Colors.brown,
      'beige': Colors.brown.shade100,
    };

    final lowerName = item.name.toLowerCase();
    for (final entry in colorNames.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }

    // Si tiene categoría con color, usarlo
    final lowerCategory = item.category.toLowerCase();
    for (final entry in colorNames.entries) {
      if (lowerCategory.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Verifica si dos colores son similares
  bool _colorsSimilar(Color a, Color b) {
    final dr = ((a.r - b.r) * 255).abs();
    final dg = ((a.g - b.g) * 255).abs();
    final db = ((a.b - b.b) * 255).abs();
    final distance = dr + dg + db;
    return distance < 100; // Umbral de similitud
  }

  /// Verifica si dos colores son análogos (cerca en círculo cromático)
  bool _areAnalogousColors(Color a, Color b) {
    final hueA = HSLColor.fromColor(a).hue;
    final hueB = HSLColor.fromColor(b).hue;

    final diff = (hueA - hueB).abs();
    return diff < 45 || diff > 315; // Dentro de 45 grados
  }

  /// Decide si debe añadir un accesorio
  bool _shouldAddAccessory(double? temperature, String? occasion) {
    if (occasion == 'formal') return _random.nextDouble() < 0.7;
    if (occasion == 'casual') return _random.nextDouble() < 0.3;
    if (temperature != null && temperature > 25) return _random.nextDouble() < 0.5; // Gorras en verano
    return _random.nextBool();
  }

  /// Decide si debe añadir accesorio de cuello
  bool _shouldAddNeckwear(double? temperature, String? occasion) {
    if (occasion == 'formal') return _random.nextDouble() < 0.6;
    if (temperature != null && temperature < 15) return _random.nextDouble() < 0.8; // Bufandas en invierno
    return _random.nextDouble() < 0.2;
  }

  /// Selecciona un accesorio que combine con el outfit
  ClothingItem _selectAccessory(List<ClothingItem> accessories, List<ClothingItem> outfit) {
    // Por ahora seleccionamos aleatoriamente
    // En el futuro se puede analizar colores
    return accessories[_random.nextInt(accessories.length)];
  }

  /// Selecciona por temperatura (método original mejorado)
  ClothingItem _selectByTemperature(
    List<ClothingItem> items,
    double? temperature,
  ) {
    if (temperature == null) {
      return items[_random.nextInt(items.length)];
    }

    final scored = items.map((item) {
      return MapEntry(item, _scoreForTemperature(item, temperature));
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Seleccionar de los mejores
    final topCount = min(3, scored.length);
    return scored[_random.nextInt(topCount)].key;
  }

  /// Sugiere prendas que combinan con una prenda base
  List<ClothingItem> suggestMatchingItems(
    ClothingItem baseItem,
    List<ClothingItem> availableClothes, {
    double? temperature,
  }) {
    return availableClothes.where((item) {
      if (item.id == baseItem.id) return false;
      if (!_areTypesComplementary(baseItem.type, item.type)) return false;

      // Verificar compatibilidad de tallas
      if (!_areSizesCompatible(baseItem.size, item.size)) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        // Ordenar por puntuación de compatibilidad
        final scoreA = calculateCompatibility(baseItem, a, temperature: temperature);
        final scoreB = calculateCompatibility(baseItem, b, temperature: temperature);
        return scoreB.compareTo(scoreA);
      });
  }

  /// Verifica si dos tipos de prenda son complementarios
  bool _areTypesComplementary(ClothingType a, ClothingType b) {
    final complementary = {
      ClothingType.top: [ClothingType.bottom, ClothingType.footwear, ClothingType.neckwear],
      ClothingType.bottom: [ClothingType.top, ClothingType.footwear],
      ClothingType.footwear: [ClothingType.top, ClothingType.bottom],
      ClothingType.headwear: [ClothingType.top, ClothingType.bottom],
      ClothingType.neckwear: [ClothingType.top],
    };

    return complementary[a]?.contains(b) ?? false;
  }

  /// Calcula un score de compatibilidad entre dos prendas (0-100)
  int calculateCompatibility(
    ClothingItem a,
    ClothingItem b, {
    double? temperature,
  }) {
    int score = 50; // Base

    // Tipos complementarios
    if (_areTypesComplementary(a.type, b.type)) {
      score += 20;
    }

    // Categorías similares
    if (a.category == b.category) {
      score += 15;
    }

    // Tallas compatibles
    if (_areSizesCompatible(a.size, b.size)) {
      score += 15;
    }

    // Temperatura apropiada
    if (temperature != null) {
      final tempScoreA = _scoreForTemperature(a, temperature);
      final tempScoreB = _scoreForTemperature(b, temperature);
      if (tempScoreA > 0 && tempScoreB > 0) {
        score += 10;
      }
    }

    return score.clamp(0, 100);
  }

  /// Genera una explicación de por qué se sugiere un outfit
  String generateOutfitExplanation(
    List<ClothingItem> outfit, {
    double? temperature,
    UserMeasurements? measurements,
  }) {
    if (outfit.isEmpty) return 'No se pudo generar un outfit';

    final parts = <String>[];

    // Explicar por temperatura
    if (temperature != null) {
      if (temperature < 10) {
        parts.add('Abrigado para el frío (${temperature.toStringAsFixed(0)}°C)');
      } else if (temperature < 20) {
        parts.add('Cómodo para el entretiempo (${temperature.toStringAsFixed(0)}°C)');
      } else {
        parts.add('Ligero para el calor (${temperature.toStringAsFixed(0)}°C)');
      }
    }

    // Explicar por tallas
    if (measurements != null && outfit.length >= 2) {
      final allCompatible = outfit.every((item) {
        return outfit.every((other) =>
            item.id == other.id || _areSizesCompatible(item.size, other.size));
      });

      if (allCompatible) {
        parts.add('Tallas compatibles con tus medidas');
      }
    }

    // Explicar por combinación
    if (outfit.length >= 2) {
      parts.add('${outfit.length} prendas combinadas');
    }

    return parts.join(' • ');
  }
}
