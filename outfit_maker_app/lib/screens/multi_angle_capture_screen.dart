import 'dart:io';
import 'package:flutter/material.dart';
import '../models/multi_angle_avatar.dart';
import '../services/multi_angle_capture_service.dart';
import '../services/image_service.dart';
import '../services/avatar_storage_service.dart';
import '../models/user_measurements.dart';
import 'home_screen.dart';

/// Pantalla para capturar el avatar desde múltiples ángulos
/// Guía al usuario para tomar fotos de frente, lado y trasera
class MultiAngleCaptureScreen extends StatefulWidget {
  final UserMeasurements measurements;

  const MultiAngleCaptureScreen({
    super.key,
    required this.measurements,
  });

  @override
  State<MultiAngleCaptureScreen> createState() => _MultiAngleCaptureScreenState();
}

class _MultiAngleCaptureScreenState extends State<MultiAngleCaptureScreen> {
  final MultiAngleCaptureService _captureService = MultiAngleCaptureService();
  final ImageService _imageService = ImageService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  // Estado de captura para cada ángulo
  final Map<AvatarAngle, File?> _capturedImages = {};
  final Map<AvatarAngle, bool> _isValidating = {};
  final Map<AvatarAngle, String?> _validationErrors = {};

  AvatarAngle _currentAngle = AvatarAngle.front;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Inicializar mapas
    for (final angle in AvatarAngle.values) {
      _capturedImages[angle] = null;
      _isValidating[angle] = false;
      _validationErrors[angle] = null;
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
      _isValidating[_currentAngle] = true;
      _validationErrors[_currentAngle] = null;
    });

    final result = await _captureService.validateAngle(file, _currentAngle);

    setState(() {
      _isValidating[_currentAngle] = false;
    });

    if (!result.isValid) {
      setState(() {
        _validationErrors[_currentAngle] = result.message;
      });

      // Mostrar error
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('Ajusta la posición'),
              ],
            ),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Foto válida
    setState(() {
      _capturedImages[_currentAngle] = file;
      _validationErrors[_currentAngle] = null;
    });

    // Mostrar éxito
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${result.message}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _goToNextAngle() {
    setState(() {
      _currentAngle = _currentAngle.next;
    });
  }

  void _goToPreviousAngle() {
    setState(() {
      _currentAngle = _currentAngle.previous;
    });
  }

  Future<void> _saveAvatar() async {
    // Si la app requiere multi-ángulo, validar que estén todas las vistas
    if (AvatarStorageService.requireMultiAngleSetup) {
      final missing = AvatarAngle.values.where((a) => _capturedImages[a] == null).toList();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Faltan vistas: ${missing.map((m) => m.displayName).join(', ')}. Captura todas para continuar.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Verificar que al menos tengamos la vista frontal
      if (_capturedImages[AvatarAngle.front] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Necesitas al menos la foto de frente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      // Guardar imágenes de cada ángulo
      String? frontPath;
      String? rightSidePath;
      String? backPath;
      String? leftSidePath;

      if (_capturedImages[AvatarAngle.front] != null) {
        frontPath = await _avatarStorage.saveAngleImage(
          _capturedImages[AvatarAngle.front]!,
          AvatarAngle.front,
        );
      }

      if (_capturedImages[AvatarAngle.rightSide] != null) {
        rightSidePath = await _avatarStorage.saveAngleImage(
          _capturedImages[AvatarAngle.rightSide]!,
          AvatarAngle.rightSide,
        );
      }

      if (_capturedImages[AvatarAngle.back] != null) {
        backPath = await _avatarStorage.saveAngleImage(
          _capturedImages[AvatarAngle.back]!,
          AvatarAngle.back,
        );
      }

      if (_capturedImages[AvatarAngle.leftSide] != null) {
        leftSidePath = await _avatarStorage.saveAngleImage(
          _capturedImages[AvatarAngle.leftSide]!,
          AvatarAngle.leftSide,
        );
      }

      // Crear objeto multi-ángulo
      final multiAngleAvatar = MultiAngleAvatar(
        frontImagePath: frontPath!,
        rightSideImagePath: rightSidePath,
        backImagePath: backPath,
        leftSideImagePath: leftSidePath,
        sideImagePath: rightSidePath, // Legacy compatibility
        createdAt: DateTime.now(),
        metadata: {
          'hasCompleteViews': rightSidePath != null && backPath != null && leftSidePath != null,
          'capturedAngles': _capturedImages.entries
              .where((e) => e.value != null)
              .map((e) => e.key.name)
              .toList(),
        },
      );

      // Guardar avatar principal (usar frontal como principal)
      await _avatarStorage.saveAvatar(
        avatarImage: _capturedImages[AvatarAngle.front]!,
        measurements: widget.measurements,
        multiAngleAvatar: multiAngleAvatar,
      );

      // Guardar referencias de ángulos
      await _avatarStorage.saveMultiAngleAvatar(multiAngleAvatar);

      if (mounted) {
        // Navegar a HomeScreen
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
    _captureService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentImage = _capturedImages[_currentAngle] != null;
    final isValidating = _isValidating[_currentAngle] ?? false;
    final error = _validationErrors[_currentAngle];

    // Contar vistas completadas
    final completedViews = _capturedImages.values.where((f) => f != null).length;
    final totalViews = AvatarAngle.values.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura Multi-Ángulo'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressStep(AvatarAngle.front, completedViews >= 1),
                    _buildProgressLine(completedViews >= 2),
                    _buildProgressStep(AvatarAngle.rightSide, completedViews >= 2),
                    _buildProgressLine(completedViews >= 3),
                    _buildProgressStep(AvatarAngle.back, completedViews >= 3),
                    _buildProgressLine(completedViews >= 4),
                    _buildProgressStep(AvatarAngle.leftSide, completedViews >= 4),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedViews de $totalViews vistas completadas',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título del ángulo actual
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_currentAngle.icon} Vista ${_currentAngle.displayName}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAngle.description,
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Preview de la imagen
                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: error != null
                          ? Border.all(color: Colors.red, width: 2)
                          : hasCurrentImage
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
                    ),
                    child: isValidating
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Analizando posición...'),
                              ],
                            ),
                          )
                        : hasCurrentImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _capturedImages[_currentAngle]!,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Toma una foto de ${_currentAngle.displayName.toLowerCase()}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),

                  // Mensaje de error
                  if (error != null)
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
                              error,
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Indicador de éxito
                  if (hasCurrentImage && error == null)
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
                            '✓ Vista ${_currentAngle.displayName} capturada correctamente',
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📋 Instrucciones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...AngleGuidelines.getInstructions(_currentAngle).map(
                          (instruction) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(child: Text(instruction)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botones de navegación
                  Row(
                    children: [
                      // Botón anterior
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _goToPreviousAngle,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botón siguiente
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasCurrentImage ? _goToNextAngle : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Siguiente'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botones de captura
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isValidating ? null : _capturePhoto,
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
                          onPressed: isValidating ? null : _selectFromGallery,
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
                  Builder(
                    builder: (context) {
                      final canSave = AvatarStorageService.requireMultiAngleSetup
                          ? completedViews == totalViews
                          : (_capturedImages[AvatarAngle.front] != null);

                      return ElevatedButton(
                        onPressed: (canSave && !_isSaving) ? _saveAvatar : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: canSave ? Colors.green : Colors.orange,
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
                            : Column(
                                children: [
                                  Text(
                                    completedViews == totalViews
                                        ? 'Guardar Avatar Completo'
                                        : 'Guardar Avatar',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  if (completedViews < totalViews)
                                    Text(
                                      '($completedViews/$totalViews vistas)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(AvatarAngle angle, bool isCompleted) {
    final isCurrent = angle == _currentAngle;
    final color = isCompleted
        ? Colors.green
        : isCurrent
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: () {
        setState(() => _currentAngle = angle);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isCurrent
              ? Border.all(color: Colors.white, width: 3)
              : null,
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: color.withAlpha(100),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white)
              : Text(
                  angle.icon,
                  style: const TextStyle(fontSize: 24),
                ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(bool isCompleted) {
    return Container(
      width: 40,
      height: 4,
      color: isCompleted ? Colors.green : Colors.grey.shade300,
    );
  }
}
