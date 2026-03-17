# 🚀 Guía de Instalación y Setup - Outfit Maker v2.0

## 📋 Requisitos Previos

### Sistema Operativo
- **Windows 10+**, **macOS 10.15+**, o **Linux**
- Mínimo 4GB RAM
- 5GB espacio libre en disco

### Software Requerido
- **Flutter SDK** (v3.0+)
- **Dart SDK** (incluido con Flutter)
- **Android Studio** (para Android) o **Xcode** (para iOS)
- **Git**

### Dispositivo Destino
- **Android 8.0+** (API 21+)
- **iOS 12.0+**
- Cámara funcional
- Mínimo 2GB RAM

---

## 🔧 Instalación de Dependencias

### 1. Instalar Flutter

#### Windows
```bash
# Descargar Flutter SDK
# https://flutter.dev/docs/get-started/install/windows

# Extraer en C:\flutter (o ruta preferida)
# Agregar a PATH:
# C:\flutter\bin

# Verificar instalación
flutter --version
```

#### macOS
```bash
# Usando Homebrew
brew install flutter

# O descargar manualmente
# https://flutter.dev/docs/get-started/install/macos

# Verificar instalación
flutter --version
```

#### Linux
```bash
# Descargar Flutter SDK
# https://flutter.dev/docs/get-started/install/linux

# Extraer en ~/flutter
# Agregar a PATH en ~/.bashrc o ~/.zshrc
export PATH="$PATH:$HOME/flutter/bin"

# Verificar instalación
flutter --version
```

### 2. Instalar Android Studio (para Android)

```bash
# Descargar desde
# https://developer.android.com/studio

# Instalar y ejecutar
# Instalar Android SDK
# Instalar emulador (opcional)

# Verificar
flutter doctor
```

### 3. Instalar Xcode (para iOS)

```bash
# macOS solo
xcode-select --install

# O desde App Store
# https://apps.apple.com/app/xcode/id497799835

# Verificar
flutter doctor
```

### 4. Verificar Setup

```bash
# Ejecutar diagnóstico completo
flutter doctor

# Debe mostrar:
# ✓ Flutter
# ✓ Dart
# ✓ Android Studio (si desarrollas para Android)
# ✓ Xcode (si desarrollas para iOS)
```

---

## 📥 Clonar el Proyecto

### 1. Clonar Repositorio

```bash
# Clonar proyecto
git clone https://github.com/tu-usuario/outfit-maker.git

# Entrar en directorio
cd outfit-maker/outfi_maker_app
```

### 2. Obtener Dependencias

```bash
# Descargar dependencias
flutter pub get

# Actualizar dependencias
flutter pub upgrade
```

### 3. Generar Archivos Necesarios

```bash
# Generar archivos de build
flutter pub run build_runner build

# O con watch mode
flutter pub run build_runner watch
```

---

## 🏗️ Configuración del Proyecto

### 1. Configurar Android

#### android/app/build.gradle
```gradle
android {
    compileSdkVersion 33
    
    defaultConfig {
        applicationId "com.example.outfit_maker"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 20
        versionName "2.0.0"
    }
}
```

#### android/app/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### 2. Configurar iOS

#### ios/Podfile
```ruby
platform :ios, '12.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

#### ios/Runner/Info.plist
```xml
<key>NSCameraUsageDescription</key>
<string>La app necesita acceso a la cámara para capturar fotos de tu avatar y prendas</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>La app necesita acceso a tu galería para seleccionar fotos</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>La app necesita permiso para guardar fotos</string>
```

---

## ▶️ Ejecutar la Aplicación

### 1. Ejecutar en Emulador/Simulador

#### Android
```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en emulador
flutter run

# O especificar dispositivo
flutter run -d emulator-5554
```

#### iOS
```bash
# Ejecutar en simulador
flutter run

# O especificar dispositivo
flutter run -d "iPhone 14"
```

### 2. Ejecutar en Dispositivo Físico

#### Android
```bash
# Conectar dispositivo USB
# Habilitar "Depuración USB" en Configuración > Opciones de Desarrollador

# Listar dispositivos
flutter devices

# Ejecutar
flutter run
```

#### iOS
```bash
# Conectar dispositivo
# Confiar en la computadora

# Ejecutar
flutter run
```

### 3. Modo Debug vs Release

```bash
# Modo Debug (por defecto)
flutter run

# Modo Release (optimizado)
flutter run --release

# Modo Profile (análisis de rendimiento)
flutter run --profile
```

---

## 🧪 Testing

### 1. Ejecutar Tests

```bash
# Todos los tests
flutter test

# Test específico
flutter test test/services/advanced_scanner_capture_service_test.dart

