import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../services/avatar_storage_service.dart';

/// Canvas que muestra el avatar del usuario con prendas superpuestas
/// Esta versión centra el avatar, aplica una caja de referencia (avatarBox)
/// para posicionar y escalar las prendas consistentemente y garantiza
/// que todas las prendas del mismo tipo compartan escala similar.
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

    // Ordenar por layerOrder para composicion
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
                // Fondo tenue para centrar atención en el modelo
                Positioned.fill(
                  child: Container(
                    color: Colors.grey.shade50,
                  ),
                ),

                // Avatar centrado
                _buildCenteredAvatar(canvasWidth, canvasHeight),

                // Capas de prendas posicionadas relativamente a avatarBox
                ..._buildClothingLayers(sortedItems, canvasWidth, canvasHeight),

                // Mensaje cuando no hay prendas
                if (sortedItems.isEmpty) _buildEmptyState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenteredAvatar(double canvasWidth, double canvasHeight) {
    // Definimos un area de avatar (avatarBox) centrada dentro del canvas.
    // Esta caja será la referencia para posicionar/escala las prendas.
    final avatarBoxWidth = canvasWidth * 0.45; // ocupará ~45% del ancho
    final avatarBoxHeight = canvasHeight * 0.9; // y la mayoría de la altura

    final avatarBoxLeft = (canvasWidth - avatarBoxWidth) / 2;
    final avatarBoxTop = (canvasHeight - avatarBoxHeight) / 2;

    if (_avatarImage == null) {
      // Dibujar silueta dentro de avatarBox
      return Positioned(
        left: avatarBoxLeft,
        top: avatarBoxTop,
        width: avatarBoxWidth,
        height: avatarBoxHeight,
        child: Container(
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size(avatarBoxWidth, avatarBoxHeight),
            painter: _SimpleSilhouettePainter(),
          ),
        ),
      );
    }

    // Si tenemos imagen, la mostramos con BoxFit.cover dentro de avatarBox
    // y aplicamos una ligera desaturación (por encima) para que la ropa destaque.
    return Positioned(
      left: avatarBoxLeft,
      top: avatarBoxTop,
      width: avatarBoxWidth,
      height: avatarBoxHeight,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _avatarImage!,
              width: avatarBoxWidth,
              height: avatarBoxHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
            ),
          ),
          // Overlay leve para bajar contraste
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClothingLayers(List<ClothingItem> items, double canvasWidth, double canvasHeight) {
    // Avatar box reference (mismo calculo que en _buildCenteredAvatar)
    final avatarBoxWidth = canvasWidth * 0.45;
    final avatarBoxHeight = canvasHeight * 0.9;
    final avatarBoxLeft = (canvasWidth - avatarBoxWidth) / 2;
    final avatarBoxTop = (canvasHeight - avatarBoxHeight) / 2;

    // Define escalas por tipo para que todas las prendas del mismo tipo usen una escala coherente
    final Map<ClothingType, Size> typeBaseSizes = {};

    // Primer pase: calcular tamaños base (segun percentos guardados o por defecto)
    for (final item in items) {
      final pos = item.position;

      // si el item tiene tamaños percentuales válidos, adaptarlos a avatarBox
      final width = (pos.widthPercent > 0 && pos.widthPercent <= 1)
          ? avatarBoxWidth * pos.widthPercent
          : avatarBoxWidth * 0.9; // fallback ancho

      final height = (pos.heightPercent > 0 && pos.heightPercent <= 1)
          ? avatarBoxHeight * pos.heightPercent
          : avatarBoxHeight * 0.25; // fallback alto

      // guardar primer valor por tipo
      typeBaseSizes.putIfAbsent(item.type, () => Size(width, height));
    }

    // Si no hay items, no hay capas
    if (items.isEmpty) return [];

    // Construir widgets posicionado usando la avatarBox como referencia
    final layers = <Widget>[];

    for (final item in items) {
      final pos = item.position;

      // Usar el tamaño base por tipo para mantener consistencia
      final baseSize = typeBaseSizes[item.type]!;
      final itemWidth = baseSize.width;
      final itemHeight = baseSize.height;

      // Calcular anclaje relativo dentro de avatarBox
      // pos.anchorX/Y se espera en rango 0..1 relativo a avatarBox
      final anchorX = (pos.anchorX >= 0 && pos.anchorX <= 1) ? pos.anchorX : 0.5;
      final anchorY = (pos.anchorY >= 0 && pos.anchorY <= 1) ? pos.anchorY : 0.45;

      final left = avatarBoxLeft + (avatarBoxWidth * anchorX) - (itemWidth / 2);
      final top = avatarBoxTop + (avatarBoxHeight * anchorY) - (itemHeight / 2);

      layers.add(Positioned(
        left: left,
        top: top,
        width: itemWidth,
        height: itemHeight,
        child: Transform.rotate(
          angle: (pos.rotation ?? 0) * 3.14159 / 180,
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
              child: _buildClothingImage(item, itemWidth, itemHeight),
            ),
          ),
        ),
      ));
    }

    return layers;
  }

  Widget _buildClothingImage(ClothingItem item, double w, double h) {
    // Forzamos que la prenda use BoxFit.cover para rellenar su caja y mantener proporciones
    final file = File(item.imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: w,
        height: h,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(item),
      );
    }

    if (item.imagePath.startsWith('http')) {
      return Image.network(
        item.imagePath,
        fit: BoxFit.cover,
        width: w,
        height: h,
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

  Widget _buildEmptyState() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(220),
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
