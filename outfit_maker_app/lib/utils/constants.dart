// Constantes de la aplicación

class AppConstants {
  // Nombres de categorías
  static const String categoryTop = 'top';
  static const String categoryBottom = 'bottom';
  static const String categoryHeadwear = 'headwear';
  static const String categoryFootwear = 'footwear';
  static const String categoryNeckwear = 'neckwear';

  // Tallas europeas comunes
  static const List<String> euSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '38', '40', '42', '44', '46'];

  // Temporadas
  static const String seasonSpring = 'primavera';
  static const String seasonSummer = 'verano';
  static const String seasonAutumn = 'otoño';
  static const String seasonWinter = 'invierno';

  // Temperaturas para sugerencias
  static const double tempCold = 10.0;      // Menos de 10°C - ropa de invierno
  static const double tempCool = 18.0;      // 10-18°C - ropa de entretiempo
  static const double tempWarm = 25.0;      // 18-25°C - ropa de primavera/otoño
  static const double tempHot = 30.0;       // Más de 25°C - ropa de verano
}
