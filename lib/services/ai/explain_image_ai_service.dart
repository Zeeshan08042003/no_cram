import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/credit_controller.dart';
import '../../models/chat_mode.dart';
import '../../utils/image_utils.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class ExplainImageAiService {
  /// Cached model instance — created once per session
  GenerativeModel? _cachedModel;
  final _imagePicker = ImagePicker();

  GenerativeModel _getModel(String modelName) {
    _cachedModel ??= FirebaseAI.googleAI().generativeModel(model: modelName);
    return _cachedModel!;
  }

  /// Build conversation context for follow-up questions about images
  String _buildFollowUpContext(ChatController controller, String currentQuestion) {
    final previousMessages = controller.messages;

    if (previousMessages.isEmpty) {
      return currentQuestion;
    }

    final StringBuffer context = StringBuffer();

    context.writeln('=== FOLLOW-UP IMAGE EXPLANATION CONTEXT ===');
    context.writeln('This is a follow-up question about images you previously explained.');
    context.writeln('IMPORTANT: Build on your previous explanation. Do NOT repeat details already covered.');
    context.writeln('=== PREVIOUS CONVERSATION ===');

    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER ASKED: ${msg.userInput.prompt}');
      } else {
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 400
            ? '${aiText.substring(0, 400)}...[explanation continues...]'
            : aiText;
        context.writeln('YOUR EXPLANATION: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP QUESTION ===');
    context.writeln('USER NOW ASKS: $currentQuestion');
    context.writeln('Provide an explanation that builds on what was already discussed:');

    return context.toString();
  }

  imageExplanation(String text, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    final userId = ChatController.cachedUserId ?? '';

    // Check if images are selected
    if (controller.selectedImageBytesList.isEmpty) {
      final picked = await chooseImageSourceForExplain();
      if (!picked || controller.selectedImageBytesList.isEmpty) return;
    }

    if (text.isEmpty) {
      Get.snackbar(
        'Add a question',
        'Please write what you want to know about the images, then send.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Get all selected images and compress them (FIX 3)
    final rawImageBytesList = List<Uint8List>.from(controller.selectedImageBytesList);
    final imageBytesList = await compressImagesForAI(rawImageBytesList);

    // Find the loading message index
    final loadingIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
    if (loadingIndex == -1) return;

    final conversationId = controller.currentConversationId.value;
    if (conversationId == null) return;

    controller.clearImages(); // Clear images since they are already captured in rawImageBytesList

    final cfg = getConfigDefaults();
    final modelName = cfg.explainImageValue?.model ?? 'gemini-2.5-flash';
    final isMultiImage = imageBytesList.length > 1;

    // Build prompt text
    String basePrompt;
    if (controller.isFollowUp) {
      basePrompt = _buildFollowUpContext(controller, text);
      print('[IMAGE AI] Using follow-up context (${controller.messages.length} msgs)');
    } else if (isMultiImage) {
      basePrompt = cfg.explainImageValue?.multiImagePrompt ??
          'You are a patient, clear college teacher helping a student understand content from multiple images (notes, diagrams, or handwritten work).\n\n'
          'Review ALL images together before answering — treat them as parts of one explanation unless they clearly cover different topics.\n\n'
          'Answer the student\'s question directly first, in a simple, teacher-like way. Use short paragraphs or a short bullet list. If images build on each other, briefly connect the ideas.\n\n'
          'If helpful, add 1–2 lines summarising the combined main idea of all images. Do not restate every label or reproduce raw text. Do not mention "analyzing" or "extracting" text.\n\n'
          'Keep your answer concise: maximum 3 short paragraphs, or 1 paragraph + a few bullets. Write clearly and professionally.\n\n'
          'Student question: $text';
    } else {
      basePrompt = cfg.explainImageValue?.explainImagePrompt ??
          'You are a patient, clear college teacher helping a student understand content from an image (notes, diagram, or formula).\n\n'
          'Use only what is visible in the image to answer. Do not guess or add outside knowledge unless it directly clarifies what is shown.\n\n'
          'Answer the student\'s question directly first — in a simple, teacher-like way. Use short paragraphs or a short bullet list. Focus on what actually helps the student understand, not on listing every detail.\n\n'
          'If helpful, add a 1–2 line summary of the image\'s main idea. Do not restate every label or reproduce raw text from the image. Do not mention "analyzing" or "extracting" text.\n\n'
          'Keep your answer concise: maximum 3 short paragraphs, or 1 paragraph + a few bullets. Write clearly and professionally.\n\n'
          'Student question: $text';
    }

    try {
      /// 3️⃣ GEMINI IMAGE EXPLANATION (with compressed images)
      final explainModel = _getModel(modelName);

      final contentParts = <Part>[TextPart(basePrompt)];
      for (final bytes in imageBytesList) {
        contentParts.add(InlineDataPart('image/jpeg', bytes));
      }

      final response = await explainModel.generateContent([
        Content.multi(contentParts)
      ]);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[IMAGE AI] Generation stopped or stale, discarding result.');
        return;
      }

      print('Multi-image explanation complete');

      final output = response.text ??
          "Sorry, I couldn't explain the images. Please try again.";

      /// 4️⃣ UPLOAD ORIGINAL (uncompressed) IMAGES TO FIREBASE STORAGE
      print('Uploading ${rawImageBytesList.length} images to storage...');
      final imageUrls = await StorageService().uploadMultipleImages(
        bytesList: rawImageBytesList,
        userId: userId,
        folder: 'image_explanation',
      );

      print('Uploaded ${imageUrls.length} images successfully');

      /// 5️⃣ UPDATE UI MESSAGE (Only if still on this conversation)
      if (controller.currentConversationId.value == conversationId) {
        final localIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
        if (localIndex != -1) {
          controller.messages[localIndex] = FBChatItem.ai(
            mode: ChatMode.explainImage.key,
            text: output,
          );
        }
      }

      // ✅ CONSUME CREDIT ONLY AFTER SUCCESSFUL RESPONSE
      try {
        await Get.find<CreditController>().checkAndConsumeCredit();
      } catch (_) {}

      /// 6️⃣ SAVE TO FIRESTORE
      final firestoreService = FirestoreService();
      await firestoreService.updateAiResponseInConversation(
        conversationId: conversationId,
        chatId: aiChatId,
        outputText: output,
        imageUrls: imageUrls,
      );
      print('✅ AI response updated in Firestore with imageUrls');
    } catch (e, st) {
      print('Gemini error in Explain Image: $e');
      print(st);

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.explainImage.key,
          text: 'Error while explaining the images.',
        );
      }
    }

    controller.scrollToBottom();
  }

  Future<bool> chooseImageSourceForExplain() async {
    var controller = Get.find<ChatController>();

    bool pickedAny = false;

    await Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                title: const Text('Use Camera', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Capture one image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () async {
                  Get.back();
                  await _captureImageFromCamera();
                  pickedAny = controller.selectedImageBytesList.isNotEmpty;
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Select up to ${ChatController.maxImageCount} images',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () async {
                  Get.back();
                  await _pickMultipleImagesFromGallery();
                  pickedAny = controller.selectedImageBytesList.isNotEmpty;
                },
              ),
            ],
          ),
        ),
      ),
    );

    return pickedAny;
  }

  /// Pick multiple images from gallery — compression happens in imageExplanation()
  Future<void> _pickMultipleImagesFromGallery() async {
    final controller = Get.find<ChatController>();
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        limit: ChatController.maxImageCount,
      );

      if (pickedFiles.isEmpty) return;

      controller.clearImages();

      final bytesList = <Uint8List>[];
      for (final file in pickedFiles) {
        final bytes = await file.readAsBytes();
        bytesList.add(bytes);
      }

      controller.addMultipleImageBytes(bytesList);
      print('[IMAGE] Picked ${pickedFiles.length} images from gallery');
    } catch (e) {
      Get.snackbar('Gallery error', 'Could not pick images from gallery: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _captureImageFromCamera() async {
    final controller = Get.find<ChatController>();
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      controller.clearImages();

      final bytes = await picked.readAsBytes();
      controller.addImageBytes(bytes);
      print('[IMAGE] Captured from camera bytes length=${bytes.length}');
    } catch (e) {
      Get.snackbar('Camera error', 'Could not capture image: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> createImageChat({
    required String userId,
    required String imageUrl,
    required String explanation,
    String? query,
    String? mode,
    String? contentType,
  }) async {
    await FirebaseFirestore.instance.collection('chats').add({
      'userId': userId,
      'query': query,
      'mode': mode,
      'contentType': 'Image',
      'userImage': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'result': {
        'imageUrl': imageUrl,
        'explanation': explanation,
      },
    });
  }
}
