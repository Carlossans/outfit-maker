import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/avatar_setup_screen.dart';
import 'services/app_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicios
  await WardrobeService().initialize();
  await OutfitService().initialize();
  await AvatarService().initialize();

  runApp(const OutfitApp());
}

class OutfitApp extends StatelessWidget {
  const OutfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outfit Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AppInitializer(),
    );
  }
}

/// Widget que verifica el estado del avatar y redirige a la pantalla correspondiente
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _hasAvatar = false;

  @override
  void initState() {
    super.initState();
    _checkAvatarStatus();
  }

  Future<void> _checkAvatarStatus() async {
    final avatarService = AvatarService();
    final hasCompletedSetup = await avatarService.hasCompletedSetup();

    setState(() {
      _hasAvatar = hasCompletedSetup;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando...'),
            ],
          ),
        ),
      );
    }

    // Si tiene avatar, ir a HomeScreen, si no, a AvatarSetupScreen
    return _hasAvatar ? const HomeScreen() : const AvatarSetupScreen();
  }
}
