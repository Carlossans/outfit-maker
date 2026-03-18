import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_models.dart';

/// Canvas que muestra el maniquí con prendas superpuestas
/// Las prendas se posicionan automáticamente en su zona del cuerpo correspondiente
class OutfitCanvas extends StatelessWidget {
  final List<ClothingItem> selectedItems;
  final double? height;
  final bool showSilhouette;

  const OutfitCanvas({
    super.key,
    required this.selectedItems,
    this.height,
    this.showSilhouette = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = height ?? constraints.maxHeight;
        final canvasWidth = constraints.maxWidth;

        // Área del cuerpo (maniquí) - centrada
        final bodyWidth = canvasWidth * 0.55;
        final bodyHeight = canvasHeight * 0.85;
        final bodyLeft = (canvasWidth - bodyWidth) / 2;
        final bodyTop = (canvasHeight - bodyHeight) / 2;

        return Container(
          width: double.infinity,
          height: canvasHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fondo degradado sutil
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey.shade50,
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                      ],
                    ),
                  ),
                ),

                // Silueta del cuerpo (maniquí)
                if (showSilhouette)
                  Positioned(
                    left: bodyLeft,
                    top: bodyTop,
                    width: bodyWidth,
                    height: bodyHeight,
                    child: CustomPaint(
                      size: Size(bodyWidth, bodyHeight),
                      painter: BodySilhouettePainter(),
                    ),
                  ),

                // Capas de prendas
                ..._buildClothingLayers(bodyLeft, bodyTop, bodyWidth, bodyHeight),

                // Mensaje cuando no hay prendas
                if (selectedItems.isEmpty)
                  _buildEmptyState(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildClothingLayers(
    double bodyLeft,
    double bodyTop,
    double bodyWidth,
    double bodyHeight,
  ) {
    // Ordenar por layerOrder (de menor a mayor)
    final sortedItems = List<ClothingItem>.from(selectedItems)
      ..sort((a, b) => a.category.layerOrder.compareTo(b.category.layerOrder));

    return sortedItems.map((item) {
      final zone = item.category.bodyZone;

      // Calcular posición y tamaño basado en la zona del cuerpo
      final itemWidth = bodyWidth * zone.relativeWidth;
      final itemHeight = bodyHeight * zone.relativeHeight;
      final itemLeft = bodyLeft + (bodyWidth - itemWidth) / 2;
      final itemTop = bodyTop + (bodyHeight * zone.relativeY) - (itemHeight / 2);

      return Positioned(
        left: itemLeft,
        top: itemTop,
        width: itemWidth,
        height: itemHeight,
        child: ClothingLayer(item: item),
      );
    }).toList();
  }

  Widget _buildEmptyState() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
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
          'Selecciona prendas para ver el outfit',
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

/// Widget individual para mostrar una prenda superpuesta
class ClothingLayer extends StatelessWidget {
  final ClothingItem item;

  const ClothingLayer({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _getBorderRadius(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _getBorderRadius(),
        child: _buildImage(),
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    switch (item.category) {
      case ClothingCategory.tops:
        return const BorderRadius.vertical(
          top: Radius.circular(16),
          bottom: Radius.circular(8),
        );
      case ClothingCategory.bottoms:
        return const BorderRadius.vertical(
          top: Radius.circular(8),
          bottom: Radius.circular(12),
        );
      case ClothingCategory.shoes:
        return BorderRadius.circular(10);
      case ClothingCategory.accessories:
        return BorderRadius.circular(12);
    }
  }

  Widget _buildImage() {
    final file = File(item.imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    if (item.imagePath.startsWith('http')) {
      return Image.network(
        item.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.category.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintor de silueta de cuerpo humano
class BodySilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final centerX = size.width / 2;

    // Cabeza (círculo)
    final headRadius = size.width * 0.18;
    final headCenterY = size.height * 0.08;
    path.addOval(Rect.fromCircle(
      center: Offset(centerX, headCenterY),
      radius: headRadius,
    ));

    // Cuello
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.08,
      size.height * 0.18,
      centerX + size.width * 0.08,
      size.height * 0.24,
    ));

    // Torso (trapecio suave)
    path.moveTo(centerX - size.width * 0.35, size.height * 0.24);
    path.lineTo(centerX + size.width * 0.35, size.height * 0.24);
    path.lineTo(centerX + size.width * 0.30, size.height * 0.50);
    path.lineTo(centerX - size.width * 0.30, size.height * 0.50);
    path.close();

    // Cadera
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.30,
      size.height * 0.50,
      centerX + size.width * 0.30,
      size.height * 0.55,
    ));

    // Piernas (dos rectángulos con forma)
    // Pierna izquierda
    path.moveTo(centerX - size.width * 0.28, size.height * 0.55);
    path.lineTo(centerX - size.width * 0.08, size.height * 0.55);
    path.lineTo(centerX - size.width * 0.10, size.height * 0.88);
    path.lineTo(centerX - size.width * 0.22, size.height * 0.88);
    path.close();

    // Pierna derecha
    path.moveTo(centerX + size.width * 0.08, size.height * 0.55);
    path.lineTo(centerX + size.width * 0.28, size.height * 0.55);
    path.lineTo(centerX + size.width * 0.22, size.height * 0.88);
    path.lineTo(centerX + size.width * 0.10, size.height * 0.88);
    path.close();

    // Brazos (simplificados)
    // Brazo izquierdo
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.42,
      size.height * 0.26,
      centerX - size.width * 0.36,
      size.height * 0.50,
    ));

    // Brazo derecho
    path.addRect(Rect.fromLTRB(
      centerX + size.width * 0.36,
      size.height * 0.26,
      centerX + size.width * 0.42,
      size.height * 0.50,
    ));

    // Dibujar relleno y contorno
    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vista previa estática de un outfit guardado
class OutfitPreview extends StatelessWidget {
  final Outfit outfit;
  final double height;

  const OutfitPreview({
    super.key,
    required this.outfit,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return OutfitCanvas(
      selectedItems: outfit.items,
      height: height,
    );
  }
}
