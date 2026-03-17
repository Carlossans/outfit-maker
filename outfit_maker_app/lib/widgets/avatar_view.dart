import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';

/// Widget que muestra el avatar del usuario con la ropa superpuesta
class AvatarView extends StatelessWidget {
  final File userImage;
  final List<ClothingItem> outfit;
  final List<ui.Image>? clothingImages;
  final bool isLoading;
  final VoidCallback? onRetry;

  const AvatarView({
    super.key,
    required this.userImage,
    required this.outfit,
    this.clothingImages,
    this.isLoading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen del usuario
        Image.file(
          userImage,
          fit: BoxFit.contain,
        ),
        // Overlay de ropa (si hay imágenes cargadas)
        if (clothingImages != null && clothingImages!.isNotEmpty)
          CustomPaint(
            painter: SimpleAvatarPainter(clothingImages!),
            size: Size.infinite,
          ),
      ],
    );
  }
}

/// Pintor simple para mostrar la ropa superpuesta
class SimpleAvatarPainter extends CustomPainter {
  final List<ui.Image> clothingImages;

  SimpleAvatarPainter(this.clothingImages);

  @override
  void paint(Canvas canvas, Size size) {
    if (clothingImages.isEmpty) return;

    // Dibujar cada prenda centrada
    for (int i = 0; i < clothingImages.length; i++) {
      final image = clothingImages[i];
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Calcular escala para que quepa en la pantalla
      final scale = (size.width * 0.5) / imageSize.width;
      final scaledHeight = imageSize.height * scale;

      final offset = Offset(
        (size.width - imageSize.width * scale) / 2,
        size.height * 0.2 + (i * scaledHeight * 0.3),
      );

      final srcRect = Rect.fromLTWH(
        0,
        0,
        imageSize.width,
        imageSize.height,
      );
      final dstRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        imageSize.width * scale,
        scaledHeight,
      );

      canvas.drawImageRect(image, srcRect, dstRect, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
