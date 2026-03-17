# 🔧 Configuración de Desarrollo - Outfit Maker v2.0

## Estructura del Proyecto

```
outfi_maker_app/
├── lib/
│   ├── ai/
│   │   └── outfit_ai.dart
│   ├── models/
│   │   ├── clothing_item.dart
│   │   ├── multi_angle_avatar.dart
│   │   ├── multi_angle_clothing.dart
│   │   ├── outfit_album.dart
│   │   ├── outfit.dart
│   │   └── user_measurements.dart
│   ├── screens/
│   │   ├── add_clothing_screen.dart
│   │   ├── advanced_multi_angle_capture_screen.dart ⭐ NUEVO
│   │   ├── avatar_screen.dart
│   │   ├── avatar_setup_screen.dart (MODIFICADO)
│   │   ├── calendar_screen.dart
│   │   ├── clothing_multi_angle_capture_screen.dart
│   │   ├── home_screen.dart (MODIFICADO)
│   │   ├── multi_angle_capture_screen.dart
│   │   ├── outfit_builder_screen.dart (MODIFICADO)
│   │   ├── saved_outfits_screen.dart
│   │   └── wardrobe_screen.dart
│   ├── services/
│   │   ├── advanced_ai_generation_service.dart
│   │   ├── advanced_scanner_capture_service.dart ⭐ NUEVO
│   │   ├── ai_image_generation_service.dart
│   │   ├── album_service.dart
│   │   ├── avatar_storage_service.dart
│   │   ├── barcode_service.dart
│   │   ├── bg_removal_service.dart
│   │   ├── body_segmentation.dart
│   │   ├── calendar_outfit_service.dart
│   │   ├── clothing_capture_service.dart
│   │   ├── clothing_warping.dart
│   │   ├── enhanced_ai_generation_service.dart
│   │   ├── firebase_service.dart
│   │   ├── full_body_validation_service.dart
│   │   ├── image_download_service.dart
│   │   ├── image_service.dart
│   │   ├── improved_clothing_warping.dart
│   │   ├── improved_outfit_generation_service.dart ⭐ NUEVO
│   │   ├── multi_angle_capture_service.dart
│   │   ├── outfit_service.dart
│   │   ├── realistic_outfit_generation_service.dart
│   │   ├── storage_service.dart
│   │   ├── wardrobe_service.dart
│   │   └── weather_service.dart
│   ├── utils/
│   │   ├── color_utils.dart
│   │   ├── constants.dart
│   │   └── size_converter.dart
│   ├── widgets/
│   │   ├── avatar_painter.dart
│   │   ├── avatar_view.dart
│   │   ├── clothing_card.dart
│   │   ├── clothing_carousel.dart
│   │   └── weather_widget.dart
│   └── main.dart
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## Dependencias Principales

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # ML Kit
  google_mlkit_pose_detection: ^0.x.x
  
  # Storage
  path_provider: ^2.x.x
  
  # Camera & Images
  camera: ^0.x.x
  image_picker: ^0.x.x
  
  # UI
  cupertino_icons: ^1.0.0
  
  # State Management
  provider: ^6.x.x
  
  # Database
  sqflite: ^2.x.x
  
  # Networking
  http: ^1.x.x
  
  # Utils
  intl: ^0.x.x
  uuid: ^3.x.x
```

## Configuración de Desarrollo

### Variables de Entorno

Crear archivo `.env`:
```
FIREBASE_API_KEY=your_key
FIREBASE_PROJECT_ID=your_project
DEBUG_MODE=true
LOG_LEVEL=debug
```

### Configuración de Build

#### Android (android/app/build.gradle)
```gradle
android {
    compileSdkVersion 33
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

#### iOS (ios/Podfile)
```ruby
platform :ios, '12.0'
```

## Comandos Útiles

### Desarrollo
```bash
# Ejecutar en modo debug
flutter run

# Ejecutar con logs
flutter run -v

# Ejecutar en dispositivo específico
flutter run -d <device_id>

# Hot reload
r (en terminal)

# Hot restart
R (en terminal)
```

### Testing
```bash
# Ejecutar tests
flutter test

# Tests con cobertura
flutter test --coverage

# Tests específicos
flutter test test/services/advanced_scanner_capture_service_test.dart
```

### Build
```bash
# Build APK
flutter build apk

# Build AAB (Play Store)
flutter build appbundle

# Build iOS
flutter build ios

# Build web
flutter build web
```

### Análisis
```bash
# Análisis estático
flutter analyze

# Formato de código
flutter format lib/

