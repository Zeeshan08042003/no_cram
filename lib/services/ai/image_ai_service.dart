import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class ImageAIService {
  Future<void> handleIllustrationPrompt(String userInput) async {
    final controller = Get.find<ChatController>();

    final cfg = getConfigDefaults();

    final systemInstruction = cfg.imageValue?.imageValue ??
        'You are an expert image prompt generator. '
            'Convert the user idea into a detailed, vivid description. '
            'Only output the description.';

    final imageModelName =
    cfg.imageValue?.model?.trim().isNotEmpty == true
        ? cfg.imageValue!.model!.trim()
        : 'gemini-3-pro-image-preview';

    /// 1️⃣ Loading UI
    final loadingIndex = controller.messages.length;
    controller.messages.add(
      FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: 'Thinking about your illustration idea...',
      ),
    );
    controller.scrollToBottom();

    try {
      /// 2️⃣ Prompt
      final finalPrompt = '''
$systemInstruction

User idea:
$userInput
''';

      /// 3️⃣ Generate images
      final imgModel =
      FirebaseAI.googleAI().imagenModel(model: imageModelName);
      final basePrompt = "Explain image in very short it should be easy to understand the image and also it should be not more than 10-15 lines";
      final response = await imgModel.generateImages(finalPrompt);
      final explainModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );

      final explainResponse = await explainModel.generateContent([
        Content.multi([
          TextPart(basePrompt),
          InlineDataPart('image/jpeg', response.images[0].bytesBase64Encoded),
        ])
      ]);
      if (response.images == null || response.images!.isEmpty) {
        throw Exception("No images generated");
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
      var pref = await SharedPreferences.getInstance();
      var userId = pref.getString('userId');
      for (final bytes in imageBytesList) {
        final url = await StorageService().uploadImageBytes(
          bytes: bytes,
          userId: userId??'',
        );
        uploadedUrls.add(url);
      }

      /// 6️⃣ SAVE USING SAME MODEL ✅
      final chat = FBChatModel(
        id: '',
        userId: userId??'',
        mode: ChatMode.illustration.key,
        createdAt: DateTime.now(),
        userInput: UserInput(prompt: userInput),
        aiOutput: AIResponse(text: explainResponse.text, imageUrls: uploadedUrls)
      );

      final docRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(); // 🔥 creates doc with ID

      await docRef.set(
        FBChatModel.toFireStore(chat, docRef.id),
      );

      /// 7️⃣ Update UI
      controller.messages[loadingIndex] = FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: explainResponse.text ?? '',
        imageUrls: previewUris,
        imageBytesList: imageBytesList,
      );
    } catch (e, st) {
      print('🔴 Illustration error: $e');
      print(st);

      controller.messages[loadingIndex] = FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: 'Something went wrong while creating the illustration.',
      );
    }

    controller.scrollToBottom();
  }
}
