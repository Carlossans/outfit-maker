import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import '../widgets/avatar_painter.dart';
import '../widgets/clothing_carousel.dart';
import '../models/clothing_item.dart';
import '../services/wardrobe_service.dart';
import '../services/body_segmentation.dart';
import '../services/clothing_warping.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

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
  late final PoseDetector _poseDetector;
  SelfieSegmenter? _segmenter;
  late final BodySegmentationService _bodySegmentation;
  late final ClothingWarpingService _clothingWarping;

  bool _isProcessing = true;
  List<Pose> _poses = [];
  SegmentationMask? _bodyMask;
  List<ui.Image> _clothingImages = [];
  final List<ui.Image> _warpedClothingImages = [];
  List<ClothingItem> _currentOutfit = [];
  int _selectedCategoryIndex = 0;
  bool _useWarping = false; // Toggle para warping

  // Categorías disponibles para el carrusel
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
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
      ),
    );
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.stream,
    );
    _bodySegmentation = BodySegmentationService();
    _clothingWarping = ClothingWarpingService();
    _processImage();
  }

  Future<void> _processImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFile(widget.userImage);

      // 1. Detectar pose
      _poses = await _poseDetector.processImage(inputImage);

      // 2. Segmentar cuerpo
      _bodyMask = await _segmenter?.processImage(inputImage);

      // 3. Cargar imágenes de ropa
      await _loadClothingImages();

      // 4. Aplicar warping si está habilitado
      if (_useWarping && _bodyMask != null) {
        await _applyWarpingToClothing();
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error procesando imagen: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _applyWarpingToClothing() async {
    if (_currentOutfit.isEmpty || _bodyMask == null) return;

    _warpedClothingImages.clear();

    // Obtener tamaño real de la imagen del usuario
    final bytes = await widget.userImage.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());

    for (final item in _currentOutfit) {
      if (item.imagePath.isNotEmpty) {
        final clothingFile = File(item.imagePath);
        if (await clothingFile.exists()) {
          // Obtener anchor points específicos para el tipo
          final typeAnchors = _bodySegmentation.getClothingAnchorPoints(
            _bodyMask!,
            imageSize,
            item.type,
          );

          // Aplicar warping
          final warpedFile = await _clothingWarping.warpClothingToBody(
            clothingImage: clothingFile,
            bodyAnchors: typeAnchors,
            type: item.type,
            targetSize: imageSize,
          );

          if (warpedFile != null) {
            // Cargar la imagen warpeada como ui.Image
            final warpedBytes = await warpedFile.readAsBytes();
            final warpedCodec = await ui.instantiateImageCodec(warpedBytes);
            final warpedFrame = await warpedCodec.getNextFrame();
            _warpedClothingImages.add(warpedFrame.image);
          }
        }
      }
    }
  }

  Future<void> _loadClothingImages() async {
    List<ui.Image> images = [];
    for (final item in _currentOutfit) {
      try {
        ui.Image? image = await _loadImage(item);
        if (image != null) {
          images.add(image);
        }
      } catch (e) {
        debugPrint('Error cargando imagen: $e');
      }
    }
    _clothingImages = images;
  }

  Future<ui.Image?> _loadImage(ClothingItem item) async {
    try {
      if (item.assetPath.isNotEmpty) {
        final data = await rootBundle.load(item.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return frame.image;
      } else if (item.imagePath.isNotEmpty) {
        final file = File(item.imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          return frame.image;
        }
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
    return null;
  }

  void _addClothingToOutfit(ClothingItem item) {
    setState(() {
      // Reemplazar si ya existe una prenda del mismo tipo
      _currentOutfit.removeWhere((c) => c.type == item.type);
      _currentOutfit.add(item);
    });
    _loadClothingImages();
  }

  void _removeClothingFromOutfit(ClothingType type) {
    setState(() {
      _currentOutfit.removeWhere((c) => c.type == type);
    });
    _loadClothingImages();
  }

  void _clearOutfit() {
    setState(() {
      _currentOutfit.clear();
      _clothingImages.clear();
    });
  }

  @override
  void dispose() {
    _poseDetector.close();
    _segmenter?.close();
    _bodySegmentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prueba de Ropa"),
        actions: [
          // Toggle para warping
          IconButton(
            icon: Icon(
              _useWarping ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: _useWarping ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              setState(() => _useWarping = !_useWarping);
              if (_useWarping && _bodyMask != null) {
                _applyWarpingToClothing();
              }
            },
            tooltip: 'Activar ajuste de ropa al cuerpo',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearOutfit,
            tooltip: 'Limpiar outfit',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _processImage,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Vista del avatar con ropa
          Expanded(
            flex: 3,
            child: _buildAvatarView(),
          ),

          // Indicador de outfit actual
          if (_currentOutfit.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: _currentOutfit.map((item) {
                  return Chip(
                    avatar: const Icon(Icons.checkroom, size: 18),
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
                const Text('Categoría:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            label: Text(_getCategoryName(type)),
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
              title: 'Tus ${_getCategoryName(_categories[_selectedCategoryIndex])}s',
              items: WardrobeService().getClothesByType(_categories[_selectedCategoryIndex]),
              onItemSelected: _addClothingToOutfit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarView() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando imagen...'),
          ],
        ),
      );
    }

    if (_poses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No se detectó ninguna pose',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Asegúrate de que:\n• Estés de pie\n• La foto sea de cuerpo entero\n• El fondo sea claro',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _processImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Mostrar indicador de warping si está activo
    final showWarpedImages = _useWarping && _warpedClothingImages.isNotEmpty;

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen del usuario
          Image.file(widget.userImage, fit: BoxFit.contain),

          // Overlay de segmentación corporal (debug, semi-transparente)
          if (_bodyMask != null)
            CustomPaint(
              painter: SegmentationMaskPainter(_bodyMask!),
              size: Size.infinite,
            ),

          // Overlay de ropa (warped o normal)
          CustomPaint(
            painter: AvatarPainter(
              _poses,
              showWarpedImages ? _warpedClothingImages : _clothingImages,
              _currentOutfit,
            ),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }

  String _getCategoryName(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return 'Parte Superior';
      case ClothingType.bottom:
        return 'Parte Inferior';
      case ClothingType.headwear:
        return 'Accesorio Cabeza';
      case ClothingType.footwear:
        return 'Calzado';
      case ClothingType.neckwear:
        return 'Accesorio Cuello';
    }
  }
}
