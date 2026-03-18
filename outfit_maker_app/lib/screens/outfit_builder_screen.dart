import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_services.dart';
import '../widgets/outfit_canvas_new.dart';
import '../widgets/clothing_carousel.dart';

/// Pantalla para crear outfits visualmente
/// Muestra un maniquí central con prendas superpuestas y carruseles para seleccionar
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final OutfitService _outfitService = OutfitService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Prendas organizadas por categoría
  Map<ClothingCategory, List<ClothingItem>> _clothesByCategory = {};

  // Selección actual por categoría
  Map<ClothingCategory, ClothingItem?> _selectedByCategory = {
    for (var cat in ClothingCategory.values) cat: null,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _wardrobeService.initialize();
    await _outfitService.initialize();

    final clothes = _wardrobeService.getAllItems();

    // Organizar por categoría
    final byCategory = <ClothingCategory, List<ClothingItem>>{};
    for (final category in ClothingCategory.values) {
      byCategory[category] = clothes.where((c) => c.category == category).toList();
    }

    if (mounted) {
      setState(() {
        _clothesByCategory = byCategory;
        _isLoading = false;
      });
    }
  }

  /// Obtiene las prendas seleccionadas como lista
  List<ClothingItem> get _selectedItems =>
      _selectedByCategory.values.whereType<ClothingItem>().toList();

  /// Verifica si hay al menos una prenda seleccionada
  bool get _hasSelection => _selectedItems.isNotEmpty;

  /// Maneja la selección de una prenda
  void _onItemSelected(ClothingCategory category, ClothingItem? item) {
    setState(() {
      _selectedByCategory[category] = item;
    });

    if (item != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} añadido'),
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => _onItemSelected(category, null),
          ),
        ),
      );
    }
  }

  /// Limpia todas las selecciones
  void _clearSelection() {
    setState(() {
      for (final category in ClothingCategory.values) {
        _selectedByCategory[category] = null;
      }
    });
  }

  /// Guarda el outfit actual
  Future<void> _saveOutfit() async {
    if (!_hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una prenda')),
      );
      return;
    }

    final selectedCount = _selectedItems.length;
    final nameController = TextEditingController(
      text: 'Outfit $selectedCount prendas',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar Outfit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del outfit',
                hintText: 'Ej: Look casual de verano',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Resumen de prendas seleccionadas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _selectedItems
                    .map((item) => ListTile(
                          dense: true,
                          leading: Text(item.category.icon),
                          title: Text(item.name),
                          contentPadding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);

      try {
        await _outfitService.saveOutfit(
          name: nameController.text.isNotEmpty
              ? nameController.text
              : 'Outfit ${DateTime.now().day}/${DateTime.now().month}',
          items: _selectedItems,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Outfit guardado exitosamente')),
          );
          _clearSelection();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  /// Sugiere un outfit aleatorio
  void _suggestOutfit() {
    final hasClothes = _clothesByCategory.values.any((list) => list.isNotEmpty);

    if (!hasClothes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay prendas en el armario')),
      );
      return;
    }

    setState(() {
      for (final category in ClothingCategory.values) {
        final items = _clothesByCategory[category];
        if (items != null && items.isNotEmpty) {
          // Seleccionar aleatoriamente o dejar null
          _selectedByCategory[category] =
              DateTime.now().millisecond % 3 == 0 ? null : items.first;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sugerencia: ${_selectedItems.length} prendas'),
        action: SnackBarAction(
          label: 'Aceptar',
          onPressed: () {},
        ),
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
        title: const Text('Crear Outfit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _suggestOutfit,
            tooltip: 'Sugerir outfit',
          ),
          if (_hasSelection)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Limpiar selección',
            ),
        ],
      ),
      body: Column(
        children: [
          // SECCIÓN SUPERIOR: Canvas con el maniquí y prendas
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutfitCanvas(
                selectedItems: _selectedItems,
                height: double.infinity,
              ),
            ),
          ),

          // SECCIÓN INFERIOR: Selectores de prendas
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicador de arrastre
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header de sección
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.checkroom,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Selecciona prendas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedItems.length} seleccionadas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Carruseles de prendas
                  Expanded(
                    child: _clothesByCategory.values.every((l) => l.isEmpty)
                        ? _buildEmptyState()
                        : ClothingCarouselSelector(
                            clothesByCategory: _clothesByCategory,
                            selectedByCategory: _selectedByCategory,
                            onItemSelected: _onItemSelected,
                            itemSize: 80,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _hasSelection
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveOutfit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Outfit'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No hay prendas en tu armario',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade prendas primero para crear outfits',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
