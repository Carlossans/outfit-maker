import 'dart:io';
import 'package:flutter/material.dart';
import '../models/multi_angle_avatar.dart';
import '../services/advanced_scanner_capture_service.dart';
import '../services/image_service.dart';
import '../services/avatar_storage_service.dart';
import '../models/user_measurements.dart';
import 'home_screen.dart';

/// Pantalla mejorada de captura multi-ángulo con guía visual tipo "scanner"
/// Proporciona feedback en tiempo real mientras el usuario se posiciona
class AdvancedMultiAngleCaptureScreen extends StatefulWidget {
  final UserMeasurements measurements;

  const AdvancedMultiAngleCaptureScreen({
    super.key,
    required this.measurements,
  });

  @override
  State<AdvancedMultiAngleCaptureScreen> createState() =>
      _AdvancedMultiAngleCaptureScreenState();
}

class _AdvancedMultiAngleCaptureScreenState
    extends State<AdvancedMultiAngleCaptureScreen> {
  final AdvancedScannerCaptureService _scannerService =
      AdvancedScannerCaptureService();
  final ImageService _imageService = ImageService();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  // Estado de captura
  final Map<AvatarAngle, File?> _capturedImages = {};
  final Map<AvatarAngle, ScannerAnalysisResult?> _analysisResults = {};

  AvatarAngle _currentAngle = AvatarAngle.front;
  bool _isSaving = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    for (final angle in AvatarAngle.values) {
      _capturedImages[angle] = null;
      _analysisResults[angle] = null;
    }
  }

  Future<void> _capturePhoto() async {
    final file = await _imageService.pickFromCamera();
    if (file != null) {
      await _analyzeCapture(file);
    }
  }

  Future<void> _selectFromGallery() async {
    final file = await _imageService.pickFromGallery();
    if (file != null) {
      await _analyzeCapture(file);
    }
  }

  Future<void> _analyzeCapture(File file) async {
    setState(() => _isAnalyzing = true);

    final result = await _scannerService.analyzeFrame(file, _currentAngle);

    setState(() {
      _isAnalyzing = false;
      _analysisResults[_currentAngle] = result;

      if (result.isSuccess) {
        _capturedImages[_currentAngle] = file;
        _showSuccessDialog(result);
      } else {
        _showErrorDialog(result);
      }
    });
  }

  void _showSuccessDialog(ScannerAnalysisResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('¡Perfecto!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: result.quality.color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(result.quality.icon, color: result.quality.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calidad: ${result.quality.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Confianza: ${(result.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(ScannerAnalysisResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Ajusta tu posición'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (result.feedback != null) ...[
              const SizedBox(height: 8),
              Text(result.feedback!),
            ],
            if (result.positioningHints.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Consejos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.positioningHints.map(
                (hint) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(hint)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _goToNextAngle() {
    setState(() => _currentAngle = _currentAngle.next);
  }

  void _goToPreviousAngle() {
    setState(() => _currentAngle = _currentAngle.previous);
  }

  Future<void> _saveAvatar() async {
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
        sideImagePath: rightSidePath,
        createdAt: DateTime.now(),
        metadata: {
          'hasCompleteViews': rightSidePath != null && backPath != null && leftSidePath != null,
          'capturedAngles': _capturedImages.entries
              .where((e) => e.value != null)
              .map((e) => e.key.name)
              .toList(),
          'captureMethod': 'advanced_scanner',
          'qualityScores': {
            for (final angle in AvatarAngle.values)
              angle.name: (_analysisResults[angle]?.confidence ?? 0.0),
          },
        },
      );

      // Guardar avatar principal
      await _avatarStorage.saveAvatar(
        avatarImage: _capturedImages[AvatarAngle.front]!,
        measurements: widget.measurements,
        multiAngleAvatar: multiAngleAvatar,
      );

      // Guardar referencias de ángulos
      await _avatarStorage.saveMultiAngleAvatar(multiAngleAvatar);

      if (mounted) {
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
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentImage = _capturedImages[_currentAngle] != null;
    final analysis = _analysisResults[_currentAngle];
    final completedViews = _capturedImages.values.where((f) => f != null).length;
    final totalViews = AvatarAngle.values.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura Avanzada Multi-Ángulo'),
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
                          '${_currentAngle.icon} ${_currentAngle.displayName}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAngle.description,
                          style: TextStyle(color: Colors.grey[700]),
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
                      border: analysis != null && !analysis.isSuccess
                          ? Border.all(color: Colors.orange, width: 2)
                          : hasCurrentImage
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
                    ),
                    child: _isAnalyzing
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

                  // Indicador de análisis
                  if (analysis != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: analysis.quality.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: analysis.quality.color.withAlpha(100)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(analysis.quality.icon, color: analysis.quality.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      analysis.message,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Calidad: ${analysis.quality.displayName} (${(analysis.confidence * 100).toStringAsFixed(0)}%)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (analysis.positioningHints.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...analysis.positioningHints.map(
                              (hint) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('💡 ', style: TextStyle(fontSize: 12)),
                                    Expanded(
                                      child: Text(
                                        hint,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                        ..._getInstructions(_currentAngle).map(
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
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _goToPreviousAngle,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          onPressed: _isAnalyzing ? null : _capturePhoto,
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
                          onPressed: _isAnalyzing ? null : _selectFromGallery,
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
                    onPressed: (_capturedImages[AvatarAngle.front] != null && !_isSaving)
                        ? _saveAvatar
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: completedViews == totalViews ? Colors.green : null,
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

  List<String> _getInstructions(AvatarAngle angle) {
    switch (angle) {
      case AvatarAngle.front:
        return [
          'De pie, mirando directamente a la cámara',
          'Brazos ligeramente separados del cuerpo',
          'Postura recta y natural',
          'Asegúrate de que se vean pies y cabeza',
          'Fondo simple y despejado',
          'Buena iluminación frontal',
        ];
      case AvatarAngle.rightSide:
        return [
          'De perfil, mostrando tu lado derecho',
          'Cuerpo completamente de lado',
          'Brazos a los lados',
          'Mira hacia tu izquierda, no a la cámara',
          'Postura recta',
          'Asegúrate de que se vea todo el cuerpo',
        ];
      case AvatarAngle.back:
        return [
          'De espaldas a la cámara',
          'Postura recta y relajada',
          'Brazos ligeramente separados',
          'Asegúrate de que se vea toda la espalda',
          'Cabeza mirando hacia adelante',
          'Pies y cabeza visibles',
        ];
      case AvatarAngle.leftSide:
        return [
          'De perfil, mostrando tu lado izquierdo',
          'Cuerpo completamente de lado',
          'Brazos a los lados',
          'Mira hacia tu derecha, no a la cámara',
          'Postura recta',
          'Asegúrate de que se vea todo el cuerpo',
        ];
    }
  }

  Widget _buildProgressStep(AvatarAngle angle, bool isCompleted) {
    final isCurrent = angle == _currentAngle;
    final color = isCompleted
        ? Colors.green
        : isCurrent
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => setState(() => _currentAngle = angle),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isCurrent ? Border.all(color: Colors.white, width: 3) : null,
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
              : Text(angle.icon, style: const TextStyle(fontSize: 24)),
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
