import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../models/multi_angle_clothing.dart';
import '../services/clothing_capture_service.dart';
import '../services/image_service.dart';
import '../services/wardrobe_service.dart';

/// Pantalla para capturar prendas desde múltiples ángulos
/// Permite capturar frente y reverso para mejorar la generación de outfits
class ClothingMultiAngleCaptureScreen extends StatefulWidget {
  final ClothingType? initialType;

  const ClothingMultiAngleCaptureScreen({
    super.key,
    this.initialType,
  });

  @override
  State<ClothingMultiAngleCaptureScreen> createState() =>
      _ClothingMultiAngleCaptureScreenState();
}

class _ClothingMultiAngleCaptureScreenState
    extends State<ClothingMultiAngleCaptureScreen> {
  final ClothingCaptureService _captureService = ClothingCaptureService();
  final ImageService _imageService = ImageService();
  final WardrobeService _wardrobeService = WardrobeService();

  // Controladores
  final nameController = TextEditingController();
  final sizeController = TextEditingController();

  // Estado
  ClothingType selectedType = ClothingType.top;
  ClothingAngle _currentAngle = ClothingAngle.front;
  File? _frontImage;
  File? _backImage;
  bool _isValidating = false;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _captureService.initialize();
    if (widget.initialType != null) {
      selectedType = widget.initialType!;
    }
  }

  Future<void> _capturePhoto() async {
    final file = await _imageService.pickFromCamera();
    if (file != null) {
      await _validateAndProcessImage(file);
    }
  }

  Future<void> _selectFromGallery() async {
    final file = await _imageService.pickFromGallery();
    if (file != null) {
      await _validateAndProcessImage(file);
    }
  }

  Future<void> _validateAndProcessImage(File file) async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final result = await _captureService.validateClothingImage(
      file,
      selectedType,
      _currentAngle,
    );

    setState(() {
      _isValidating = false;
    });

    if (!result.isValid) {
      setState(() {
        _validationError = result.message;
      });

      _showErrorDialog(result.message);
      return;
    }

    // Procesar imagen
    final processedFile = await _captureService.processClothingImage(file);

    setState(() {
      if (_currentAngle == ClothingAngle.front) {
        _frontImage = processedFile ?? file;
      } else {
        _backImage = processedFile ?? file;
      }
      _validationError = null;
    });

    // Éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ ${result.message}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Revisa la foto'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _switchAngle(ClothingAngle angle) {
    setState(() {
      _currentAngle = angle;
      _validationError = null;
    });
  }

  Future<void> _saveClothing() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas al menos la foto frontal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, da un nombre a la prenda'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Generar ID único
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Guardar prenda multi-ángulo
      final multiAngleClothing = await _captureService.saveMultiAngleClothing(
        id: id,
        name: nameController.text,
        type: selectedType,
        frontImage: _frontImage!,
        backImage: _backImage,
      );

      if (multiAngleClothing == null) {
        throw Exception('Error guardando la prenda');
      }

      // Crear ClothingItem básico para el armario
      final clothingItem = multiAngleClothing.toClothingItem(
        category: _getCategoryFromType(selectedType),
        size: sizeController.text.isNotEmpty ? sizeController.text : 'M',
      );

      // Guardar en el armario
      await _wardrobeService.addClothing(clothingItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prenda guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error guardando prenda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getCategoryFromType(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return 'top';
      case ClothingType.bottom:
        return 'bottom';
      case ClothingType.headwear:
        return 'headwear';
      case ClothingType.footwear:
        return 'footwear';
      case ClothingType.neckwear:
        return 'neckwear';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    sizeController.dispose();
    _captureService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = _currentAngle == ClothingAngle.front ? _frontImage : _backImage;
    final hasCurrentImage = currentImage != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Prenda Multi-Ángulo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de tipo
            _buildTypeSelector(),

            const SizedBox(height: 20),

            // Campos de nombre y talla
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la prenda',
                hintText: 'Ej: Camisa azul',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: sizeController,
              decoration: const InputDecoration(
                labelText: 'Talla (opcional)',
                hintText: 'Ej: M, 42, L',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Selector de ángulo
            _buildAngleSelector(),

            const SizedBox(height: 20),

            // Preview de imagen
            _buildImagePreview(currentImage, hasCurrentImage),

            // Mensaje de error
            if (_validationError != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),

            // Indicador de éxito
            if (hasCurrentImage && _validationError == null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Vista ${_currentAngle.displayName} capturada',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Instrucciones
            _buildInstructions(),

            const SizedBox(height: 20),

            // Botones de captura
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isValidating ? null : _capturePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isValidating ? null : _selectFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botón de guardar
            ElevatedButton(
              onPressed: (_frontImage != null && !_isSaving) ? _saveClothing : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _backImage != null
                          ? 'Guardar Prenda (2 vistas)'
                          : 'Guardar Prenda (1 vista)',
                      style: const TextStyle(fontSize: 18),
                    ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de prenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ClothingType.values.map((type) {
              final isSelected = selectedType == type;
              return ChoiceChip(
                label: Text(_getTypeDisplayName(type)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => selectedType = type);
                  }
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAngleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        children: [
          const Text(
            'Captura las dos vistas para mejores resultados',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAngleButton(
                  ClothingAngle.front,
                  _frontImage != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAngleButton(
                  ClothingAngle.back,
                  _backImage != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAngleButton(ClothingAngle angle, bool isCompleted) {
    final isCurrent = _currentAngle == angle;

    return InkWell(
      onTap: () => _switchAngle(angle),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.purple
              : isCompleted
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: Colors.purple.shade700, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.camera_alt,
              color: isCurrent
                  ? Colors.white
                  : isCompleted
                      ? Colors.green
                      : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              angle.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrent
                    ? Colors.white
                    : isCompleted
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
              ),
            ),
            Text(
              isCompleted ? 'Completado' : 'Pendiente',
              style: TextStyle(
                fontSize: 11,
                color: isCurrent
                    ? Colors.white70
                    : isCompleted
                        ? Colors.green.shade600
                        : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(File? currentImage, bool hasCurrentImage) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: hasCurrentImage
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: _isValidating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analizando imagen...'),
                ],
              ),
            )
          : hasCurrentImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    currentImage!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Toma una foto de la prenda',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentAngle.instruction,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInstructions() {
    final instructions = ClothingCaptureInstructions.getInstructions(
      selectedType,
      _currentAngle,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Consejos para ${_currentAngle.displayName.toLowerCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...instructions.map((instruction) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        instruction,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _getTypeDisplayName(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return 'Parte Superior';
      case ClothingType.bottom:
        return 'Parte Inferior';
      case ClothingType.headwear:
        return 'Cabeza';
      case ClothingType.footwear:
        return 'Calzado';
      case ClothingType.neckwear:
        return 'Cuello';
    }
  }
}
