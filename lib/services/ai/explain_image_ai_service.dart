import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_mode.dart';
import '../../utils/constants.dart';
import '../firebase/firebase_config.dart';
import '../firebase/firestore_service.dart';

class ExplainImageAiService {

  /// Build conversation context for follow-up questions about images
  String _buildFollowUpContext(ChatController controller, String currentQuestion) {
    final previousMessages = controller.messages;
    
    if (previousMessages.isEmpty) {
      return currentQuestion;
    }

    final StringBuffer context = StringBuffer();
    
    context.writeln('''
=== FOLLOW-UP IMAGE EXPLANATION CONTEXT ===
This is a follow-up question about images you previously explained.
IMPORTANT INSTRUCTIONS:
1. Continue from your previous explanation - do not start from scratch
2. Do NOT repeat details already explained
3. Go deeper into the specific aspect the user is asking about
4. Reference the images you already analyzed
5. Connect new explanations to what was already discussed
6. Be specific and build upon previous context

=== PREVIOUS CONVERSATION ===
''');

    for (int i = 0; i < previousMessages.length; i++) {
      final msg = previousMessages[i];
      if (msg.isUserMessage) {
        context.writeln('USER ASKED: ${msg.userInput.prompt}');
      } else {
        final aiText = msg.aiOutput?.text ?? '';
        final truncatedText = aiText.length > 500 
            ? '${aiText.substring(0, 500)}...[explanation continues...]' 
            : aiText;
        context.writeln('YOUR EXPLANATION: $truncatedText');
      }
      context.writeln('');
    }

    context.writeln('=== NEW FOLLOW-UP QUESTION ===');
    context.writeln('USER NOW ASKS: $currentQuestion');
    context.writeln('');
    context.writeln('Provide an explanation that builds on what was already discussed without repeating previous details:');

    return context.toString();
  }

  final _imagePicker = ImagePicker();

