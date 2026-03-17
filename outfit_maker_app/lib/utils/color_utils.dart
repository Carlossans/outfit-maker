import 'package:flutter/material.dart';

class ColorUtils {
  /// Convierte un string de color a Color
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convierte un Color a string hexadecimal
  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Obtiene el nombre del color en español
  static String getColorName(Color color) {
    // Colores básicos
    final Map<String, Color> basicColors = {
      'Negro': Colors.black,
      'Blanco': Colors.white,
      'Rojo': Colors.red,
      'Azul': Colors.blue,
      'Verde': Colors.green,
      'Amarillo': Colors.yellow,
      'Naranja': Colors.orange,
      'Morado': Colors.purple,
      'Rosa': Colors.pink,
      'Gris': Colors.grey,
      'Marrón': Colors.brown,
      'Cyan': Colors.cyan,
    };

    // Encontrar el color más cercano
    String closestName = 'Desconocido';
    double minDistance = double.infinity;

    basicColors.forEach((name, basicColor) {
      final distance = _colorDistance(color, basicColor);
      if (distance < minDistance) {
        minDistance = distance;
        closestName = name;
      }
    });

    return closestName;
  }

  /// Calcula la distancia entre dos colores
  static double _colorDistance(Color a, Color b) {
    final dr = ((a.r - b.r) * 255).abs();
    final dg = ((a.g - b.g) * 255).abs();
    final db = ((a.b - b.b) * 255).abs();
    return dr + dg + db;
  }

  /// Determina si un color es claro u oscuro
  static bool isLightColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.light;
  }

  /// Obtiene el color de texto apropiado para un fondo
  static Color getTextColorForBackground(Color background) {
    return isLightColor(background) ? Colors.black : Colors.white;
  }

  /// Categoriza colores para matching de outfits
  static String getColorCategory(Color color) {
    final hue = HSLColor.fromColor(color).hue;

    if (color == Colors.black || color == Colors.white || color == Colors.grey) {
      return 'neutral';
    }
    if (hue >= 0 && hue < 30) return 'warm';      // Rojos, naranjas
    if (hue >= 30 && hue < 90) return 'warm';     // Amarillos
    if (hue >= 90 && hue < 150) return 'cool';     // Verdes
    if (hue >= 150 && hue < 270) return 'cool';    // Cyan, azules
    if (hue >= 270 && hue < 330) return 'cool';    // Morados
    return 'warm'; // Rojos/rosas
  }

  /// Sugiere colores complementarios
  static List<Color> getComplementaryColors(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final complementaryHue = (hsl.hue + 180) % 360;
    final analogousHue1 = (hsl.hue + 30) % 360;
    final analogousHue2 = (hsl.hue - 30 + 360) % 360;

    return [
      HSLColor.fromAHSL(1, complementaryHue, hsl.saturation, hsl.lightness).toColor(),
      HSLColor.fromAHSL(1, analogousHue1, hsl.saturation, hsl.lightness).toColor(),
      HSLColor.fromAHSL(1, analogousHue2, hsl.saturation, hsl.lightness).toColor(),
    ];
  }
}
