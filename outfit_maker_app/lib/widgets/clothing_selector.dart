import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';

/// Selector de prendas con carrusel horizontal por categoría
/// Cada categoría muestra sus prendas en un scroll horizontal
class CategoryClothingSelector extends StatelessWidget {
  final Map<ClothingCategory, List<ClothingItem>> clothesByCategory;
  final Map<ClothingCategory, ClothingItem?> selectedByCategory;
  final Function(ClothingCategory, ClothingItem?) onItemSelected;
  final double itemHeight;

  const CategoryClothingSelector({
    super.key,
    required this.clothesByCategory,
    required this.selectedByCategory,
    required this.onItemSelected,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    // Orden de categorías
    final categories = [
      ClothingCategory.headwear,
      ClothingCategory.top,
      ClothingCategory.bottom,
      ClothingCategory.footwear,
      ClothingCategory.accessory,
    ];

    // Filtrar solo categorías con prendas
    final availableCategories = categories
        .where((cat) => (clothesByCategory[cat]?.isNotEmpty ?? false))
        .toList();

    if (availableCategories.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: availableCategories.length,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la categoría
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (selected != null)
                  TextButton.icon(
                    onPressed: () => onItemSelected(category, null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Quitar'),
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
            height: itemHeight + 20,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        width: itemHeight * 0.9,
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade300 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
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
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Ninguna',
              style: TextStyle(
                fontSize: 11,
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
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        width: itemHeight * 0.9,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withAlpha(60)
                  : Colors.black.withAlpha(20),
              blurRadius: isSelected ? 8 : 4,
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
                  top: Radius.circular(11),
                ),
                child: _buildItemImage(item),
              ),
            ),

            // Nombre de la prenda
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.grey.shade800,
                    ),
                  ),
                  if (item.size != null)
                    Text(
                      item.size!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
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
          style: const TextStyle(fontSize: 32),
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

/// Selector compacto con chips y bottom sheet
class CompactClothingSelector extends StatelessWidget {
  final Map<ClothingCategory, List<ClothingItem>> clothesByCategory;
  final Map<ClothingCategory, ClothingItem?> selectedByCategory;
  final Function(ClothingCategory, ClothingItem?) onItemSelected;

  const CompactClothingSelector({
    super.key,
    required this.clothesByCategory,
    required this.selectedByCategory,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chips de categorías
          Wrap(
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
        ],
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
                        subtitle: item.size != null ? Text(item.size!) : null,
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
