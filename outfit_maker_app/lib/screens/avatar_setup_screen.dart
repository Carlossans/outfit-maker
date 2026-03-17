import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../services/avatar_storage_service.dart';
import '../services/full_body_validation_service.dart';
import '../models/user_measurements.dart';
import 'home_screen.dart';
import 'advanced_multi_angle_capture_screen.dart';

class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({super.key});

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  File? userImage;
  bool _isValidating = false;
  bool _isSaving = false;
  String? _validationError;
  UserMeasurements? _extractedMeasurements;

  final ImageService _imageService = ImageService();
  final FullBodyValidationService _validationService = FullBodyValidationService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  // Controladores para medidas
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final shouldersController = TextEditingController();
  final waistController = TextEditingController();
  final chestController = TextEditingController();
  final hipsController = TextEditingController();

  Future<void> _takePhoto() async {
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

  /// Valida que la imagen sea de cuerpo entero y extrae medidas
  Future<void> _validateAndProcessImage(File file) async {
    setState(() {
      _isValidating = true;
      _validationError = null;
      _extractedMeasurements = null;
    });

    final result = await _validationService.validateFullBodyPhoto(file);

    setState(() {
      _isValidating = false;
    });

    if (!result.isValid) {
      setState(() {
        _validationError = result.errorMessage;
        userImage = null;
      });

      // Mostrar error
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Foto no válida'),
              ],
            ),
            content: Text(result.errorMessage ?? 'Error desconocido'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Foto válida - extraer medidas automáticamente
    if (result.bodyMetrics != null && result.detectedPoses != null) {
      final landmarks = result.detectedPoses!.first.landmarks;

      // Extraer medidas automáticamente
      final measurements = _validationService.extractMeasurementsFromPose(
        landmarks,
        knownHeight: double.tryParse(heightController.text),
      );

      setState(() {
        userImage = file;
        _extractedMeasurements = measurements;
        _validationError = null;

        // Actualizar campos con valores estimados
        heightController.text = measurements.height.toStringAsFixed(0);
        weightController.text = measurements.weight.toStringAsFixed(0);
        shouldersController.text = measurements.shoulders.toStringAsFixed(1);
        waistController.text = measurements.waist.toStringAsFixed(1);
        if (measurements.chest != null) {
          chestController.text = measurements.chest!.toStringAsFixed(1);
        }
        if (measurements.hips != null) {
          hipsController.text = measurements.hips!.toStringAsFixed(1);
        }
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (userImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, sube una foto de cuerpo entero primero')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Crear medidas del usuario (usar valores de los campos o los extraídos)
      final measurements = UserMeasurements(
        height: double.tryParse(heightController.text) ?? _extractedMeasurements?.height ?? 170,
        weight: double.tryParse(weightController.text) ?? _extractedMeasurements?.weight ?? 70,
        shoulders: double.tryParse(shouldersController.text) ?? _extractedMeasurements?.shoulders ?? 45,
        waist: double.tryParse(waistController.text) ?? _extractedMeasurements?.waist ?? 80,
        chest: double.tryParse(chestController.text) ?? _extractedMeasurements?.chest,
        hips: double.tryParse(hipsController.text) ?? _extractedMeasurements?.hips,
      );

      // Guardar avatar permanentemente
      await _avatarStorage.saveAvatar(
        avatarImage: userImage!,
        measurements: measurements,
      );

      if (mounted) {
        // Navegar a HomeScreen y eliminar todas las rutas anteriores
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error guardando avatar: $e');
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
    chestController.dispose();
    hipsController.dispose();
    _validationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear tu Avatar'),
        automaticallyImplyLeading: false, // No permitir volver atrás
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
                  Text('• Debe ser una foto de cuerpo entero (cabeza a pies)'),
                  Text('• Estar de pie, de frente o de lado'),
                  Text('• Fondo claro y simple'),
                  Text('• Buena iluminación'),
                  Text('• Ropa ajustada para mejor estimación de medidas'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preview de la imagen
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: _validationError != null
                    ? Border.all(color: Colors.red, width: 2)
                    : userImage != null
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
                  : userImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(userImage!, fit: BoxFit.contain),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline, size: 80, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Toca para subir foto',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
            ),

            // Indicador de estado
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
                      '✓ Cuerpo completo detectado',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                    onPressed: _isValidating ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isValidating ? null : _selectFromGallery,
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
              _extractedMeasurements != null
                  ? '✓ Medidas estimadas automáticamente. Puedes ajustarlas.'
                  : 'Introduce tus medidas manualmente o usa la foto para estimarlas',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Campos de medidas en grid
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    controller: chestController,
                    label: 'Pecho (cm) - opcional',
                    icon: Icons.accessibility_new,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMeasurementField(
                    controller: hipsController,
                    label: 'Cadera (cm) - opcional',
                    icon: Icons.accessibility,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Opciones de captura
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.panorama, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Captura Multi-Ángulo (Recomendado)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para mejores resultados en la generación de outfits, captura tu avatar desde múltiples ángulos:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAngleChip('🧍', 'Frente', true),
                      ),
                      Expanded(
                        child: _buildAngleChip('➡️', 'Lateral', true),
                      ),
                      Expanded(
                        child: _buildAngleChip('🔙', 'Trasera', true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: userImage == null
                        ? null
                        : () {
                            // Crear medidas actuales
                            final measurements = UserMeasurements(
                              height: double.tryParse(heightController.text) ??
                                  _extractedMeasurements?.height ??
                                  170,
                              weight: double.tryParse(weightController.text) ??
                                  _extractedMeasurements?.weight ??
                                  70,
                              shoulders: double.tryParse(shouldersController.text) ??
                                  _extractedMeasurements?.shoulders ??
                                  45,
                              waist: double.tryParse(waistController.text) ??
                                  _extractedMeasurements?.waist ??
                                  80,
                              chest: double.tryParse(chestController.text) ??
                                  _extractedMeasurements?.chest,
                              hips: double.tryParse(hipsController.text) ??
                                  _extractedMeasurements?.hips,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdvancedMultiAngleCaptureScreen(
                                  measurements: measurements,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.camera_enhance),
                    label: const Text('Captura Avanzada (3 ángulos)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botón continuar (captura simple)
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Crear Avatar Simple (1 foto)', style: TextStyle(fontSize: 18)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildAngleChip(String emoji, String label, bool isRecommended) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isRecommended ? Colors.purple.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isRecommended ? Colors.purple.shade800 : Colors.grey.shade700,
              fontWeight: isRecommended ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
