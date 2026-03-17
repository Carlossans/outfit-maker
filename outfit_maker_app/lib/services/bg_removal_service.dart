import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BgRemovalService {
  // TODO: Mover a variables de entorno o configuración segura
  final String apiKey = "9BgFkFCmdo88bZFYJEF7j2dL";

  Future<File?> removeBackground(File inputImage, String outputPath) async {
    try {
      final bytes = await inputImage.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          bytes,
          filename: inputImage.path.split(Platform.pathSeparator).last,
        ),
      );

      request.headers.addAll({
        'X-Api-Key': apiKey,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final resBytes = await response.stream.toBytes();
        final file = File(outputPath);
        await file.writeAsBytes(resBytes);
        return file;
      } else {
        debugPrint('Error removing background: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception removing background: $e');
      return null;
    }
  }
}