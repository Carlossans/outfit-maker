import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import 'clothing_card.dart';

class ClothingCarousel extends StatelessWidget {
  final List<ClothingItem> items;
  final Function(ClothingItem)? onItemSelected;
  final String? title;

  const ClothingCarousel({
    super.key,
    required this.items,
    this.onItemSelected,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        SizedBox(
          height: 180,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No hay prendas',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 120,
                        child: GestureDetector(
                          onTap: () => onItemSelected?.call(item),
                          child: ClothingCard(item: item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
