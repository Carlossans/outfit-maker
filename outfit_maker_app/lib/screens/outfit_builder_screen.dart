import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../services/wardrobe_service.dart';
import '../services/outfit_service.dart';
import '../services/avatar_storage_service.dart';
import '../services/ai_image_generation_service.dart';
import '../services/enhanced_ai_generation_service.dart';
import '../services/advanced_ai_generation_service.dart';
import '../services/realistic_outfit_generation_service.dart';
import '../widgets/clothing_carousel.dart';
import '../ai/outfit_ai.dart';

/// Pantalla para crear outfits con el avatar como modelo de referencia
/// El usuario puede:
/// 1. Ver su avatar arriba
/// 2. Seleccionar prendas de los carruseles
/// 3. Ver cómo quedan las prendas sobre el avatar (simulado)
/// 4. Generar imagen final con IA
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  // Servicios
  final WardrobeService _wardrobeService = WardrobeService();
  final OutfitService _outfitService = OutfitService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();
  final AIImageGenerationService _aiGeneration = AIImageGenerationService();
  final EnhancedAIImageGenerationService _enhancedGeneration = EnhancedAIImageGenerationService();
  final AdvancedAIGenerationService _advancedGeneration = AdvancedAIGenerationService();
  final RealisticOutfitGenerationService _realisticGeneration = RealisticOutfitGenerationService();
  final OutfitAI _outfitAI = OutfitAI();

  // Opciones de generación
  bool _useEnhancedGeneration = true;
  bool _useAdvancedGeneration = true;
  bool _useRealisticGeneration = true; // Nueva opción para generación realista
  final String _selectedProvider = 'local'; // 'local', 'replicate', 'stability', 'openai'

  // Estado
  bool _isLoading = true;
  bool _isGenerating = false;
  File? _avatarImage;
  final List<ClothingItem> _selectedItems = [];
  File? _generatedPreview;

  // Prendas por categoría
  List<ClothingItem> _tops = [];
  List<ClothingItem> _bottoms = [];
  List<ClothingItem> _footwear = [];
  List<ClothingItem> _headwear = [];
  List<ClothingItem> _neckwear = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _wardrobeService.initialize();
    await _outfitService.initialize();

    // Cargar avatar del usuario
    final avatarFile = await _avatarStorage.getAvatarImageFile();

    // Cargar prendas por categoría
    final clothes = _wardrobeService.getClothes();

    if (mounted) {
      setState(() {
        _avatarImage = avatarFile;
        _tops = clothes.where((c) => c.type == ClothingType.top).toList();
        _bottoms = clothes.where((c) => c.type == ClothingType.bottom).toList();
        _footwear = clothes.where((c) => c.type == ClothingType.footwear).toList();
        _headwear = clothes.where((c) => c.type == ClothingType.headwear).toList();
        _neckwear = clothes.where((c) => c.type == ClothingType.neckwear).toList();
        _isLoading = false;
      });
    }
  }

  /// Añade una prenda al outfit
  void _addToOutfit(ClothingItem item) {
    setState(() {
      // Reemplazar si ya existe una del mismo tipo
      _selectedItems.removeWhere((i) => i.type == item.type);
      _selectedItems.add(item);
      _generatedPreview = null; // Resetear preview al cambiar
    });

    // Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} añadido al outfit'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _removeFromOutfit(item),
        ),
      ),
    );
  }

  /// Quita una prenda del outfit
  void _removeFromOutfit(ClothingItem item) {
    setState(() {
      _selectedItems.removeWhere((i) => i.id == item.id);
      _generatedPreview = null;
    });
  }

  /// Verifica si las prendas seleccionadas tienen vistas multi-ángulo
  Future<int> _countMultiAngleClothes() async {
    int count = 0;
    final appDir = await getApplicationDocumentsDirectory();

    for (final item in _selectedItems) {
      final clothingDir = Directory('${appDir.path}/clothing/${item.id}');
      if (await clothingDir.exists()) {
        final backFile = File('${clothingDir.path}/back.jpg');
        if (await backFile.exists()) {
          count++;
        }
      }
    }
    return count;
  }

  /// Genera la imagen con IA mostrando cómo queda el outfit
  Future<void> _generateOutfitPreview() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una prenda')),
      );
      return;
    }

    if (_avatarImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró tu avatar')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      AIGenerationResult result;

      // Contar prendas multi-ángulo para feedback
      final multiAngleCount = await _countMultiAngleClothes();
      if (multiAngleCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usando $multiAngleCount prendas con vistas múltiples para mejor precisión'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (_useRealisticGeneration) {
        // Usar el nuevo servicio de generación realista (recomendado)
        result = await _realisticGeneration.generateRealisticOutfit(
          avatarImage: _avatarImage!,
          outfitItems: _selectedItems,
        );
      } else if (_useAdvancedGeneration) {
        // Usar el servicio de generación avanzada
        _advancedGeneration.setProvider(_selectedProvider);
        result = await _advancedGeneration.generateRealisticOutfit(
          avatarImage: _avatarImage!,
          outfitItems: _selectedItems,
        );
      } else if (_useEnhancedGeneration) {
        // Usar el servicio de generación realista mejorado
        result = await _enhancedGeneration.generateHighQualityPreview(
          avatarImage: _avatarImage!,
          outfitItems: _selectedItems,
        );
      } else {
        // Usar el servicio básico
        result = await _aiGeneration.generateOutfitPreview(
          avatarImage: _avatarImage!,
          outfitItems: _selectedItems,
        );
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
          if (result.success && result.generatedImage != null) {
            _generatedPreview = result.generatedImage;
            _showGeneratedPreviewDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.errorMessage ?? 'Error generando imagen')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Muestra el diálogo con la imagen generada
  void _showGeneratedPreviewDialog() {
    if (_generatedPreview == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '¡Así te quedaría!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Imagen generada
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Image.file(_generatedPreview!, fit: BoxFit.contain),
            ),
            // Prendas aplicadas
            if (_selectedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedItems.map((item) => Chip(
                    avatar: const Icon(Icons.checkroom, size: 18),
                    label: Text(item.name),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  )).toList(),
                ),
              ),
            // Botones
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Seguir editando'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveOutfit();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar outfit'),
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

  /// Sugiere un outfit automáticamente
  void _suggestOutfit() {
    final clothes = _wardrobeService.getClothes();
    if (clothes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay prendas en el armario')),
      );
      return;
    }

    final suggestion = _outfitAI.suggestOutfit(clothes);
    setState(() {
      _selectedItems.clear();
      _selectedItems.addAll(suggestion);
      _generatedPreview = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sugerencia: ${suggestion.length} prendas seleccionadas'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _scrollToPreview(),
        ),
      ),
    );
  }

  /// Guarda el outfit actual
  Future<void> _saveOutfit() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una prenda')),
      );
      return;
    }

    // Mostrar diálogo para nombre
    final nameController = TextEditingController(
      text: 'Outfit ${_selectedItems.length} prendas',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar Outfit'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre del outfit',
            hintText: 'Ej: Outfit casual de verano',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _outfitService.saveOutfit(
        name: nameController.text.isNotEmpty
            ? nameController.text
            : 'Outfit ${_selectedItems.length} prendas',
        clothes: _selectedItems,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outfit guardado exitosamente')),
      );

      setState(() => _selectedItems.clear());
    }
  }

  void _scrollToPreview() {
    // Scroll al preview
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Outfit'),
        actions: [
          // Menú de opciones de generación
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Opciones de generación',
            onSelected: (value) {
              if (value == 'toggle_realistic') {
                setState(() => _useRealisticGeneration = !_useRealisticGeneration);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _useRealisticGeneration
                          ? 'Modo Realista Avanzado activado ✨'
                          : 'Modo Realista Avanzado desactivado',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else if (value == 'toggle_advanced') {
                setState(() => _useAdvancedGeneration = !_useAdvancedGeneration);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _useAdvancedGeneration
                          ? 'Modo IA Avanzada activado'
                          : 'Modo IA Avanzada desactivado',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else if (value == 'toggle_enhanced') {
                setState(() => _useEnhancedGeneration = !_useEnhancedGeneration);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _useEnhancedGeneration
                          ? 'Modo realista activado'
                          : 'Modo básico activado',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_realistic',
                child: Row(
                  children: [
                    Icon(
                      _useRealisticGeneration ? Icons.check_box : Icons.check_box_outline_blank,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Realista Avanzado (Recomendado) ✨'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_advanced',
                child: Row(
                  children: [
                    Icon(
                      !_useRealisticGeneration && _useAdvancedGeneration
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('IA Avanzada'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_enhanced',
                child: Row(
                  children: [
                    Icon(
                      !_useRealisticGeneration && !_useAdvancedGeneration && _useEnhancedGeneration
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Generación realista'),
                  ],
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Realista Avanzado: mejor precisión\ncon segmentación corporal y multi-ángulo',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _suggestOutfit,
            tooltip: 'Sugerir outfit',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveOutfit,
            tooltip: 'Guardar outfit',
          ),
        ],
      ),
      body: Column(
        children: [
          // SECCIÓN SUPERIOR: Avatar como modelo de referencia
          _buildAvatarSection(),

          const Divider(height: 1),

          // SECCIÓN INFERIOR: Carruseles de prendas
          Expanded(
            child: _buildClothingCarousels(),
          ),
        ],
      ),
      // Botón flotante para generar imagen con IA
      floatingActionButton: _selectedItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isGenerating ? null : _generateOutfitPreview,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGenerating ? 'Generando...' : 'Ver cómo me queda'),
            )
          : null,
    );
  }

  /// Construye la sección del avatar con las prendas seleccionadas
  Widget _buildAvatarSection() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Tu modelo de referencia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedItems.clear();
                      _generatedPreview = null;
                    }),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Limpiar'),
                  ),
              ],
            ),
          ),

          // Avatar o placeholder
          SizedBox(
            height: 280,
            child: _avatarImage != null
                ? _buildAvatarWithClothes()
                : _buildNoAvatarPlaceholder(),
          ),

          // Indicador de prendas seleccionadas
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Prendas seleccionadas: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ..._selectedItems.map((item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(item.name),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeFromOutfit(item),
                        backgroundColor: _getColorForType(item.type).withAlpha(50),
                      ),
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Muestra el avatar con indicación visual de las prendas seleccionadas
  Widget _buildAvatarWithClothes() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Imagen del avatar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _avatarImage!,
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Overlay indicando dónde van las prendas
        if (_selectedItems.isNotEmpty)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: _ClothingOverlayPainter(
                  selectedTypes: _selectedItems.map((i) => i.type).toList(),
                ),
              ),
            ),
          ),

        // Indicadores de zona
        if (_selectedItems.isNotEmpty)
          ..._buildZoneIndicators(),
      ],
    );
  }

  /// Indicadores visuales de las zonas del cuerpo
  List<Widget> _buildZoneIndicators() {
    final indicators = <Widget>[];

    for (final item in _selectedItems) {
      Offset position;
      IconData icon;

      switch (item.type) {
        case ClothingType.headwear:
          position = const Offset(0, -80);
          icon = Icons.face;
          break;
        case ClothingType.neckwear:
          position = const Offset(0, -50);
          icon = Icons.accessibility_new;
          break;
        case ClothingType.top:
          position = const Offset(0, -20);
          icon = Icons.checkroom;
          break;
        case ClothingType.bottom:
          position = const Offset(0, 40);
          icon = Icons.accessibility;
          break;
        case ClothingType.footwear:
          position = const Offset(0, 90);
          icon = Icons.directions_walk;
          break;
      }

      indicators.add(
        Positioned(
          top: 120 + position.dy,
          left: MediaQuery.of(context).size.width / 2 - 20 + position.dx,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getColorForType(item.type),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return indicators;
  }

  Color _getColorForType(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return Colors.blue;
      case ClothingType.bottom:
        return Colors.green;
      case ClothingType.footwear:
        return Colors.orange;
      case ClothingType.headwear:
        return Colors.purple;
      case ClothingType.neckwear:
        return Colors.red;
    }
  }

  /// Placeholder cuando no hay avatar
  Widget _buildNoAvatarPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No hay avatar configurado',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// Construye los carruseles de prendas por categoría
  Widget _buildClothingCarousels() {
    final hasClothes = _tops.isNotEmpty ||
        _bottoms.isNotEmpty ||
        _footwear.isNotEmpty ||
        _headwear.isNotEmpty ||
        _neckwear.isNotEmpty;

    if (!hasClothes) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay prendas en tu armario',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Añade prendas primero para crear outfits',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80), // Espacio para FAB
      children: [
        // Instrucciones
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toca una prenda para verla sobre tu avatar. '
                  'Luego pulsa "Ver cómo me queda" para generar la imagen con IA.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Carruseles por categoría
        if (_tops.isNotEmpty)
          ClothingCarousel(
            title: '👕 Parte Superior',
            items: _tops,
            onItemSelected: _addToOutfit,
          ),

        if (_bottoms.isNotEmpty)
          ClothingCarousel(
            title: '👖 Parte Inferior',
            items: _bottoms,
            onItemSelected: _addToOutfit,
          ),

        if (_footwear.isNotEmpty)
          ClothingCarousel(
            title: '👟 Calzado',
            items: _footwear,
            onItemSelected: _addToOutfit,
          ),

        if (_headwear.isNotEmpty)
          ClothingCarousel(
            title: '🧢 Sombreros y Gorras',
            items: _headwear,
            onItemSelected: _addToOutfit,
          ),

        if (_neckwear.isNotEmpty)
          ClothingCarousel(
            title: '🧣 Accesorios de Cuello',
            items: _neckwear,
            onItemSelected: _addToOutfit,
          ),
      ],
    );
  }
}

