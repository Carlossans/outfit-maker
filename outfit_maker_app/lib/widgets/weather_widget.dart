import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  final bool showSuggestion;

  const WeatherWidget({
    super.key,
    this.showSuggestion = true,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  double? temperature;
  bool isLoading = true;
  String? error;
  bool useLocation = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final weatherService = WeatherService();

    // Verificar si la API key está configurada
    if (!weatherService.isConfigured) {
      setState(() {
        error = 'API key no configurada\nVer guía en lib/services/weather_setup_guide.md';
        isLoading = false;
      });
      return;
    }

    try {
      if (useLocation) {
        // Usar geolocalización real
        final temp = await weatherService.getCurrentLocationTemperature();
        _handleResult(temp);
      } else {
        // Usar coordenadas de Madrid como ejemplo
        const lat = 40.4168;
        const lon = -3.7038;
        final temp = await weatherService.getTemperature(lat, lon);
        _handleResult(temp);
      }
    } catch (e) {
      setState(() {
        error = 'Error al cargar el clima';
        isLoading = false;
      });
    }
  }

  void _handleResult(double? temp) {
    if (!mounted) return;

    setState(() {
      temperature = temp;
      isLoading = false;
      if (temp == null) {
        error = 'No se pudo obtener el clima\nToca para reintentar';
      }
    });
  }

  Future<void> _enableLocation() async {
    setState(() => useLocation = true);
    await _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildContainer(
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Cargando clima...'),
          ],
        ),
      );
    }

    if (error != null) {
      return GestureDetector(
        onTap: _loadWeather,
        child: _buildContainer(
          color: Colors.grey[200],
          borderColor: Colors.grey[400],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.refresh, size: 16, color: Colors.grey),
            ],
          ),
        ),
      );
    }

    if (temperature == null) {
      return _buildContainer(
        color: Colors.grey[200],
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: Colors.grey),
            SizedBox(width: 8),
            Text('Sin datos', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Temperatura disponible
    final icon = WeatherService.getIconForTemperature(temperature!);
    final color = WeatherService.getColorForTemperature(temperature!);
    final suggestion = widget.showSuggestion
        ? WeatherService.getClothingSuggestionForTemperature(temperature!)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContainer(
          color: color.withAlpha(20),
          borderColor: color.withAlpha(100),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                '${temperature!.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (!useLocation) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.location_on, size: 18),
                  onPressed: _enableLocation,
                  tooltip: 'Usar mi ubicación',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Icon(Icons.location_on, size: 18, color: Colors.green),
              ],
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadWeather,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        if (suggestion != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              suggestion,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContainer({
    required Widget child,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}
