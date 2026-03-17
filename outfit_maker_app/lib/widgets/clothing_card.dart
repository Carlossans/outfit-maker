// /lib/widgets/clothing_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';

class ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ClothingCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Talla: ${item.size}'),
                  Text(
                    _getTypeDisplayName(item.type),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (item.imagePath.isEmpty) {
      return _buildPlaceholder();
    }

    final file = File(item.imagePath);
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data != true) {
          return _buildPlaceholder();
        }

        return Image.file(
          file,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          _getTypeIcon(item.type),
          size: 50,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  String _getTypeDisplayName(ClothingType type) {
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

  IconData _getTypeIcon(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return Icons.checkroom;
      case ClothingType.bottom:
        return Icons.accessibility;
      case ClothingType.headwear:
        return Icons.face;
      case ClothingType.footwear:
        return Icons.hiking;
      case ClothingType.neckwear:
        return Icons.accessibility_new;
    }
  }
}