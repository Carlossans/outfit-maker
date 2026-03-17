# Configuración del Servicio de Clima

Para que la función de temperatura funcione correctamente, necesitas configurar una API key de OpenWeatherMap.

## Pasos para configurar:

### 1. Obtener API Key (GRATIS)

1. Ve a https://openweathermap.org/
2. Crea una cuenta gratuita
3. Ve a "My API Keys" en tu perfil
4. Copia la API key (tiene este formato: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

### 2. Configurar en la app

Abre el archivo `lib/services/weather_service.dart` y reemplaza:

```dart
final String apiKey = "TU_API_KEY";
```

Por tu API key real:

```dart
final String apiKey = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"; // Tu key aquí
```

### 3. Alternativa: Variables de entorno (Recomendado)

Para mayor seguridad, puedes usar variables de entorno:

1. Añade al archivo `android/app/build.gradle`:
```gradle
def dartEnvironmentVariables = [
    'OPENWEATHER_API_KEY',
]
```

2. Crea un archivo `.env` en la raíz del proyecto:
```
OPENWEATHER_API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

3. Usa el paquete `flutter_dotenv` para leer la variable.

## Funcionalidades disponibles:

- **Temperatura actual**: Muestra la temperatura en grados Celsius
- **Sugerencias de outfit**: La app sugerirá ropa según la temperatura:
  - **Menos de 10°C**: Ropa de invierno (abrigos, sudaderas)
  - **10-18°C**: Ropa de entretiempo
  - **18-25°C**: Ropa de primavera/otoño
  - **Más de 25°C**: Ropa de verano (camisetas, polos)

## Uso de geolocalización real:

Para obtener el clima de tu ubicación actual:

1. Añade el permiso en `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

2. El WeatherWidget usará automáticamente tu ubicación actual.

## Notas:

- La API gratuita permite hasta 60 llamadas/minuto
- Los datos se actualizan cada 10 minutos como máximo
- Si ves "Error al cargar el clima", toca el widget para reintentar
