import 'dart:convert';
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
  // final _model = FirebaseAI.googleAI()
  //     .generativeModel(model: 'gemini-2.5-flash');
  //
  // Future<String> explainImage(Uint8List bytes, String prompt) async {
  //   final response = await _model.generateContent([
  //     Content.multi([
  //       TextPart(prompt),
  //       InlineDataPart('image/jpeg', bytes),
  //     ])
  //   ]);
  //
  //   return response.text ?? '';
  // }

  final _imagePicker = ImagePicker();

  imageExplanation(String text) async {
    var controller = Get.find<ChatController>();
    var pref = await SharedPreferences.getInstance();
    var userId = pref.getString('userId');
    if (controller.selectedImageBytes.value == null) {
      final picked = await chooseImageSourceForExplain();
      if (!picked || controller.selectedImageBytes.value == null) return;
    }

    if (text.isEmpty) {
      Get.snackbar(
        'Add a question',
        'Please write what you want to know about the image, then send.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }


    final bytes = controller.selectedImageBytes.value!;
    final base64Image = base64Encode(bytes);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

    /// 1️⃣ USER MESSAGE
    controller.messages.add(
      ChatMessage(
        text: text,
        isUser: true,
        mode: ChatMode.explainImage,
        imageUrl: dataUri,
      ),
    );
    controller.textController.clear();
    controller.selectedImageBytes.value = null;
    controller.scrollToBottom();

    /// 2️⃣ LOADING MESSAGE
    final loadingIndex = controller.messages.length;
    controller.messages.add(
      ChatMessage(
        text: 'Analyzing the image and explaining it...',
        imageText: 'Analyzing the image and explaining it...',
        isUser: false,
        mode: ChatMode.explainImage,
      ),
    );
    controller.scrollToBottom();

    final cfg = getConfigDefaults();
    final basePrompt = cfg.explainImageValue?.explainImagePrompt ??
        '''
You are a kind, clear college teacher helping a student understand an image.
Explain clearly and step-by-step.
''';

    try {
      /// 3️⃣ GEMINI IMAGE EXPLANATION
      final explainModel = FirebaseAI.googleAI().generativeModel(
        model: cfg.explainImageValue?.model ?? 'gemini-2.5-flash',
      );

      final response = await explainModel.generateContent([
        Content.multi([
          TextPart(basePrompt),
          InlineDataPart('image/jpeg', bytes),
        ])
      ]);

      print("Object 2");

      final output = response.text ??
          "Sorry, I couldn't explain this image. Please try another one.";

      var file = await Constants().bytesToFile(bytes);
      /// 4️⃣ UPLOAD IMAGE TO FIREBASE STORAGE
      ///
      print("print the data : ${file.absolute}");
      var imageUrl = await StorageService().uploadImage(
        file, userId??'',
      );

      print("print the data 2 : ${imageUrl}");

      print("Object 3");

      /// 5️⃣ SAVE CHAT TO FIRESTORE

      /// 6️⃣ UPDATE UI MESSAGE
      if (loadingIndex < controller.messages.length) {
        print("Object 4");

        controller.messages[loadingIndex] = ChatMessage(
          text: output,
          isUser: false,
          mode: ChatMode.explainImage,
        );

        var chat = FBChatModel(
          id: '',
          userId: userId??'',
          mode: ChatMode.explainImage.name,
          createdAt: DateTime.now(),
          userInput: UserInput(
            prompt: text,
            imageUrl: imageUrl,
          ),

          aiOutput: AIResponse(
            text: output,
          ),
        );

        await FirestoreService().createChat(chat);


        print("Object 5");
      }
    } catch (e, st) {
      print('Gemini error in Explain Image: $e');
      print(st);

      if (loadingIndex < controller.messages.length) {
        controller.messages[loadingIndex] = ChatMessage(
          text: "Error while explaining the image.",
          isUser: false,
          mode: ChatMode.explainImage,
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
                onTap: () async {
                  Get.back();
                  await _captureImageFromCamera();
                  pickedAny = controller.selectedImageBytes.value != null;
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Get.back();
                  await _pickImageFromGallery();
                  pickedAny = controller.selectedImageBytes.value != null;
                },
              ),
            ],
          ),
        ),
      ),
    );

    return pickedAny;
  }

  Future<void> _pickImageFromGallery() async {
    var controller = Get.find<ChatController>();
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      controller.selectedImageBytes.value = bytes;
      print('[IMAGE] Picked from gallery bytes length=${bytes.length}');
    } catch (e) {
      Get.snackbar(
        'Gallery error',
        'Could not pick image from gallery: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _captureImageFromCamera() async {
    var controller = Get.find<ChatController>();
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      controller.selectedImageBytes.value = bytes;
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