# Con cobertura
flutter test --coverage
```

### 2. Análisis Estático

```bash
# Análisis de código
flutter analyze

# Formato de código
flutter format lib/

# Linting
dart analyze lib/
```

---

## 📦 Build para Producción

### 1. Build APK (Android)

```bash
# Build APK
flutter build apk

# Build APK split por arquitectura
flutter build apk --split-per-abi

# Ubicación: build/app/outputs/flutter-apk/app-release.apk
```

### 2. Build AAB (Google Play)

```bash
# Build App Bundle
flutter build appbundle

# Ubicación: build/app/outputs/bundle/release/app-release.aab
```

### 3. Build iOS

```bash
# Build para iOS
flutter build ios

# Build para App Store
flutter build ios --release

# Ubicación: build/ios/iphoneos/Runner.app
```

---

## 🔐 Configuración de Seguridad

### 1. Claves de API

Crear archivo `.env`:
```
FIREBASE_API_KEY=your_key
FIREBASE_PROJECT_ID=your_project
DEBUG_MODE=false
```

### 2. Permisos

Verificar que todos los permisos están configurados:
- ✓ Cámara
- ✓ Almacenamiento
- ✓ Galería

### 3. Certificados (iOS)

```bash
# Generar certificados
# Usar Xcode o Apple Developer Portal
```

---

## 🐛 Troubleshooting

### Problema: "Flutter not found"
```bash
# Solución: Agregar Flutter a PATH
# Windows: Agregar C:\flutter\bin a PATH
# macOS/Linux: Agregar $HOME/flutter/bin a PATH

# Verificar
flutter --version
```

### Problema: "Android SDK not found"
```bash
# Solución: Instalar Android SDK
flutter doctor --android-licenses

# O configurar manualmente
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
```

### Problema: "Xcode not found"
```bash
# Solución: Instalar Xcode
xcode-select --install

# O desde App Store
```

### Problema: "Dependencias no se descargan"
```bash
# Solución: Limpiar y reinstalar
flutter clean
flutter pub get
flutter pub upgrade
```

### Problema: "Error de compilación"
```bash
# Solución: Limpiar build
flutter clean

# Reconstruir
flutter pub get
flutter run
```

### Problema: "Cámara no funciona"
```bash
# Verificar permisos en AndroidManifest.xml
# Verificar permisos en Info.plist (iOS)
# Solicitar permisos en tiempo de ejecución
```

---

## 📊 Verificación de Instalación

### Checklist
- [ ] Flutter instalado (`flutter --version`)
- [ ] Dart instalado (`dart --version`)
- [ ] Android Studio instalado (si es necesario)
- [ ] Xcode instalado (si es necesario)
- [ ] Proyecto clonado
- [ ] Dependencias descargadas (`flutter pub get`)
- [ ] Dispositivo conectado o emulador ejecutándose
- [ ] Aplicación ejecutándose sin errores

---

## 🚀 Próximos Pasos

### 1. Explorar la Aplicación
- Crear avatar
- Añadir prendas
- Crear outfits
- Guardar favoritos

### 2. Personalizar
- Cambiar colores en `lib/main.dart`
- Modificar textos en `lib/utils/constants.dart`
- Agregar nuevas características

### 3. Desplegar
- Generar APK/AAB para Android
- Generar IPA para iOS
- Subir a Play Store/App Store

---

## 📚 Recursos Útiles

### Documentación
- [Flutter Docs](https://flutter.dev/docs)
- [Dart Docs](https://dart.dev/guides)
- [ML Kit Docs](https://developers.google.com/ml-kit)

### Comunidad
- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Reddit r/Flutter](https://reddit.com/r/Flutter)

### Herramientas
- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Android Studio](https://developer.android.com/studio)
- [Xcode](https://developer.apple.com/xcode/)

---

## 💬 Soporte

Si encuentras problemas:

1. **Consulta la documentación**
   - `GUIA_DE_USO.md`
   - `NOTAS_TECNICAS.md`
   - `DEVELOPMENT.md`

2. **Ejecuta diagnóstico**
   ```bash
   flutter doctor -v
   ```

3. **Limpia y reconstruye**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Contacta soporte**
   - 📧 support@outfitmaker.app
   - 🐛 issues@outfitmaker.app

---

## ✅ Instalación Completada

Una vez completados todos los pasos:

1. ✅ Dependencias instaladas
2. ✅ Proyecto configurado
3. ✅ Aplicación ejecutándose
4. ✅ Listo para desarrollar

**¡Disfruta desarrollando con Outfit Maker! 👗✨**

---

**Versión:** 2.0  
**Última actualización:** 2024  
**Mantenedor:** Equipo de Outfit Maker
