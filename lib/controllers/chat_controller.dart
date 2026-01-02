import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_mode.dart';
import '../screens/result_screen.dart';
import '../services/ai/explain_image_ai_service.dart';
import '../services/ai/image_ai_service.dart';
import '../services/ai/story_telling_ai_services.dart';
import '../services/ai/text_ai_service.dart';

/// ---------------- ENUM & MESSAGE MODEL ----------------

enum ChatMode {
  defaultMode,
  illustration,
  storyTelling,
  explainImage,
  video,
}

extension ChatModeX on ChatMode {
  String get label {
    switch (this) {
      case ChatMode.illustration:
        return 'Illustration';
      case ChatMode.storyTelling:
        return 'Story';
      case ChatMode.explainImage:
        return 'Explain Image';
      case ChatMode.video:
        return 'Video';
      case ChatMode.defaultMode:
      default:
        return 'Text';
    }
  }

  String get key {
    switch (this) {
      case ChatMode.illustration:
        return 'illustration';
      case ChatMode.storyTelling:
        return 'storyTelling';
      case ChatMode.explainImage:
        return 'explainImage';
      case ChatMode.video:
        return 'video';
      case ChatMode.defaultMode:
      default:
        return 'default';
    }
  }

  // ✅ ADD THIS
  static ChatMode fromString(String? value) {
    switch (value) {
      case 'illustration':
        return ChatMode.illustration;
      case 'storyTelling':
        return ChatMode.storyTelling;
      case 'explainImage':
        return ChatMode.explainImage;
      case 'video':
        return ChatMode.video;
      default:
        return ChatMode.defaultMode;
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageText;
  final ChatMode mode;
  final String? imageUrl; // legacy single data-uri or network url
  final Uint8List? imageBytes; // legacy single bytes
  final List<Uint8List>? imageBytesList; // multiple images as bytes
  final List<String>? imageUrlList; // multiple image URLs or data URIs

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.mode,
    this.imageUrl,
    this.imageBytes,
    this.imageBytesList,
    this.imageUrlList,
    this.imageText,
  });
}

/// ---------------- CONTROLLER ----------------

class ChatController extends GetxController {
  final messages = <ChatMessage>[].obs;
  final textController = TextEditingController();
  final scrollController = ScrollController();
  var textServices = TextAIService();
  var imageServices = ImageAIService();
  var storyTellingServices = StoryTellingServices();
  var explainImageServices = ExplainImageAiService();
  final selectedMode = ChatMode.defaultMode.obs;
  final Rx<Uint8List?> selectedImageBytes = Rx<Uint8List?>(null);
  final model = FirebaseAI.googleAI();
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  var isGenerating = false.obs;

  @override
  void onInit() {
    super.onInit();
    // If you want the controller to ensure RC is fetched/activated here,
    // you could call remoteConfig.fetchAndActivate() — but it's often done once in main().
  }

  /// simple template filler

  /// UI calls this when a chip is tapped
  changeMode(ChatMode mode) async {
    if (selectedMode.value == mode) {
      // Toggle off
      selectedMode.value = ChatMode.defaultMode;
      selectedImageBytes.value = null;
      print("🔄 Mode cleared (no mode selected)");
      return;
    }

    selectedMode.value = mode;
    print("🎯 Mode selected: ${mode.label}");

    if (mode == ChatMode.explainImage) {
      await explainImageServices.chooseImageSourceForExplain();
    }
  }

  sendMessage() async {
    final text = textController.text.trim();
    final mode = selectedMode.value;

    print("Mode is called ${mode.label}");
    print("📨 sendMessage | mode=${mode.key} | text='$text'");

    isGenerating(true);
    // 1️⃣ Explain Image flow
    if (mode == ChatMode.explainImage) {
      // Navigate to result screen so user sees the result view
      Get.to(() => ResultScreen());
      await explainImageServices.imageExplanation(text);
      return;
    }

    // 2️⃣ Normal flow
    if (text.isEmpty) return;

    // Add user message to chat history (chat screen)
    messages.add(
      ChatMessage(
        text: text,
        isUser: true,
        mode: mode,
      ),
    );
    textController.clear();
    scrollToBottom();

    // Navigate to result screen for modes that produce a "result"
    Get.to(() => ResultScreen());

    if (mode == ChatMode.illustration) {
      print("✨ Illustration mode started");
      await imageServices.handleIllustrationPrompt(text);
    } else if (mode == ChatMode.storyTelling) {
      print("📖 Story telling mode started");
      await storyTellingServices.handleStoryPrompt(text);
    } else {
      print("📝 Text mode started");
      await textServices.handleTextGeneration(text, mode);
    }
    isGenerating(false);
    scrollToBottom();
  }

  scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  showImageInDialog(Widget imageWidget) {
    final context = Get.context!;
    final size = MediaQuery.of(context).size;

    final maxWidth = size.width * 0.9;
    final maxHeight = size.height * 0.85;

    Get.dialog(
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                InteractiveViewer(minScale: 1, maxScale: 5, child: imageWidget),
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.85),
    );
  }

  clearMessage() {
    messages.clear();
    selectedMode.value = ChatMode.defaultMode;
  }

  callHistory(FBChatModel? chatModel) {
    // 🔥 RESET STATE
    messages.clear();
    print("object is now in called history function");
    final mode = setChatMode(chatModel?.mode??'');
    print("object of mode is ${chatModel?.mode??'' + mode}");
    // 🔥 SYNC MODE FOR HEADER
    selectedMode.value = mode;

    print(selectedMode);
    // USER MESSAGE
    messages.add(
      ChatMessage(
        text: chatModel?.userInput.prompt??'',
        isUser: true,
        mode: mode,
        imageUrl: chatModel?.userInput.imageUrl,
      ),
    );

    // AI MESSAGE (TEXT OR IMAGE)
    if (chatModel?.aiOutput != null) {
      messages.add(
        ChatMessage(
          text: chatModel?.aiOutput!.text ?? '',
          isUser: false,
          mode: mode,
          imageUrlList: chatModel?.aiOutput!.imageUrls,
          imageText: chatModel?.aiOutput?.text??''
        ),
      );
    }

    scrollToBottom();
  }



  setChatMode(String mode){
    print("mode is $mode");
    if(mode == "Illustration") {
      return ChatMode.illustration;
    }else if(mode == "explainImage"){
      return ChatMode.explainImage;
    }else if(mode == "storyTelling"){
      return ChatMode.storyTelling;
    }else{
      return ChatMode.defaultMode;
    }
  }


}

// import 'dart:async';
// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
//
// import '../models/chat_message.dart';
// import '../models/chat_mode.dart';
// import '../services/ai/image_ai_service.dart';
// import '../services/ai/text_ai_service.dart';
// import '../services/ai/explain_image_ai_service.dart';
// import '../services/firebase/firestore_service.dart';
// import '../services/image_picker_service.dart';
//
// class ChatController extends GetxController {
//   final ChatRepository repo;
//   final TextAIService textAI;
//   final ImageAIService imageAI;
//   final VisionAIService visionAI;
//   final ImagePickerService imagePicker;
//
//   ChatController({
//     required this.repo,
//     required this.textAI,
//     required this.imageAI,
//     required this.visionAI,
//     required this.imagePicker,
//   });
//
//   final messages = <ChatMessage>[].obs;
//   final selectedMode = ChatMode.defaultMode.obs;
//   final textController = TextEditingController();
//
//   /// Used by HomeScreen preview
//   final Rx<Uint8List?> selectedImageBytes = Rx<Uint8List?>(null);
//
//   final String chatId = 'default_chat';
//   StreamSubscription? _sub;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _sub = repo.messages(chatId).listen((data) {
//       messages.assignAll(data);
//       scrollToBottom();
//     });  }
//
//   final ScrollController scrollController = ScrollController();
//
//   void scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (scrollController.hasClients) {
//         scrollController.animateTo(
//           scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   @override
//   void onClose() {
//     _sub?.cancel();
//     scrollController.dispose();
//     textController.dispose();
//     super.onClose();
//
//   }
//
//
//   // ---------------- UI COMPATIBILITY ----------------
//
//   void changeMode(ChatMode mode) async {
//     if (selectedMode.value == mode) {
//       selectedMode.value = ChatMode.defaultMode;
//       selectedImageBytes.value = null;
//       return;
//     }
//
//     selectedMode.value = mode;
//
//     if (mode == ChatMode.explainImage) {
//       await pickImageFromGallery();
//     }
//   }
//
//   Future<void> pickImageFromGallery() async {
//     final bytes = await imagePicker.pick(ImageSource.gallery);
//     if (bytes != null) {
//       selectedImageBytes.value = bytes;
//     }
//   }
//
//   void showImageInDialog(Widget imageWidget) {
//     Get.dialog(
//       Center(
//         child: InteractiveViewer(
//           minScale: 1,
//           maxScale: 5,
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: imageWidget,
//           ),
//         ),
//       ),
//       barrierColor: Colors.black.withOpacity(0.85),
//     );
//   }
//
//   // ---------------- SEND MESSAGE ----------------
//
//   Future<void> sendMessage() async {
//     final text = textController.text.trim();
//     if (text.isEmpty) return;
//
//     final userMessage = ChatMessage(
//       id: '',
//       text: text,
//       isUser: true,
//       mode: selectedMode.value,
//       createdAt: DateTime.now(),
//     );
//
//     await repo.sendMessage(chatId, userMessage);
//     textController.clear();
//
//     if (selectedMode.value == ChatMode.illustration) {
//       final images = await imageAI.generateImages(text);
//       await repo.sendMessage(
//         chatId,
//         ChatMessage(
//           id: '',
//           text: '',
//           isUser: false,
//           mode: ChatMode.illustration,
//           imageUrls: images,
//           createdAt: DateTime.now(),
//         ),
//       );
//     } else if (selectedMode.value == ChatMode.explainImage &&
//         selectedImageBytes.value != null) {
//       final result = await visionAI.explainImage(
//         selectedImageBytes.value!,
//         'Explain the image clearly for a student.',
//       );
//
//       await repo.sendMessage(
//         chatId,
//         ChatMessage(
//           id: '',
//           text: result,
//           isUser: false,
//           mode: ChatMode.explainImage,
//           createdAt: DateTime.now(),
//         ),
//       );
//
//       selectedImageBytes.value = null;
//     } else {
//       final aiResponse = await textAI.generate(text);
//       await repo.sendMessage(
//         chatId,
//         ChatMessage(
//           id: '',
//           text: aiResponse,
//           isUser: false,
//           mode: selectedMode.value,
//           createdAt: DateTime.now(),
//         ),
//       );
//     }
//
//     selectedMode.value = ChatMode.defaultMode;
//   }
// }