/// Pintor personalizado para mostrar overlay de prendas en el avatar
class _ClothingOverlayPainter extends CustomPainter {
  final List<ClothingType> selectedTypes;

  _ClothingOverlayPainter({required this.selectedTypes});

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar rectángulos indicando zonas según tipo de prenda
    for (final type in selectedTypes) {
      Rect zone;
      Color color;

      switch (type) {
        case ClothingType.headwear:
          zone = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.15),
            width: size.width * 0.3,
            height: size.height * 0.15,
          );
          color = Colors.purple;
          break;
        case ClothingType.neckwear:
          zone = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.25),
            width: size.width * 0.25,
            height: size.height * 0.08,
          );
          color = Colors.red;
          break;
        case ClothingType.top:
          zone = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.38),
            width: size.width * 0.5,
            height: size.height * 0.25,
          );
          color = Colors.blue;
          break;
        case ClothingType.bottom:
          zone = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.65),
            width: size.width * 0.45,
            height: size.height * 0.35,
          );
          color = Colors.green;
          break;
        case ClothingType.footwear:
          zone = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.92),
            width: size.width * 0.4,
            height: size.height * 0.12,
          );
          color = Colors.orange;
          break;
      }

      // Dibujar zona con color correspondiente
      final zonePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withAlpha(200);

      canvas.drawRect(zone, zonePaint);

      // Relleno semitransparente
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withAlpha(30);

      canvas.drawRect(zone, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
