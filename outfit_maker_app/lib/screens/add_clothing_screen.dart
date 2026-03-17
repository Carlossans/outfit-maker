import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/image_service.dart';
import '../services/wardrobe_service.dart';
import '../models/clothing_item.dart';
import '../services/bg_removal_service.dart';
import 'clothing_multi_angle_capture_screen.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  File? imageFile;

  final ImageService imageService = ImageService();
  final nameController = TextEditingController();
  final sizeController = TextEditingController();
  ClothingType selectedType = ClothingType.top; // Valor por defecto

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
    // Continuar con el flujo simple existente
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
    if (imageFile == null) return;

    // CORREGIDO: Usar path_provider para obtener directorio temporal
    final tempDir = await getTemporaryDirectory();
    final String tempPath =
        "${tempDir.path}/transparent_${DateTime.now().millisecondsSinceEpoch}.png";

    final bgService = BgRemovalService();

    final result = await bgService.removeBackground(imageFile!, tempPath);

    if (result == null) {
      debugPrint("No se pudo eliminar el fondo");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la imagen')),
        );
      }
      return;
    }

    // CORRECCIÓN: Usar ClothingType correctamente
    final item = ClothingItem(
      id: DateTime.now().toString(),
      name: nameController.text.isNotEmpty ? nameController.text : "Prenda",
      category: _getCategoryFromType(selectedType),
      size: sizeController.text.isNotEmpty ? sizeController.text : "M",
      imagePath: result.path,
      assetPath: '', // Vacío porque es una imagen capturada, no un asset
      type: selectedType, // Ahora es ClothingType
    );

    await WardrobeService().addClothing(item);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Helper para convertir ClothingType a categoría string
  String _getCategoryFromType(ClothingType type) {
    switch (type) {
      case ClothingType.top:
        return "top";
      case ClothingType.bottom:
        return "bottom";
      case ClothingType.headwear:
        return "headwear";
      case ClothingType.footwear:
        return "footwear";
      case ClothingType.neckwear:
        return "neckwear";
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
        title: const Text("Añadir prenda - Simple"),
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
            if (imageFile != null) Image.file(imageFile!, height: 200),
            const SizedBox(height: 20),

            // Selector de tipo de prenda
            DropdownButtonFormField<ClothingType>(
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: "Tipo de prenda"),
              items: ClothingType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedType = value;
                  });
                }
              },
            ),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nombre de la prenda"),
            ),
            TextField(
              controller: sizeController,
              decoration: const InputDecoration(labelText: "Talla (EU)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: pickImageGallery,
              child: const Text("Seleccionar de galería"),
            ),
            ElevatedButton(
              onPressed: pickImageCamera,
              child: const Text("Usar cámara"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveClothing,
              child: const Text("Guardar prenda"),
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