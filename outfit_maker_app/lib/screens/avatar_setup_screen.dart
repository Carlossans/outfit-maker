import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../services/avatar_storage_service.dart';
import '../models/user_measurements.dart';
import 'home_screen.dart';

/// Pantalla simplificada para configurar el avatar del usuario
class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({super.key});

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  File? userImage;
  bool _isSaving = false;

  final ImageService _imageService = ImageService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  // Controladores para medidas
  final heightController = TextEditingController(text: '170');
  final weightController = TextEditingController(text: '70');
  final shouldersController = TextEditingController(text: '45');
  final waistController = TextEditingController(text: '80');

  Future<void> _takePhoto() async {
    final file = await _imageService.pickFromCamera();
    if (file != null) {
      setState(() => userImage = file);
    }
  }

  Future<void> _selectFromGallery() async {
    final file = await _imageService.pickFromGallery();
    if (file != null) {
      setState(() => userImage = file);
    }
  }

  Future<void> _saveAndContinue() async {
    if (userImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, sube una foto primero')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final measurements = UserMeasurements(
        height: double.tryParse(heightController.text) ?? 170,
        weight: double.tryParse(weightController.text) ?? 70,
        shoulders: double.tryParse(shouldersController.text) ?? 45,
        waist: double.tryParse(waistController.text) ?? 80,
      );

      await _avatarStorage.saveAvatar(
        avatarImage: userImage!,
        measurements: measurements,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
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
    heightController.dispose();
    weightController.dispose();
    shouldersController.dispose();
    waistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear tu Avatar'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📸 Instrucciones para la foto:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('• Foto de cuerpo entero (cabeza a pies)'),
                  Text('• Estar de pie, de frente'),
                  Text('• Fondo claro y simple'),
                  Text('• Buena iluminación'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preview de la imagen
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: userImage != null
                    ? Border.all(color: Colors.green, width: 2)
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: userImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(userImage!, fit: BoxFit.contain),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Toca para subir foto',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
            ),

            if (userImage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Foto cargada',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Botones de foto
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Formulario de medidas
            const Text(
              'Tus medidas (cm)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Introduce tus medidas manualmente',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    controller: heightController,
                    label: 'Altura (cm)',
                    icon: Icons.height,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMeasurementField(
                    controller: weightController,
                    label: 'Peso (kg)',
                    icon: Icons.monitor_weight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    controller: shouldersController,
                    label: 'Hombros (cm)',
                    icon: Icons.accessibility,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMeasurementField(
                    controller: waistController,
                    label: 'Cintura (cm)',
                    icon: Icons.straighten,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botón continuar
            ElevatedButton(
              onPressed: _isSaving || userImage == null ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Crear Avatar', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