  imageExplanation(String text) async {
    var controller = Get.find<ChatController>();
    var pref = await SharedPreferences.getInstance();
    var userId = pref.getString('userId');
    
    // Check if images are selected (using list instead of single value)
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

    // Get all selected images
    final imageBytesList = List<Uint8List>.from(controller.selectedImageBytesList);

    /// 1️⃣ USER MESSAGE (with multiple images)
    /// Note: Only pass imageBytesList for live chat. imageUrlList is for history loading.
    controller.messages.add(
      FBChatItem.user(
        prompt: text,
        mode: ChatMode.explainImage.key,
        imageBytesList: imageBytesList,
      ),
    );
    controller.textController.clear();
    controller.clearImages(); // Clear all selected images
    controller.scrollToBottom();

    /// 2️⃣ LOADING MESSAGE
    final loadingIndex = controller.messages.length;
    final imageCount = imageBytesList.length;
    controller.messages.add(
      FBChatItem.ai(
        mode: ChatMode.explainImage.key,
        text: 'Analyzing ${imageCount > 1 ? "$imageCount images" : "the image"} and explaining...',
      ),
    );
    controller.scrollToBottom();

    final cfg = getConfigDefaults();
    
    // Use multi_image_prompt when multiple images are selected
    final isMultiImage = imageBytesList.length > 1;
    
    // Check if this is a follow-up question
    String basePrompt;
    if (controller.isFollowUp) {
      // For follow-up: include conversation history with special instructions
      final followUpContext = _buildFollowUpContext(controller, text);
      basePrompt = '''
You are a kind, clear college teacher helping a student understand something from images.

$followUpContext
''';
      print('[IMAGE AI] Using follow-up context with ${controller.messages.length} previous messages');
    } else {
      // For new conversation
      basePrompt = isMultiImage
          ? (cfg.explainImageValue?.multiImagePrompt ??
              '''
You are a kind, clear college teacher helping a student understand something from multiple images of notes, diagrams, or handwritten work.
Carefully review all provided images together before answering. Treat them as parts of a single explanation unless they clearly show different topics.
User question: $text
''')
          : (cfg.explainImageValue?.explainImagePrompt ??
              '''
You are a kind, clear college teacher helping a student understand something from an image of notes or a diagram.
Use only the content visible in the image to answer.
User question: $text
''');
    }

    try {
      /// 3️⃣ GEMINI IMAGE EXPLANATION (with all images)
      final explainModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );

      // Build content parts with all images
      final contentParts = <Part>[TextPart(basePrompt)];
      for (final bytes in imageBytesList) {
        contentParts.add(InlineDataPart('image/jpeg', bytes));
      }

      final response = await explainModel.generateContent([
        Content.multi(contentParts)
      ]);

      print("Object 2 - Multi-image explanation complete");

      final output = response.text ??
          "Sorry, I couldn't explain the images. Please try again.";

      /// 4️⃣ UPLOAD ALL IMAGES TO FIREBASE STORAGE
      print("Uploading ${imageBytesList.length} images to storage...");
      final imageUrls = await StorageService().uploadMultipleImages(
        bytesList: imageBytesList,
        userId: userId ?? '',
        folder: 'image_explanation',
      );

      print("Uploaded ${imageUrls.length} images successfully");

      /// 5️⃣ UPDATE UI MESSAGE
      if (loadingIndex < controller.messages.length) {
        print("Object 4 - Updating UI");

        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.explainImage.key,
          text: output,
        );

        /// 6️⃣ CREATE CHAT ITEM WITH BOTH USER INPUT AND AI OUTPUT
        final chatItem = FBChatItem(
          id: '', // Will be assigned by FirestoreService
          createdAt: DateTime.now(),
          mode: ChatMode.explainImage.key,
          isUserMessage: false,
          userInput: UserInput(
            prompt: text,
            imageUrl: imageUrls, // Save all image URLs
          ),
          aiOutput: AIResponse(text: output),
        );

        final firestoreService = FirestoreService();

        if (controller.isFollowUp) {
          /// 🔄 ADD TO EXISTING CONVERSATION (Follow-up)
          await firestoreService.addChatToConversation(
            conversationId: controller.currentConversationId.value!,
            chatItem: chatItem,
          );
          print('✅ Follow-up image explanation added to conversation');
        } else {
          /// 🆕 CREATE NEW CONVERSATION
          final conversationId = await firestoreService.createConversation(
            userId: userId ?? '',
            mode: ChatMode.explainImage.key,
            chatItem: chatItem,
          );
          controller.currentConversationId.value = conversationId;
          print('✅ New image explanation conversation created: $conversationId');
        }

        print("Object 5 - Chat saved to Firestore (conversation-based)");
      }
    } catch (e, st) {
      print('Gemini error in Explain Image: $e');
      print(st);

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = FBChatItem.ai(
          mode: ChatMode.explainImage.key,
          text: "Error while explaining the images.",
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
                leading: const Icon(Icons.photo_camera_outlined,
                    color: Colors.white),
                title: const Text(
                  'Use Camera',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Capture one image',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () async {
                  Get.back();
                  await _captureImageFromCamera();
                  pickedAny = controller.selectedImageBytesList.isNotEmpty;
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
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

  /// Pick multiple images from gallery
  Future<void> _pickMultipleImagesFromGallery() async {
    var controller = Get.find<ChatController>();
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        limit: ChatController.maxImageCount,
      );
      
      if (pickedFiles.isEmpty) return;

      // Clear existing images before adding new ones to avoid duplicates
      controller.clearImages();

      final bytesList = <Uint8List>[];
      for (final file in pickedFiles) {
        final bytes = await file.readAsBytes();
        bytesList.add(bytes);
      }
      
      controller.addMultipleImageBytes(bytesList);
      print('[IMAGE] Picked ${pickedFiles.length} images from gallery');
    } catch (e) {
      Get.snackbar(
        'Gallery error',
        'Could not pick images from gallery: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _captureImageFromCamera() async {
    var controller = Get.find<ChatController>();
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      // Clear existing images before adding new one to avoid duplicates
      controller.clearImages();

      final bytes = await picked.readAsBytes();
      controller.addImageBytes(bytes);
      print('[IMAGE] Captured from camera bytes length=${bytes.length}');
    } catch (e) {
      Get.snackbar(
        'Camera error',
        'Could not capture image: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
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
