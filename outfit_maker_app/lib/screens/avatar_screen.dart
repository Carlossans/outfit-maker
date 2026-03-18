import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../services/wardrobe_service.dart';
import '../widgets/clothing_carousel.dart';
import '../widgets/outfit_canvas.dart';

/// Pantalla simplificada para probar outfits sobre el avatar
class AvatarScreen extends StatefulWidget {
  final File userImage;
  final List<ClothingItem> outfit;

  const AvatarScreen({
    super.key,
    required this.userImage,
    required this.outfit,
  });

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  List<ClothingItem> _currentOutfit = [];
  int _selectedCategoryIndex = 0;

  final List<ClothingType> _categories = [
    ClothingType.headwear,
    ClothingType.top,
    ClothingType.bottom,
    ClothingType.footwear,
    ClothingType.neckwear,
  ];

  @override
  void initState() {
    super.initState();
    _currentOutfit = List.from(widget.outfit);
  }

  void _addClothingToOutfit(ClothingItem item) {
    setState(() {
      _currentOutfit.removeWhere((c) => c.type == item.type);
      _currentOutfit.add(item);
    });
  }

  void _removeClothingFromOutfit(ClothingType type) {
    setState(() {
      _currentOutfit.removeWhere((c) => c.type == type);
    });
  }

  void _clearOutfit() {
    setState(() {
      _currentOutfit.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Probar Outfit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearOutfit,
            tooltip: 'Limpiar outfit',
          ),
        ],
      ),
      body: Column(
        children: [
          // Vista del avatar con ropa
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutfitCanvas(
                selectedItems: _currentOutfit,
                height: double.infinity,
              ),
            ),
          ),

          // Indicador de outfit actual
          if (_currentOutfit.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: _currentOutfit.map((item) {
                  return Chip(
                    avatar: Text(item.type.icon),
                    label: Text(item.name),
                    onDeleted: () => _removeClothingFromOutfit(item.type),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
            ),

          // Selector de categorías
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Categoría:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final type = entry.value;
                        final isSelected = index == _selectedCategoryIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategoryIndex = index);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carrusel de prendas disponibles
          Expanded(
            flex: 2,
            child: ClothingCarousel(
              title: _categories[_selectedCategoryIndex].displayName,
              items: WardrobeService()
                  .getClothesByType(_categories[_selectedCategoryIndex]),
              onItemSelected: _addClothingToOutfit,
            ),
          ),
        ],
      ),
    );
  }
}
