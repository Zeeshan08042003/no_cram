import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses image bytes before sending to Gemini API.
/// Reduces image size by ~50–80% while keeping visual quality sufficient for AI.
/// Max dimension: 1024px. Quality: 75%.
Future<Uint8List> compressImageForAI(Uint8List bytes) async {
  try {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
    );
    final originalKb = (bytes.length / 1024).toStringAsFixed(0);
    final compressedKb = (compressed.length / 1024).toStringAsFixed(0);
    print('[IMAGE_COMPRESS] ${originalKb}KB → ${compressedKb}KB');
    return compressed;
  } catch (e) {
    // If compression fails, return original bytes rather than crashing
    print('[IMAGE_COMPRESS] Compression failed, using original: $e');
    return bytes;
  }
}

/// Compresses a list of image bytes in parallel.
Future<List<Uint8List>> compressImagesForAI(List<Uint8List> bytesList) async {
  return await Future.wait(bytesList.map(compressImageForAI));
}
