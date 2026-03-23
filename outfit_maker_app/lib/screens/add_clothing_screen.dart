import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../services/app_services.dart';
import '../models/app_models.dart';

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
  final colorController = TextEditingController();
  ClothingCategory selectedCategory = ClothingCategory.tops;

  Future<void> _pickImageGallery() async {
    final file = await imageService.pickFromGallery();
    if (file != null) setState(() => imageFile = file);
  }

  Future<void> _pickImageCamera() async {
    final file = await imageService.pickFromCamera();
    if (file != null) setState(() => imageFile = file);
  }

  Future<void> _saveClothing() async {
    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre para la prenda')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Guardar imagen permanentemente
      final savedPath = await ImageService().saveClothingImage(imageFile!);

      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        category: selectedCategory,
        imagePath: savedPath ?? imageFile!.path,
        color: colorController.text.trim().isNotEmpty ? colorController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await WardrobeService().addItem(item);

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
    colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir prenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview de imagen
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: imageFile != null ? Colors.green : Colors.grey.shade300,
                  width: imageFile != null ? 2 : 1,
                ),
              ),
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(imageFile!, fit: BoxFit.contain),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Toca para añadir foto',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Botones de imagen
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Selector de categoría
            DropdownButtonFormField<ClothingCategory>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: ClothingCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Nombre de la prenda
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la prenda',
                hintText: 'Ej: Camiseta azul',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Color de la prenda
            TextField(
              controller: colorController,
              decoration: const InputDecoration(
                labelText: 'Color (opcional)',
                hintText: 'Ej: Azul marino',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.palette_outlined),
              ),
            ),
            const SizedBox(height: 32),

            // Botón guardar
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveClothing,
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
