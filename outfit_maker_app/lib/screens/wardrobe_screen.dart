import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../services/wardrobe_service.dart';
import '../widgets/clothing_card.dart';
import 'add_clothing_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  late Future<void> _initFuture;
  ClothingType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _initFuture = WardrobeService().initialize();
  }

  Future<void> _refreshData() async {
    setState(() {});
  }

  Future<void> _deleteClothing(ClothingItem item) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: Text('¿Estás seguro de que quieres eliminar "${item.name}"?'),
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
      final success = await WardrobeService().removeClothing(item.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" eliminado del armario')),
        );
        _refreshData();
      }
    }
  }

  void _showClothingDetails(ClothingItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Categoría: ${item.category}'),
            Text('Talla: ${item.size}'),
            Text('Tipo: ${_getTypeDisplayName(item.type)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteClothing(item);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withAlpha(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayName(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return 'Parte Superior';
      case ClothingType.bottom:
        return 'Parte Inferior';
      case ClothingType.headwear:
        return 'Cabeza';
      case ClothingType.footwear:
        return 'Calzado';
      case ClothingType.neckwear:
        return 'Cuello';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    var clothes = WardrobeService().getClothes();

    // Aplicar filtro si hay uno seleccionado
    if (_selectedFilter != null) {
      clothes = clothes.where((c) => c.type == _selectedFilter).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Armario"),
        actions: [
          // Filtro por tipo
          PopupMenuButton<ClothingType?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onSelected: (type) {
              setState(() => _selectedFilter = type);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Todos'),
              ),
              ...ClothingType.values.map((type) => PopupMenuItem(
                value: type,
                child: Text(_getTypeDisplayName(type)),
              )),
            ],
          ),
          // Contador de prendas
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${clothes.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddClothingScreen()),
          );
          _refreshData();
        },
      ),
      body: Column(
        children: [
          // Chips de filtros activos
          if (_selectedFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text('Filtrado: ${_getTypeDisplayName(_selectedFilter!)}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedFilter = null),
                  ),
                ],
              ),
            ),
          // Grid de prendas
          Expanded(
            child: clothes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.checkroom, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter != null
                              ? 'No hay prendas de este tipo'
                              : "No hay prendas en el armario",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddClothingScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir prenda'),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: clothes.length,
                    itemBuilder: (context, index) {
                      final item = clothes[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white),
                              SizedBox(height: 4),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteClothing(item);
                          return false; // Eliminamos manualmente
                        },
                        child: ClothingCard(
                          item: item,
                          onTap: () => _showClothingDetails(item),
                          onLongPress: () => _deleteClothing(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
