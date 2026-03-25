import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/credit_controller.dart';
import '../../models/chat_mode.dart';
import '../../utils/image_utils.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class ImageAIService {
  
  /// Handle illustration prompt — checks if there are uploaded images and routes accordingly
  Future<void> handleIllustrationPrompt(String userInput, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    
    if (controller.selectedImageBytesList.isNotEmpty) {
      await _handleIllustrationWithReferenceImages(userInput, aiChatId: aiChatId, generationId: generationId);
    } else {
      await _handleTextOnlyIllustration(userInput, aiChatId: aiChatId, generationId: generationId);
    }
  }

  // ---------------------------------------------------------------------------
  // FIX 1: Text-only illustration — 2 calls → 1 call
  // The remote config image_prompt already contains a full Imagen prompt with
  // {{prompt}} as the placeholder. We substitute directly and call Imagen once.
  // There is no need for an intermediate Flash "enhancement" call.
  // ---------------------------------------------------------------------------
  Future<void> _handleTextOnlyIllustration(String userInput, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    final cfg = getConfigDefaults();
    final userId = ChatController.cachedUserId ?? '';

    // Fix wrong default: was 'gemini-3-pro-image-preview' (non-existent model)
    final imageModelName = cfg.imageValue?.model?.trim().isNotEmpty == true
        ? cfg.imageValue!.model!.trim()
        : 'imagen-4.0-generate-001';

    // Substitute {{prompt}} with user input in the remote config Imagen prompt
    const defaultImagePrompt =
        'Create a bright, friendly educational illustration for a middle school classroom '
        'that visually explains: {{prompt}}\n\n'
        'Style requirements:\n'
        '- Cartoon-style characters with bold outlines, vibrant colours, clean background\n'
        '- Simple visual scene or story moment — NOT a chart, diagram, or text block\n'
        '- 2–3 clearly identifiable characters or objects that each represent one key part of the concept\n'
        '- A single clear focal point — the concept should be obvious at a glance\n'
        '- Age-appropriate, safe, and classroom-friendly\n'
        '- No photorealistic human faces\n'
        '- Minimal text inside the image; only very short labels (2–4 words) if essential';

    final rawPrompt = cfg.imageValue?.imageValue?.isNotEmpty == true
        ? cfg.imageValue!.imageValue!
        : defaultImagePrompt;

    final imagePrompt = rawPrompt.replaceAll('{{prompt}}', userInput);

    /// 1️⃣ Loading UI
    final loadingIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
    if (loadingIndex == -1) return;

    final conversationId = controller.currentConversationId.value;
    if (conversationId == null) return;

    try {
      /// 2️⃣ Flash call for prompt enhancement + explanation
      final analysisModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );

      final analysisPrompt =
          'You are an expert educational illustrator helper.\n'
          'The student wants an illustration for: "$userInput"\n\n'
          'Respond in EXACTLY this format (no extra text, no markdown):\n'
          'PROMPT: [A detailed Imagen illustration prompt for a bright, friendly educational cartoon that explains "$userInput". '
          'Focus on simple characters and a clear scene. Keep it under 100 words.]\n'
          'EXPLANATION: [2–3 simple, encouraging sentences for the student explaining what the illustration shows about "$userInput".]';

      final analysisResponse = await analysisModel.generateContent([
        Content.text(analysisPrompt)
      ]);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[IMAGEN] Analysis stopped or stale, discarding result.');
        return;
      }

      final analysisText = analysisResponse.text ?? '';
      final imagenPrompt = _extractSection(analysisText, 'PROMPT:', 'EXPLANATION:') ?? imagePrompt;
      final explanation = _extractSection(analysisText, 'EXPLANATION:', null) ?? "Here is an illustration to help you understand $userInput.";

      print('📝 Enhanced Imagen prompt: $imagenPrompt');

      /// 3️⃣ Generate image with enhanced prompt
      final imgModel = FirebaseAI.googleAI().imagenModel(model: imageModelName);
      final response = await imgModel.generateImages(imagenPrompt);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[IMAGEN] Generation stopped or stale, discarding result.');
        return;
      }

      if (response.images == null || response.images!.isEmpty) {
        throw Exception('No images generated');
      }

      /// 4️⃣ Decode images
      final List<Uint8List> imageBytesList = [];
      final List<String> previewUris = [];

      for (final img in response.images!) {
        final raw = img.bytesBase64Encoded;
        if (raw == null) continue;

        final bytes = raw is Uint8List
            ? raw
            : base64Decode(raw.toString().replaceAll(RegExp(r'\s+'), ''));

        imageBytesList.add(bytes);
        previewUris.add(
          'data:${img.mimeType ?? 'image/png'};base64,${base64Encode(bytes)}',
        );
      }

      /// 5️⃣ Upload to Firebase Storage
      final List<String> uploadedUrls = [];
      for (final bytes in imageBytesList) {
        final url = await StorageService().uploadImageBytes(
          bytes: bytes,
          userId: userId,
        );
        uploadedUrls.add(url);
      }

      /// 6️⃣ Update Firestore
      final firestoreService = FirestoreService();
      await firestoreService.updateAiResponseInConversation(
        conversationId: conversationId,
        chatId: aiChatId,
        outputText: explanation,
        imageUrls: uploadedUrls,
      );

      // ✅ CONSUME CREDIT ONLY AFTER SUCCESSFUL RESPONSE
      try {
        await Get.find<CreditController>().checkAndConsumeCredit();
      } catch (_) {}

      /// 7️⃣ Update UI (Only if still on this conversation)
      if (controller.currentConversationId.value == conversationId) {
        final localIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
        if (localIndex != -1) {
          controller.messages[localIndex] = FBChatItem.ai(
            mode: ChatMode.illustration.key,
            text: explanation,
            imageUrls: previewUris,
            imageBytesList: imageBytesList,
          );
        }
      }
    } catch (e, st) {
      print('🔴 Illustration error: $e');
      print(st);

      if (loadingIndex != -1 && loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.illustration.key,
          text: 'Something went wrong while creating the illustration.',
        );
      }
    }

    controller.scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // FIX 2: Reference-image illustration — 3 calls → 2 calls
  // Combines the image analysis and explanation into a single structured Flash
  // call (PROMPT: / EXPLANATION: format), then uses the PROMPT part for Imagen.
  // FIX 3: Compresses reference images before sending to Flash.
  // ---------------------------------------------------------------------------
  Future<void> _handleIllustrationWithReferenceImages(String userInput, {required String aiChatId, required String generationId}) async {
    final controller = Get.find<ChatController>();
    final cfg = getConfigDefaults();
    final userId = ChatController.cachedUserId ?? '';

    final referenceImageBytesList = List<Uint8List>.from(controller.selectedImageBytesList);
    final imageCount = referenceImageBytesList.length;

    // Find the loading message index
    final loadingIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
    if (loadingIndex == -1) return;

    final conversationId = controller.currentConversationId.value;
    if (conversationId == null) return;

    controller.clearImages(); // Clear images since they are already captured

    final imageModelName = cfg.imageValue?.model?.trim().isNotEmpty == true
        ? cfg.imageValue!.model!.trim()
        : 'imagen-4.0-generate-001';

    try {
      /// 3️⃣ Compress reference images before sending (FIX 3)
      final compressedImages = await compressImagesForAI(referenceImageBytesList);

      /// 4️⃣ Single Flash call: analysis + prompt + explanation together (FIX 2)
      final analysisModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );

      final analysisPrompt =
          'You are an expert at analyzing educational images and creating illustration prompts.\n'
          'Analyze the provided image(s) and the user\'s request: "$userInput"\n\n'
          'Respond in EXACTLY this format (no extra text, no markdown):\n'
          'PROMPT: [A detailed Imagen illustration prompt for an educational cartoon-style illustration inspired by the images and the user\'s request. '
          'Include style, colours, characters, and composition. Keep it under 120 words.]\n'
          'EXPLANATION: [2–3 plain sentences describing what the illustration will show and how it relates to "$userInput".]';

      final analysisParts = <Part>[TextPart(analysisPrompt)];
      for (final bytes in compressedImages) {
        analysisParts.add(InlineDataPart('image/jpeg', bytes));
      }

      final analysisResponse = await analysisModel.generateContent([
        Content.multi(analysisParts)
      ]);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[IMAGEN] Analysis stopped or stale, discarding result.');
        return;
      }

      final analysisText = analysisResponse.text ?? '';

      // Parse PROMPT: and EXPLANATION: from response
      final imagenPrompt = _extractSection(analysisText, 'PROMPT:', 'EXPLANATION:') ?? userInput;
      final explanation = _extractSection(analysisText, 'EXPLANATION:', null) ?? '';

      print('📝 Imagen prompt: $imagenPrompt');
      print('📝 Explanation: $explanation');

      /// 5️⃣ Generate illustration with Imagen
      final imgModel = FirebaseAI.googleAI().imagenModel(model: imageModelName);
      final response = await imgModel.generateImages(imagenPrompt);

      // Check if generation was stopped by user or a NEW generation started
      if (!controller.isGenerating.value || controller.currentGenerationId != generationId) {
        print('[IMAGEN] Generation stopped or stale, discarding result.');
        return;
      }

      if (response.images == null || response.images!.isEmpty) {
        throw Exception('No images generated');
      }

      /// 6️⃣ Decode generated images
      final List<Uint8List> generatedImageBytesList = [];
      final List<String> previewUris = [];

      for (final img in response.images!) {
        final raw = img.bytesBase64Encoded;
        if (raw == null) continue;

        final bytes = raw is Uint8List
            ? raw
            : base64Decode(raw.toString().replaceAll(RegExp(r'\s+'), ''));

        generatedImageBytesList.add(bytes);
        previewUris.add(
          'data:${img.mimeType ?? 'image/png'};base64,${base64Encode(bytes)}',
        );
      }

      /// 7️⃣ Upload reference images to Firebase Storage
      await StorageService().uploadMultipleImages(
        bytesList: referenceImageBytesList,
        userId: userId,
        folder: 'illustration_references',
      );

      /// 8️⃣ Upload generated images to Firebase Storage
      final List<String> generatedUrls = [];
      for (final bytes in generatedImageBytesList) {
        final url = await StorageService().uploadImageBytes(
          bytes: bytes,
          userId: userId,
        );
        generatedUrls.add(url);
      }

      /// 9️⃣ Save to Firestore
      final firestoreService = FirestoreService();
      await firestoreService.updateAiResponseInConversation(
        conversationId: conversationId,
        chatId: aiChatId,
        outputText: explanation,
        imageUrls: generatedUrls,
      );

      // ✅ CONSUME CREDIT ONLY AFTER SUCCESSFUL RESPONSE
      try {
        await Get.find<CreditController>().checkAndConsumeCredit();
      } catch (_) {}

      /// 🔟 Update UI (Only if still on this conversation)
      if (controller.currentConversationId.value == conversationId) {
        final localIndex = controller.messages.indexWhere((m) => m.id == aiChatId);
        if (localIndex != -1) {
          controller.messages[localIndex] = FBChatItem.ai(
            mode: ChatMode.illustration.key,
            text: explanation,
            imageUrls: previewUris,
            imageBytesList: generatedImageBytesList,
          );
        }
      }
    } catch (e, st) {
      print('🔴 Illustration with reference images error: $e');
      print(st);

      if (loadingIndex != -1 && loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.illustration.key,
          text: 'Something went wrong while creating the illustration from your images.',
        );
      }
    }

    controller.scrollToBottom();
  }

  /// Extracts text between [startTag] and [endTag] markers.
  /// If [endTag] is null, returns everything after [startTag].
  String? _extractSection(String text, String startTag, String? endTag) {
    final startIdx = text.indexOf(startTag);
    if (startIdx == -1) return null;
    final contentStart = startIdx + startTag.length;
    if (endTag == null) {
      return text.substring(contentStart).trim();
    }
    final endIdx = text.indexOf(endTag, contentStart);
    if (endIdx == -1) return text.substring(contentStart).trim();
    return text.substring(contentStart, endIdx).trim();
  }
}
