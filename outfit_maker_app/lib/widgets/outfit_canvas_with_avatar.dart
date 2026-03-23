import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_services.dart';
import 'clothing_carousel.dart';

/// Canvas que muestra el avatar real del usuario con carruseles de ropa superpuestos
/// en las zonas correspondientes del cuerpo
class OutfitCanvasWithAvatar extends StatefulWidget {
  final List<ClothingItem> selectedItems;
  final Map<ClothingCategory, ClothingItem?> selectedByCategory;
  final Function(ClothingCategory, ClothingItem?) onItemSelected;
  final Map<ClothingCategory, List<ClothingItem>> clothesByCategory;

  const OutfitCanvasWithAvatar({
    super.key,
    required this.selectedItems,
    required this.selectedByCategory,
    required this.onItemSelected,
    required this.clothesByCategory,
  });

  @override
  State<OutfitCanvasWithAvatar> createState() => _OutfitCanvasWithAvatarState();
}

class _OutfitCanvasWithAvatarState extends State<OutfitCanvasWithAvatar> {
  File? _avatarImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarService = AvatarService();
    await avatarService.initialize();
    final file = await avatarService.getAvatarImageFile();
    if (mounted) {
      setState(() {
        _avatarImage = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Imagen del avatar de fondo
                if (_avatarImage != null)
                  Positioned.fill(
                    child: Image.file(
                      _avatarImage!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),

                // Placeholder si no hay avatar
                if (_avatarImage == null)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No hay avatar configurado',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Overlay de prendas seleccionadas
                if (_avatarImage != null) ...[
                  _buildClothingOverlay(),
                ],

                // Mensaje cuando no hay prendas
                if (widget.selectedItems.isEmpty && _avatarImage != null)
                  _buildEmptyStateOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClothingOverlay() {
    // Prendas organizadas por categoría con posiciones relativas al cuerpo
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;

        return Stack(
          children: [
            // Camisetas - Zona del pecho (centro superior)
            if (widget.clothesByCategory[ClothingCategory.tops]?.isNotEmpty ?? false)
              Positioned(
                left: width * 0.15,
                right: width * 0.15,
                top: height * 0.18,
                height: height * 0.22,
                child: _buildCategoryCarousel(
                  ClothingCategory.tops,
                  'Camisetas',
                ),
              ),

            // Pantalones - Zona de piernas/caderas (centro)
            if (widget.clothesByCategory[ClothingCategory.bottoms]?.isNotEmpty ?? false)
              Positioned(
                left: width * 0.18,
                right: width * 0.18,
                top: height * 0.40,
                height: height * 0.30,
                child: _buildCategoryCarousel(
                  ClothingCategory.bottoms,
                  'Pantalones',
                ),
              ),

            // Zapatos - Zona de pies (abajo)
            if (widget.clothesByCategory[ClothingCategory.shoes]?.isNotEmpty ?? false)
              Positioned(
                left: width * 0.25,
                right: width * 0.25,
                bottom: height * 0.02,
                height: height * 0.14,
                child: _buildCategoryCarousel(
                  ClothingCategory.shoes,
                  'Zapatos',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCarousel(ClothingCategory category, String label) {
    final items = widget.clothesByCategory[category] ?? [];
    final selected = widget.selectedByCategory[category];

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected != null
              ? Colors.blue.withOpacity(0.6)
              : Colors.white.withOpacity(0.3),
          width: selected != null ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header de la categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Carrusel de prendas
          Expanded(
            child: _buildHorizontalCarousel(category, items, selected),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCarousel(
    ClothingCategory category,
    List<ClothingItem> items,
    ClothingItem? selected,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      itemCount: items.length + 1, // +1 para opción "Ninguna"
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildNoneCard(category, selected == null);
        }
        final item = items[index - 1];
        final isSelected = selected?.id == item.id;
        return _buildClothingCard(item, isSelected, category);
      },
    );
  }

  Widget _buildNoneCard(ClothingCategory category, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onItemSelected(category, null),
      child: Container(
        width: 55,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.grey.shade400
              : Colors.grey.shade200.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              'Ninguna',
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothingCard(
    ClothingItem item,
    bool isSelected,
    ClothingCategory category,
  ) {
    return GestureDetector(
      onTap: () => widget.onItemSelected(category, isSelected ? null : item),
      child: Container(
        width: 55,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade100
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
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
                  top: Radius.circular(7),
                ),
                child: _buildItemImage(item),
              ),
            ),
            // Nombre de la prenda
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade100
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(7),
                ),
              ),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(ClothingItem item) {
    final file = File(item.imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(item),
      );
    }

    if (item.imagePath.startsWith('http')) {
      return Image.network(
        item.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(item),
      );
    }

    return _buildPlaceholder(item);
  }

  Widget _buildPlaceholder(ClothingItem item) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          item.category.icon,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildEmptyStateOverlay() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Selecciona prendas de los carruseles',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Vista previa estática de un outfit guardado con avatar
class OutfitPreviewWithAvatar extends StatefulWidget {
  final Outfit outfit;
  final double height;

  const OutfitPreviewWithAvatar({
    super.key,
    required this.outfit,
    this.height = 200,
  });

  @override
  State<OutfitPreviewWithAvatar> createState() => _OutfitPreviewWithAvatarState();
}

class _OutfitPreviewWithAvatarState extends State<OutfitPreviewWithAvatar> {
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarService = AvatarService();
    await avatarService.initialize();
    final file = await avatarService.getAvatarImageFile();
    if (mounted) {
      setState(() => _avatarImage = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Avatar de fondo
            if (_avatarImage != null)
              Positioned.fill(
                child: Image.file(
                  _avatarImage!,
                  fit: BoxFit.contain,
                ),
              ),

            // Prendas superpuestas
            ..._buildClothingLayers(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildClothingLayers() {
    final sortedItems = List<ClothingItem>.from(widget.outfit.items)
      ..sort((a, b) => a.category.layerOrder.compareTo(b.category.layerOrder));

    return sortedItems.map((item) {
      // Posicionar según la zona del cuerpo
      final zone = item.category.bodyZone;

      return Positioned(
        left: 0,
        right: 0,
        top: _getTopPosition(zone),
        height: widget.height * zone.relativeHeight,
        child: _buildClothingImage(item),
      );
    }).toList();
  }

  double _getTopPosition(BodyZone zone) {
    switch (zone) {
      case BodyZone.head:
        return widget.height * 0.05;
      case BodyZone.torso:
        return widget.height * 0.25;
      case BodyZone.legs:
        return widget.height * 0.50;
      case BodyZone.feet:
        return widget.height * 0.85;
    }
  }

  Widget _buildClothingImage(ClothingItem item) {
    final file = File(item.imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    }
    return Center(
      child: Text(item.category.icon, style: const TextStyle(fontSize: 32)),
    );
  }
}
