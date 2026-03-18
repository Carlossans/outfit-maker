import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'wardrobe_screen.dart';
import 'outfit_builder_screen.dart';
import 'calendar_screen.dart';
import 'avatar_setup_screen.dart';
import 'saved_outfits_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasAvatar = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAvatarStatus();
  }

  Future<void> _checkAvatarStatus() async {
    final hasAvatar = await AvatarService().hasCompletedSetup();
    if (mounted) {
      setState(() {
        _hasAvatar = hasAvatar;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Outfit Maker"),
        centerTitle: true,
        actions: [
          if (_hasAvatar)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar Avatar',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AvatarSetupScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Título de sección
                Text(
                  'Menú Principal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Opciones del menú
                _MenuCard(
                  icon: Icons.checkroom,
                  title: 'Mi Armario',
                  subtitle: 'Gestiona tu colección de prendas',
                  color: Colors.blue,
                  onTap: () => _navigateTo(context, const WardrobeScreen()),
                ),
                const SizedBox(height: 12),
                _MenuCard(
                  icon: Icons.auto_awesome,
                  title: 'Crear Outfit',
                  subtitle: 'Combina prendas y crea looks',
                  color: Colors.purple,
                  onTap: () => _navigateTo(context, const OutfitBuilderScreen()),
                ),
                const SizedBox(height: 12),
                _MenuCard(
                  icon: Icons.calendar_month,
                  title: 'Calendario',
                  subtitle: 'Planifica tus outfits de la semana',
                  color: Colors.green,
                  onTap: () => _navigateTo(context, const CalendarScreen()),
                ),
                const SizedBox(height: 12),
                _MenuCard(
                  icon: Icons.folder_outlined,
                  title: 'Mis Outfits',
                  subtitle: 'Ver outfits guardados',
                  color: Colors.indigo,
                  onTap: () => _navigateTo(context, const SavedOutfitsScreen()),
                ),
                if (!_hasAvatar) ...[
                  const SizedBox(height: 12),
                  _MenuCard(
                    icon: Icons.person_outline,
                    title: 'Mi Avatar',
                    subtitle: 'Configura tu avatar virtual',
                    color: Colors.orange,
                    onTap: () => _navigateTo(context, const AvatarSetupScreen()),
                  ),
                ],
              ],
            ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

/// Tarjeta de menú personalizada
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
