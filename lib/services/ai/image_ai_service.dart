import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class ImageAIService {
  
  /// Handle illustration prompt - checks if there are uploaded images and routes accordingly
  Future<void> handleIllustrationPrompt(String userInput) async {
    final controller = Get.find<ChatController>();
    
    // Check if user has uploaded reference images
    if (controller.selectedImageBytesList.isNotEmpty) {
      // Route to image-based illustration generation
      await _handleIllustrationWithReferenceImages(userInput);
    } else {
      // Route to text-only illustration generation
      await _handleTextOnlyIllustration(userInput);
    }
  }
  
  /// Generate illustration based on uploaded reference images + text prompt
  Future<void> _handleIllustrationWithReferenceImages(String userInput) async {
    final controller = Get.find<ChatController>();
    final cfg = getConfigDefaults();
    var pref = await SharedPreferences.getInstance();
    var userId = pref.getString('userId');
    
    // Get all selected images before clearing
    final referenceImageBytesList = List<Uint8List>.from(controller.selectedImageBytesList);
    final imageCount = referenceImageBytesList.length;
    
    /// 1️⃣ Add user message with reference images
    controller.messages.add(
      FBChatItem.user(
        prompt: userInput,
        mode: ChatMode.illustration.key,
        imageBytesList: referenceImageBytesList,
      ),
    );
    controller.textController.clear();
    controller.clearImages(); // Clear selected images after capturing
    controller.scrollToBottom();
    
    /// 2️⃣ Loading UI
    final loadingIndex = controller.messages.length;
    controller.messages.add(
      FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: 'Analyzing ${imageCount > 1 ? "$imageCount images" : "the image"} and creating an illustration based on your request...',
      ),
    );
    controller.scrollToBottom();
    
    final imageModelName = cfg.imageValue?.model?.trim().isNotEmpty == true
        ? cfg.imageValue!.model!.trim()
        : 'gemini-3-pro-image-preview';
    
    try {
      /// 3️⃣ First, analyze the reference images with Gemini to understand context
      final analysisModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );
      
      // Build content parts with all reference images
      final analysisPrompt = '''
You are an expert at analyzing images and extracting key visual and conceptual elements. 
Analyze the following image(s) and extract:
1. Main subjects/objects in the image
2. Key colors and color palette
3. Art style (if apparent)
4. Important details or features
5. Overall theme or concept

User's request for the illustration: "$userInput"

Based on your analysis and the user's request, create a detailed, vivid prompt for generating an illustration that:
- Is inspired by the content/style of the reference image(s)
- Incorporates the user's specific request: "$userInput"
- Describes the illustration in detail including style, colors, composition, and mood
- Output ONLY the illustration prompt, nothing else.
''';
      
      final analysisParts = <Part>[TextPart(analysisPrompt)];
      for (final bytes in referenceImageBytesList) {
        analysisParts.add(InlineDataPart('image/jpeg', bytes));
      }
      
      final analysisResponse = await analysisModel.generateContent([
        Content.multi(analysisParts)
      ]);
      
      final enhancedPrompt = analysisResponse.text ?? userInput;
      print('📝 Enhanced prompt from image analysis: $enhancedPrompt');
      
      /// 4️⃣ Generate illustration using the enhanced prompt
      final imgModel = FirebaseAI.googleAI().imagenModel(model: imageModelName);
      final response = await imgModel.generateImages(enhancedPrompt);
      
      if (response.images == null || response.images!.isEmpty) {
        throw Exception("No images generated");
      }
      
      /// 5️⃣ Get explanation for the generated illustration
      final baseExplainPrompt = "Explain this illustration in a simple and clear way. Describe what's shown and how it relates to the user's request: '$userInput'. Keep it to 10-15 lines.";
      
      final explainResponse = await analysisModel.generateContent([
        Content.multi([
          TextPart(baseExplainPrompt),
          InlineDataPart('image/jpeg', response.images[0].bytesBase64Encoded),
        ])
      ]);
      
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
      final List<String> referenceUrls = await StorageService().uploadMultipleImages(
        bytesList: referenceImageBytesList,
        userId: userId ?? '',
        folder: 'illustration_references',
      );
      
      /// 8️⃣ Upload generated images to Firebase Storage
      final List<String> generatedUrls = [];
      for (final bytes in generatedImageBytesList) {
        final url = await StorageService().uploadImageBytes(
          bytes: bytes,
          userId: userId ?? '',
        );
        generatedUrls.add(url);
      }
      
      /// 9️⃣ CREATE CHAT ITEM WITH USER INPUT (including reference images) AND AI OUTPUT
      final chatItem = FBChatItem(
        id: '', // Will be assigned by FirestoreService
        createdAt: DateTime.now(),
        mode: ChatMode.illustration.key,
        isUserMessage: false,
        userInput: UserInput(
          prompt: userInput,
          imageUrl: referenceUrls, // Save reference image URLs
        ),
        aiOutput: AIResponse(
          text: explainResponse.text,
          imageUrls: generatedUrls,
        ),
      );
      
      final firestoreService = FirestoreService();
      
      if (controller.isFollowUp) {
        await firestoreService.addChatToConversation(
          conversationId: controller.currentConversationId.value!,
          chatItem: chatItem,
        );
        print('✅ Follow-up illustration with reference images added to conversation');
      } else {
        final conversationId = await firestoreService.createConversation(
          userId: userId ?? '',
          mode: ChatMode.illustration.key,
          chatItem: chatItem,
        );
        controller.currentConversationId.value = conversationId;
        print('✅ New illustration conversation with reference images created: $conversationId');
      }
      
      /// 🔟 Update UI
      controller.messages[loadingIndex] = FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: explainResponse.text ?? '',
        imageUrls: previewUris,
        imageBytesList: generatedImageBytesList,
      );
      
    } catch (e, st) {
      print('🔴 Illustration with reference images error: $e');
      print(st);
      
      controller.messages[loadingIndex] = FBChatItem.ai(
        mode: ChatMode.illustration.key,
        text: 'Something went wrong while creating the illustration from your images.',
      );
    }
    
    controller.scrollToBottom();
  }
  
  /// Original text-only illustration generation
  Future<void> _handleTextOnlyIllustration(String userInput) async {
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

      /// 6️⃣ CREATE CHAT ITEM WITH BOTH USER INPUT AND AI OUTPUT
      final chatItem = FBChatItem(
        id: '', // Will be assigned by FirestoreService
        createdAt: DateTime.now(),
        mode: ChatMode.illustration.key,
        isUserMessage: false,
        userInput: UserInput(prompt: userInput),
        aiOutput: AIResponse(text: explainResponse.text, imageUrls: uploadedUrls),
      );

      final firestoreService = FirestoreService();

      if (controller.isFollowUp) {
        /// 🔄 ADD TO EXISTING CONVERSATION (Follow-up)
        await firestoreService.addChatToConversation(
          conversationId: controller.currentConversationId.value!,
          chatItem: chatItem,
        );
        print('✅ Follow-up illustration added to conversation');
      } else {
        /// 🆕 CREATE NEW CONVERSATION
        final conversationId = await firestoreService.createConversation(
          userId: userId ?? '',
          mode: ChatMode.illustration.key,
          chatItem: chatItem,
        );
        controller.currentConversationId.value = conversationId;
        print('✅ New illustration conversation created: $conversationId');
      }

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

