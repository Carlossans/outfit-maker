import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_services.dart';
import '../widgets/outfit_canvas_with_avatar.dart';

/// Pantalla para crear outfits visualmente
/// Muestra el avatar del usuario con carruseles superpuestos para seleccionar prendas
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
          // Header con información
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca una prenda para seleccionarla',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hasSelection
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedItems.length} prendas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _hasSelection
                          ? Colors.blue.shade800
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Canvas principal con avatar y carruseles
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _clothesByCategory.values.every((l) => l.isEmpty)
                  ? _buildEmptyState()
                  : OutfitCanvasWithAvatar(
                      selectedItems: _selectedItems,
                      selectedByCategory: _selectedByCategory,
                      onItemSelected: _onItemSelected,
                      clothesByCategory: _clothesByCategory,
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
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay prendas en tu armario',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade prendas primero para crear outfits',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }
}
