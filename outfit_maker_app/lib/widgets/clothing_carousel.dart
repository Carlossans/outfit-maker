import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_models.dart';

/// Selector de prendas con carruseles horizontales por categoría
class ClothingCarouselSelector extends StatelessWidget {
  final Map<ClothingCategory, List<ClothingItem>> clothesByCategory;
  final Map<ClothingCategory, ClothingItem?> selectedByCategory;
  final Function(ClothingCategory, ClothingItem?) onItemSelected;
  final double itemSize;

  const ClothingCarouselSelector({
    super.key,
    required this.clothesByCategory,
    required this.selectedByCategory,
    required this.onItemSelected,
    this.itemSize = 85,
  });

  @override
  Widget build(BuildContext context) {
    // Orden de categorías
    final categories = [
      ClothingCategory.tops,
      ClothingCategory.bottoms,
      ClothingCategory.shoes,
      ClothingCategory.accessories,
    ];

    // Filtrar solo categorías con prendas
    final availableCategories = categories
        .where((cat) => (clothesByCategory[cat]?.isNotEmpty ?? false))
        .toList();

    if (availableCategories.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: availableCategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = availableCategories[index];
        return _buildCategorySection(context, category);
      },
    );
  }

  Widget _buildCategorySection(BuildContext context, ClothingCategory category) {
    final items = clothesByCategory[category] ?? [];
    final selected = selectedByCategory[category];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header de categoría
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  category.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (selected != null)
                  TextButton.icon(
                    onPressed: () => onItemSelected(category, null),
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Carrusel de prendas
          SizedBox(
            height: itemSize + 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: items.length + 1, // +1 para "Ninguna"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildNoneOption(context, category, selected == null);
                }
                final item = items[index - 1];
                final isSelected = selected?.id == item.id;
                return _buildClothingCard(context, item, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoneOption(
    BuildContext context,
    ClothingCategory category,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => onItemSelected(category, null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        width: itemSize * 0.85,
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade300 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.grey.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              color: isSelected ? Colors.grey.shade700 : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Ninguna',
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.grey.shade700 : Colors.grey.shade500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothingCard(
    BuildContext context,
    ClothingItem item,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => onItemSelected(item.category, isSelected ? null : item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        width: itemSize * 0.85,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 6 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen de la prenda
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
                child: _buildItemImage(item),
              ),
            ),

            // Nombre de la prenda
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(9),
                ),
              ),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(ClothingItem item) {
    // Intentar cargar desde archivo
    if (!item.imagePath.startsWith('http')) {
      final file = File(item.imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(item),
        );
      }
    }

    // Intentar desde URL
    if (item.imagePath.startsWith('http')) {
      return Image.network(
        item.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(item),
      );
    }

    return _buildImagePlaceholder(item);
  }

  Widget _buildImagePlaceholder(ClothingItem item) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Text(
          item.category.icon,
          style: const TextStyle(fontSize: 28),
        ),
      ),
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

/// Versión compacta del selector con chips
class ClothingChipsSelector extends StatelessWidget {
  final Map<ClothingCategory, List<ClothingItem>> clothesByCategory;
  final Map<ClothingCategory, ClothingItem?> selectedByCategory;
  final Function(ClothingCategory, ClothingItem?) onItemSelected;

  const ClothingChipsSelector({
    super.key,
    required this.clothesByCategory,
    required this.selectedByCategory,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: ClothingCategory.values.map((category) {
          final hasSelection = selectedByCategory[category] != null;
          final count = clothesByCategory[category]?.length ?? 0;

          if (count == 0 && !hasSelection) return const SizedBox.shrink();

          return ActionChip(
            avatar: Text(category.icon),
            label: Text('${category.displayName} ${hasSelection ? "✓" : ""}'),
            backgroundColor: hasSelection
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            side: hasSelection
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
            onPressed: () => _showCategoryPicker(context, category),
          );
        }).toList(),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, ClothingCategory category) {
    final items = clothesByCategory[category] ?? [];
    final currentSelected = selectedByCategory[category];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de arrastre
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      category.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Opción "Sin prenda"
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Sin prenda'),
                  selected: currentSelected == null,
                  onTap: () {
                    onItemSelected(category, null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),

                // Lista de prendas
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = currentSelected?.id == item.id;

                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildMiniThumbnail(item),
                        ),
                        title: Text(item.name),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        selected: isSelected,
                        onTap: () {
                          onItemSelected(category, item);
                          Navigator.pop(context);
                        },
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

  Widget _buildMiniThumbnail(ClothingItem item) {
    if (!item.imagePath.startsWith('http')) {
      final file = File(item.imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, fit: BoxFit.cover),
        );
      }
    }

    return Center(
      child: Text(item.category.icon, style: const TextStyle(fontSize: 20)),
    );
  }
}
