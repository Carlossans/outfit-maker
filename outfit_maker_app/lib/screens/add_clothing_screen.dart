import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../services/wardrobe_service.dart';
import '../models/clothing_item.dart';
import 'clothing_multi_angle_capture_screen.dart';

/// Pantalla simplificada para añadir prendas al armario
class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  File? imageFile;
  bool _isSaving = false;

  final ImageService imageService = ImageService();
  final nameController = TextEditingController();
  final sizeController = TextEditingController();
  ClothingType selectedType = ClothingType.top;

  @override
  void initState() {
    super.initState();
    // Navegar automáticamente a la captura multi-ángulo al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCaptureOptions();
    });
  }

  void _showCaptureOptions() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.camera_enhance, size: 48, color: Colors.purple),
            const SizedBox(height: 16),
            const Text(
              'Añadir Prenda',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige cómo quieres capturar tu prenda:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToMultiAngleCapture();
              },
              icon: const Icon(Icons.panorama),
              label: const Text('Captura Multi-Ángulo (Recomendado)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showSimpleCapture();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Captura Simple (1 foto)'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMultiAngleCapture() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClothingMultiAngleCaptureScreen(
          initialType: selectedType,
        ),
      ),
    );

    if (result == true) {
      Navigator.pop(context);
    }
  }

  void _showSimpleCapture() {
    // El formulario simple se muestra directamente
  }

  Future<void> pickImageGallery() async {
    final file = await imageService.pickFromGallery();
    if (file != null) setState(() => imageFile = file);
  }

  Future<void> pickImageCamera() async {
    final file = await imageService.pickFromCamera();
    if (file != null) setState(() => imageFile = file);
  }

  Future<void> saveClothing() async {
    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.isNotEmpty ? nameController.text : 'Prenda',
        category: selectedType.displayName,
        size: sizeController.text.isNotEmpty ? sizeController.text : 'M',
        imagePath: imageFile!.path,
        type: selectedType,
        createdAt: DateTime.now(),
      );

      await WardrobeService().addClothing(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenda guardada exitosamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir prenda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
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
                      'Estás usando modo simple. Para mejores resultados, usa captura multi-ángulo.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preview de imagen
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(imageFile!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Sin imagen seleccionada',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Selector de tipo de prenda
            DropdownButtonFormField<ClothingType>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo de prenda',
                border: OutlineInputBorder(),
              ),
              items: ClothingType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.icon),
                      const SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la prenda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: sizeController,
              decoration: const InputDecoration(
                labelText: 'Talla (EU)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImageGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImageCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : saveClothing,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar prenda'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToMultiAngleCapture();
              },
              icon: const Icon(Icons.panorama),
              label: const Text('Cambiar a captura multi-ángulo'),
            ),
          ],
        ),
      ),
    );
  }
}
