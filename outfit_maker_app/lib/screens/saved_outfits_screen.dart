import 'package:flutter/material.dart';
import '../models/outfit.dart';
import '../models/clothing_item.dart';
import '../services/outfit_service.dart';
import '../services/album_service.dart';

/// Pantalla para ver outfits guardados y gestionar álbumes
class SavedOutfitsScreen extends StatefulWidget {
  const SavedOutfitsScreen({super.key});

  @override
  State<SavedOutfitsScreen> createState() => _SavedOutfitsScreenState();
}

class _SavedOutfitsScreenState extends State<SavedOutfitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OutfitService _outfitService = OutfitService();
  final AlbumService _albumService = AlbumService();

  List<Outfit> _outfits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _outfitService.initialize();
    await _albumService.initialize();

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
                const SizedBox(height: 16),
                const Text(
                  'Prendas:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: outfit.clothes.length,
                    itemBuilder: (context, index) {
                      final item = outfit.clothes[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.checkroom),
                          title: Text(item.name),
                          subtitle: Text('${item.category} • Talla ${item.size}'),
                          trailing: Chip(
                            label: Text(_getTypeName(item.type)),
                            visualDensity: VisualDensity.compact,
                          ),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.checkroom), text: 'Todos'),
            Tab(icon: Icon(Icons.folder), text: 'Álbumes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOutfitsList(),
          _buildAlbumsList(),
        ],
      ),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _outfits.length,
      itemBuilder: (context, index) {
        final outfit = _outfits[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text('${outfit.clothes.length}'),
            ),
            title: Text(outfit.name),
            subtitle: Text('${outfit.clothes.length} prendas • ${_formatDate(outfit.createdAt)}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOutfitDetails(outfit),
            ),
            onTap: () => _showOutfitDetails(outfit),
          ),
        );
      },
    );
  }

  Widget _buildAlbumsList() {
    final albums = _albumService.getAllAlbums();

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes álbumes',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createDefaultAlbums,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Crear álbumes por temporada'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getSeasonColor(album.season),
              child: Icon(
                _getSeasonIcon(album.season),
                color: Colors.white,
              ),
            ),
            title: Text(album.name),
            subtitle: Text('${album.outfitCount} outfits'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showAlbumDetails(album),
          ),
        );
      },
    );
  }

  Future<void> _createDefaultAlbums() async {
    await _albumService.createDefaultSeasonalAlbums();
    setState(() {});
  }

  void _showAlbumDetails(OutfitAlbum album) {
    final albumOutfits = _albumService.getOutfitsInAlbum(album.id, _outfits);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getSeasonColor(album.season),
                      child: Icon(
                        _getSeasonIcon(album.season),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (album.description.isNotEmpty)
                            Text(
                              album.description,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${albumOutfits.length} outfits en este álbum',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: albumOutfits.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text(
                                'Este álbum está vacío',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: albumOutfits.length,
                          itemBuilder: (context, index) {
                            final outfit = albumOutfits[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${outfit.clothes.length}'),
                                ),
                                title: Text(outfit.name),
                                subtitle: Text('${outfit.clothes.length} prendas'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () async {
                                    await _albumService.removeOutfitFromAlbum(
                                      album.id,
                                      outfit.id,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getSeasonColor(String? season) {
    switch (season) {
      case 'verano':
        return Colors.orange;
      case 'invierno':
        return Colors.blue;
      case 'primavera':
        return Colors.green;
      case 'otoño':
        return Colors.brown;
      default:
        return Colors.purple;
    }
  }

  IconData _getSeasonIcon(String? season) {
    switch (season) {
      case 'verano':
        return Icons.wb_sunny;
      case 'invierno':
        return Icons.ac_unit;
      case 'primavera':
        return Icons.local_florist;
      case 'otoño':
        return Icons.forest;
      default:
        return Icons.folder;
    }
  }

  String _getTypeName(ClothingType type) {
    switch (type) {
case ClothingType.top:
        return 'Superior';
      case ClothingType.bottom:
        return 'Inferior';
      case ClothingType.headwear:
        return 'Cabeza';
      case ClothingType.footwear:
        return 'Calzado';
      case ClothingType.neckwear:
        return 'Cuello';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
