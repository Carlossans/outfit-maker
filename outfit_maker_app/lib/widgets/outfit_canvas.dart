import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../services/avatar_storage_service.dart';

/// Canvas que muestra el avatar del usuario con prendas superpuestas
/// Las prendas se posicionan usando coordenadas porcentuales relativas al avatar
class OutfitCanvas extends StatefulWidget {
  final List<ClothingItem> selectedItems;
  final double? height;
  final BoxFit fit;

  const OutfitCanvas({
    super.key,
    required this.selectedItems,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  State<OutfitCanvas> createState() => _OutfitCanvasState();
}

class _OutfitCanvasState extends State<OutfitCanvas> {
  File? _avatarImage;
  bool _isLoading = true;
  Size _avatarSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarService = AvatarStorageService();
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

    // Ordenar prendas por capa
    final sortedItems = List<ClothingItem>.from(widget.selectedItems)
      ..sort((a, b) => a.position.layerOrder.compareTo(b.position.layerOrder));

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = widget.height ?? constraints.maxHeight;
        final canvasWidth = constraints.maxWidth;

        return Container(
          width: double.infinity,
          height: canvasHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Avatar del usuario
                _buildAvatarImage(canvasWidth, canvasHeight),

                // Capas de prendas
                ...sortedItems.map((item) => _buildClothingLayer(
                  item,
                  canvasWidth,
                  canvasHeight,
                )),

                // Indicador cuando no hay prendas
                if (sortedItems.isEmpty && _avatarImage != null)
                  _buildEmptyState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarImage(double canvasWidth, double canvasHeight) {
    if (_avatarImage == null) {
      // Mostrar silueta por defecto si no hay avatar
      return _buildDefaultSilhouette();
    }

    return Image.file(
      _avatarImage!,
      fit: widget.fit,
      width: canvasWidth,
      height: canvasHeight,
      errorBuilder: (_, __, ___) => _buildDefaultSilhouette(),
    );
  }

  Widget _buildClothingLayer(ClothingItem item, double canvasWidth, double canvasHeight) {
    final pos = item.position;

    // Calcular posición y tamaño basado en porcentajes del canvas
    final itemWidth = canvasWidth * pos.widthPercent;
    final itemHeight = canvasHeight * pos.heightPercent;

    // Calcular posición
    final left = (canvasWidth * pos.anchorX) - (itemWidth / 2);
    final top = (canvasHeight * pos.anchorY) - (itemHeight / 2);

    return Positioned(
      left: left,
      top: top,
      width: itemWidth,
      height: itemHeight,
      child: Transform.rotate(
        angle: pos.rotation * 3.14159 / 180,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildClothingImage(item),
          ),
        ),
      ),
    );
  }

  Widget _buildClothingImage(ClothingItem item) {
    // Intentar cargar la imagen de la prenda
    final file = File(item.imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(item),
      );
    }

    // Si es URL
    if (item.imagePath.startsWith('http')) {
      return Image.network(
        item.imagePath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(item),
      );
    }

    return _buildImagePlaceholder(item);
  }

  Widget _buildImagePlaceholder(ClothingItem item) {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.category.icon,
              style: const TextStyle(fontSize: 24),
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

  Widget _buildDefaultSilhouette() {
    return CustomPaint(
      size: const Size(200, 400),
      painter: _SimpleSilhouettePainter(),
    );
  }

  Widget _buildEmptyState() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Selecciona prendas para ver el outfit',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// Pintor simple de silueta humana para cuando no hay avatar
class _SimpleSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    final centerX = size.width / 2;

    // Cabeza
    path.addOval(Rect.fromCircle(
      center: Offset(centerX, size.height * 0.08),
      radius: size.width * 0.15,
    ));

    // Cuello
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.06,
      size.height * 0.20,
      centerX + size.width * 0.06,
      size.height * 0.26,
    ));

    // Torso
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.25,
      size.height * 0.26,
      centerX + size.width * 0.25,
      size.height * 0.55,
    ));

    // Piernas
    // Izquierda
    path.addRect(Rect.fromLTRB(
      centerX - size.width * 0.22,
      size.height * 0.55,
      centerX - size.width * 0.05,
      size.height * 0.90,
    ));
    // Derecha
    path.addRect(Rect.fromLTRB(
      centerX + size.width * 0.05,
      size.height * 0.55,
      centerX + size.width * 0.22,
      size.height * 0.90,
    ));

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Versión del canvas para mostrar un outfit guardado (estático)
class OutfitPreview extends StatelessWidget {
  final Outfit outfit;
  final double height;

  const OutfitPreview({
    super.key,
    required this.outfit,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    return OutfitCanvas(
      selectedItems: outfit.clothes,
      height: height,
    );
  }
}
