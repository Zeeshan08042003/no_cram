import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../screens/message_bubble.dart';

/// ───────────────── IMAGE ONLY ─────────────────

Future<void> downloadImageOnly({
  Uint8List? imageBytes,
  String? imageUrl,
}) async {
  if (!await requestSavePermission()) return;

  Uint8List bytes;

  // 1️⃣ IMAGE BYTES (LIVE CHAT)
  if (imageBytes != null && imageBytes.isNotEmpty) {
    bytes = imageBytes;
  }

  // 2️⃣ IMAGE URL (HISTORY)
  else if (imageUrl != null && imageUrl.isNotEmpty) {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Failed to download image');
    }

    bytes = response.bodyBytes;
  }

  // 3️⃣ INVALID SOURCE
  else {
    throw Exception('Invalid image source');
  }

  // 🔥 SAVE — MUST END WITH .png or .jpg
  await SaverGallery.saveImage(
    bytes,
    fileName: 'ai_image_${DateTime.now().millisecondsSinceEpoch}.png',
    androidRelativePath: 'Pictures/AI Images',
    skipIfExists: true,
  );
}


/// ───────────────── IMAGE + TEXT ─────────────────

Future<void> downloadImageWithText({
  Uint8List? imageBytes,
  String? imageUrl,
  required String text,
}) async {
  if (!await requestSavePermission()) return;

  try {
    // ✅ ALWAYS NORMALIZE FIRST
    final safeBytes = await normalizeImageBytes(
      bytes: imageBytes,
      imageUrl: imageUrl,
    );

    final buffer = await ui.ImmutableBuffer.fromUint8List(safeBytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(uiImage, Offset.zero, Paint());

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 6,
      ellipsis: '...',
    );

    textPainter.layout(
      maxWidth: uiImage.width.toDouble() - 40,
    );

    final bgRect = Rect.fromLTWH(
      20,
      uiImage.height - textPainter.height - 50,
      uiImage.width.toDouble() - 40,
      textPainter.height + 24,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(14)),
      Paint()..color = Colors.black.withOpacity(0.55),
    );

    textPainter.paint(
      canvas,
      Offset(32, uiImage.height - textPainter.height - 38),
    );

    final picture = recorder.endRecording();
    final composedImage =
    await picture.toImage(uiImage.width, uiImage.height);

    final byteData =
    await composedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) throw Exception('Failed to encode image');

    await SaverGallery.saveImage(
      byteData.buffer.asUint8List(),
      fileName: 'ai_image_text_${DateTime.now().millisecondsSinceEpoch}',
      androidRelativePath: 'Pictures/AI Images',
      skipIfExists: true,
    );
  } catch (e) {
    debugPrint('DOWNLOAD ERROR: $e');
    Get.snackbar(
      'Error',
      'Failed to download image',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}



/// ALWAYS returns valid image bytes or throws
Future<Uint8List> normalizeImageBytes({
  Uint8List? bytes,
  String? imageUrl,
}) async {
  // 1️⃣ Direct bytes (live chat)
  if (bytes != null && bytes.isNotEmpty) {
    return bytes;
  }

  // 2️⃣ Base64 image
  if (imageUrl != null && imageUrl.startsWith('data:image')) {
    final cleanBase64 = imageUrl.split(',').last;
    return base64Decode(cleanBase64);
  }

  // 3️⃣ Network image (history)
  if (imageUrl != null && imageUrl.startsWith('http')) {
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      return res.bodyBytes;
    }
  }

  throw Exception('Invalid image source');
}