# Linting
dart analyze lib/
```

## Debugging

### Habilitar Logs
```dart
// En main.dart
void main() {
  // Habilitar logs detallados
  debugPrintBeginFrame = true;
  debugPrintEndFrame = true;
  
  runApp(const OutfitApp());
}
```

### Usar DevTools
```bash
flutter pub global activate devtools
devtools
```

### Breakpoints
```dart
// En código
debugger(); // Pausa aquí

// O usar IDE
// Clic en número de línea
```

## Estructura de Datos

### Avatar
```dart
MultiAngleAvatar {
  frontImagePath: String,
  rightSideImagePath: String?,
  backImagePath: String?,
  leftSideImagePath: String?,
  createdAt: DateTime,
  metadata: {
    'hasCompleteViews': bool,
    'capturedAngles': List<String>,
    'captureMethod': 'advanced_scanner',
    'qualityScores': Map<String, double>,
  }
}
```

### Outfit
```dart
Outfit {
  id: String,
  name: String,
  clothes: List<ClothingItem>,
  createdAt: DateTime,
  previewImage: File?,
  tags: List<String>,
}
```

### ClothingItem
```dart
ClothingItem {
  id: String,
  name: String,
  type: ClothingType,
  imagePath: String,
  color: String?,
  size: String?,
  brand: String?,
  createdAt: DateTime,
}
```

## Patrones de Código

### Servicio Singleton
```dart
class MyService {
  static final MyService _instance = MyService._internal();
  
  factory MyService() => _instance;
  
  MyService._internal();
  
  // Métodos...
}
```

### Validación de Resultado
```dart
final result = await service.doSomething();

if (result.isSuccess) {
  // Éxito
} else {
  // Error
  debugPrint('Error: ${result.errorMessage}');
}
```

### Manejo de Async
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  
  try {
    final data = await _service.fetchData();
    setState(() => _data = data);
  } catch (e) {
    debugPrint('Error: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

## Testing

### Test de Servicio
```dart
void main() {
  group('AdvancedScannerCaptureService', () {
    late AdvancedScannerCaptureService service;
    
    setUp(() {
      service = AdvancedScannerCaptureService();
    });
    
    test('analyzeFrame returns valid result', () async {
      final file = File('test_image.jpg');
      final result = await service.analyzeFrame(file, AvatarAngle.front);
      
      expect(result.isSuccess, true);
    });
  });
}
```

### Test de Widget
```dart
void main() {
  testWidgets('OutfitBuilderScreen displays avatar', (WidgetTester tester) async {
    await tester.pumpWidget(const OutfitApp());
    
    expect(find.byType(OutfitBuilderScreen), findsOneWidget);
  });
}
```

## Performance

### Profiling
```bash
# Ejecutar con profiling
flutter run --profile

# Usar DevTools para analizar
```

### Optimizaciones
1. Usar `const` constructores
2. Evitar rebuilds innecesarios
3. Usar `RepaintBoundary` para widgets complejos
4. Caché de imágenes
5. Lazy loading

## Seguridad

### Almacenamiento Seguro
```dart
// Usar path_provider para rutas seguras
final appDir = await getApplicationDocumentsDirectory();
final file = File('${appDir.path}/secure_data.json');
```

### Validación de Entrada
```dart
// Validar siempre entrada del usuario
if (input.isEmpty || input.length > 100) {
  throw ValidationException('Invalid input');
}
```

## Deployment

### Pre-deployment Checklist
- [ ] Todos los tests pasan
- [ ] Análisis estático sin errores
- [ ] Versión actualizada en pubspec.yaml
- [ ] CHANGELOG.md actualizado
- [ ] README.md actualizado
- [ ] Documentación actualizada
- [ ] Screenshots actualizados
- [ ] Privacidad y términos revisados

### Versioning
```yaml
# pubspec.yaml
version: 2.0.0+20
# Formato: major.minor.patch+build
```

## Troubleshooting

### Problema: "No se detectó pose"
**Solución:**
- Verificar iluminación
- Asegurar cuerpo completo visible
- Usar imagen de mejor calidad

### Problema: "Generación lenta"
**Solución:**
- Reducir resolución de imagen
- Usar modo release
- Liberar memoria

### Problema: "Crash en captura"
**Solución:**
- Verificar permisos de cámara
- Actualizar ML Kit
- Reiniciar app

## Recursos

- [Flutter Docs](https://flutter.dev/docs)
- [Dart Docs](https://dart.dev/guides)
- [ML Kit Docs](https://developers.google.com/ml-kit)
- [Material Design](https://material.io/design)

## Contacto

- 📧 dev@outfitmaker.app
- 🐛 issues@outfitmaker.app
- 💬 slack: #outfit-maker-dev

---

**Última actualización:** 2024
**Versión:** 2.0
