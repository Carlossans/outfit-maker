import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_services.dart';
import '../widgets/outfit_canvas_with_avatar.dart';

/// Pantalla para ver outfits guardados
class SavedOutfitsScreen extends StatefulWidget {
  const SavedOutfitsScreen({super.key});

  @override
  State<SavedOutfitsScreen> createState() => _SavedOutfitsScreenState();
}

class _SavedOutfitsScreenState extends State<SavedOutfitsScreen> {
  final OutfitService _outfitService = OutfitService();

  List<Outfit> _outfits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _outfitService.initialize();

    setState(() {
      _outfits = _outfitService.getAllOutfits();
      _isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    _outfits = _outfitService.getAllOutfits();
    setState(() => _isLoading = false);
  }

  Future<void> _deleteOutfit(Outfit outfit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar outfit'),
        content: Text('¿Estás seguro de que quieres eliminar "${outfit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _outfitService.deleteOutfit(outfit.id);
      _refreshData();
    }
  }

  void _showOutfitDetails(Outfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outfit.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Creado: ${_formatDate(outfit.createdAt)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (outfit.wornAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Último uso: ${_formatDate(outfit.wornAt)}',
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ],
                const SizedBox(height: 16),

                // Preview del outfit
                SizedBox(
                  height: 200,
                  child: OutfitPreview(outfit: outfit),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Prendas:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: outfit.items.length,
                    itemBuilder: (context, index) {
                      final item = outfit.items[index];
                      return Card(
                        child: ListTile(
                          leading: Text(item.category.icon),
                          title: Text(item.name),
                          subtitle: Text(item.category.displayName),
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteOutfit(outfit);
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Outfits'),
      ),
      body: _buildOutfitsList(),
    );
  }

  Widget _buildOutfitsList() {
    if (_outfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes outfits guardados',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear Outfit'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _outfits.length,
        itemBuilder: (context, index) {
          final outfit = _outfits[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: outfit.wornAt != null
                    ? Colors.green.shade100
                    : Colors.blue.shade100,
                child: Text('${outfit.items.length}'),
              ),
              title: Text(outfit.name),
              subtitle: Text('${outfit.items.length} prendas • ${_formatDate(outfit.createdAt)}'),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showOutfitDetails(outfit),
              ),
              onTap: () => _showOutfitDetails(outfit),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
