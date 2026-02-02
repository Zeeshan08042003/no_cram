import 'dart:async';
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
import 'credit_controller.dart';

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

/// ---------------- CONTROLLER ----------------

class ChatController extends GetxController {
  final messages = <FBChatItem>[].obs;
  final textController = TextEditingController();
  final scrollController = ScrollController();
  var textServices = TextAIService();
  var imageServices = ImageAIService();
  var storyTellingServices = StoryTellingServices();
  var explainImageServices = ExplainImageAiService();
  final selectedMode = ChatMode.defaultMode.obs;
  /// Display mode for header - shows the original/first mode selected (doesn't change after generation)
  final displayMode = ChatMode.defaultMode.obs;
  var showAttachmentPanel = false.obs;
  /// Multiple images support - list of image bytes
  final RxList<Uint8List> selectedImageBytesList = <Uint8List>[].obs;
  
  /// Reactive text value for button state
  final RxString textValue = ''.obs;
  
  /// Maximum number of images that can be selected
  static const int maxImageCount = 5;
  
  /// Current conversation ID - null means new conversation
  /// When set, follow-up chats will be added to this conversation
  final RxnString currentConversationId = RxnString(null);
  
  final model = FirebaseAI.googleAI();
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  var isGenerating = false.obs;
  var speechEnabled = false.obs;
  
  /// Cached CreditController for ultra-fast credit checks
  CreditController? _creditController;

  /// Check if we're in a follow-up chat (existing conversation)
  bool get isFollowUp => currentConversationId.value != null;
  
  /// Quick credit check - uses cached controller
  bool get hasCredits => _creditController?.canSearch ?? true;


  @override
  void onInit() {
    super.onInit();
    // Listen to text controller changes to update reactive value
    textController.addListener(() {
      textValue.value = textController.text;
    });
    // Pre-cache credit controller for instant access
    _initCreditController();
  }
  
  void _initCreditController() {
    try {
      _creditController = Get.find<CreditController>();
    } catch (e) {
      // Will be null if not found
    }
  }

  /// Add image bytes to the selected list
  void addImageBytes(Uint8List bytes) {
    if (selectedImageBytesList.length < maxImageCount) {
      selectedImageBytesList.add(bytes);
      print('[IMAGE] Added image, total: ${selectedImageBytesList.length}');
    } else {
      print('[IMAGE] Max image limit reached ($maxImageCount)');
    }
  }

  /// Add multiple images at once
  void addMultipleImageBytes(List<Uint8List> bytesList) {
    for (final bytes in bytesList) {
      if (selectedImageBytesList.length >= maxImageCount) break;
      selectedImageBytesList.add(bytes);
    }
    print('[IMAGE] Added ${bytesList.length} images, total: ${selectedImageBytesList.length}');
  }

  /// Remove image at specific index
  void removeImageAt(int index) {
    if (index >= 0 && index < selectedImageBytesList.length) {
      selectedImageBytesList.removeAt(index);
      print('[IMAGE] Removed image at $index, remaining: ${selectedImageBytesList.length}');
    }
  }

  /// Clear all selected images
  void clearImages() {
    selectedImageBytesList.clear();
    print('[IMAGE] Cleared all images');
  }

  /// UI calls this when a chip is tapped
  changeMode(ChatMode mode) async {
    if (selectedMode.value == mode) {
      // Toggle off
      selectedMode.value = ChatMode.defaultMode;
      clearImages();
      print("🔄 Mode cleared (no mode selected)");
      return;
    }

    selectedMode.value = mode;
    print("🎯 Mode selected: ${mode.label}");

    // Only open image picker if no images are already selected
    if (mode == ChatMode.explainImage && selectedImageBytesList.isEmpty) {
      await explainImageServices.chooseImageSourceForExplain();
    }
  }

  sendMessage() async {
    // Prevent double-tap / duplicate calls while already generating
    if (isGenerating.isTrue) {
      print("⚠️ sendMessage blocked - already generating");
      return;
    }

    final text = textController.text.trim();
    final mode = selectedMode.value;

    print("Mode is called ${mode.label}");
    print("📨 sendMessage | mode=${mode.key} | text='$text'");

    // 🎯 REQUIRE MODE SELECTION BEFORE SEARCHING (only for initial search)
    // User must select a learning style first, but follow-ups can use default (text) mode
    if (mode == ChatMode.defaultMode && !isFollowUp) {
      Get.snackbar(
        '📚 Choose a Learning Style',
        'Please select a mode (Illustration, Story, etc.) before searching',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.school, color: Colors.white),
      );
      print("❌ No mode selected - blocking search");
      return;
    }

    // 🔒 INSTANT CREDIT CHECK - Uses cached controller, no lookup overhead
    if (_creditController != null && !_creditController!.canSearch) {
      _creditController!.showBuyCreditsSheet();
      return;
    }

    // 🚀 IMMEDIATE STATE UPDATE - No delays
    isGenerating.value = true;
    
    // Set display mode (first message only)
    if (!isFollowUp) displayMode.value = mode;
    
    // Consume credit in next microtask (after UI frame)
    if (_creditController != null) {
      scheduleMicrotask(() => _creditController!.checkAndConsumeCredit());
    }
    
    // 1️⃣ Explain Image flow
    if (mode == ChatMode.explainImage) {
      // Navigate to result screen so user sees the result view
      Get.to(() => ResultScreen.generation());
      await explainImageServices.imageExplanation(text);
      // Reset mode to default for follow-up questions
      selectedMode.value = ChatMode.defaultMode;
      isGenerating(false);
      return;
    }

    // 2️⃣ Normal flow
    if (text.isEmpty) {
      isGenerating(false);
      return;
    }

    // Add user message to chat history (chat screen)
    messages.add(
      FBChatItem.user(
        prompt: text,
        mode: mode.key,
      ),
    );
    textController.clear();
    scrollToBottom();

    // Navigate to result screen for modes that produce a "result"
    Get.to(() => ResultScreen.generation());

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
    
    // Reset mode to default for follow-up questions
    selectedMode.value = ChatMode.defaultMode;
    print("🔄 Mode reset to default for follow-up questions");
    
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
    displayMode.value = ChatMode.defaultMode;
    clearImages();
    isGenerating(false); // Reset generating state
    currentConversationId.value = null; // Start a new conversation
  }

  /// Load a conversation from history
  /// Sets the currentConversationId so follow-ups are added to this conversation
  /// If isLegacy is true, follow-ups will create a new conversation
  loadConversation(FBConversationModel? conversation, {bool isLegacy = false}) {
    // 🔥 RESET STATE
    messages.clear();
    print("Loading conversation history (isLegacy: $isLegacy)");
    
    if (conversation == null) {
      currentConversationId.value = null;
      return;
    }

    // Set conversation ID for follow-ups (only for non-legacy)
    // Legacy chats don't exist in 'conversations' collection, so we create new conversation for follow-ups
    currentConversationId.value = isLegacy ? null : conversation.id;
    
    final modeString = conversation.latestMode;
    final mode = setChatMode(modeString);
    print("Conversation mode is $modeString");
    
    // 🔥 Keep mode as default for follow-up questions
    // The header will show the original mode from displayMode
    selectedMode.value = ChatMode.defaultMode;
    displayMode.value = mode; // Show original mode in header

    // Load all chats from the conversation
    for (final chat in conversation.chats) {
      // Add user message
      messages.add(
        FBChatItem.user(
          prompt: chat.userInput.prompt,
          mode: chat.mode,
          imageUrl: chat.userInput.imageUrl,
        ),
      );

      // Add AI response if exists
      if (chat.aiOutput != null) {
        messages.add(
          FBChatItem.ai(
            mode: chat.mode,
            text: chat.aiOutput!.text ?? '',
            imageUrls: chat.aiOutput!.imageUrls,
          ),
        );
      }
    }

    print("Loaded ${conversation.chats.length} chats from conversation");
    scrollToBottom();
  }


  /// Legacy method - still works with FBChatModel for backwards compatibility
  callHistory(FBChatModel? chatModel) {
    // 🔥 RESET STATE
    messages.clear();
    currentConversationId.value = null; // Legacy chats create new conversations
    print("object is now in called history function");
    final modeString = chatModel?.mode ?? '';
    final mode = setChatMode(modeString);
    print("object of mode is $modeString");
    // 🔥 Keep mode as default for follow-up questions
    // The header will show the original mode from displayMode
    selectedMode.value = ChatMode.defaultMode;
    displayMode.value = mode; // Show original mode in header

    print(selectedMode);
    // USER MESSAGE
    messages.add(
      FBChatItem.user(
        prompt: chatModel?.userInput.prompt ?? '',
        mode: modeString,
        imageUrl: chatModel?.userInput.imageUrl,
      ),
    );

    // AI MESSAGE (TEXT OR IMAGE)
    if (chatModel?.aiOutput != null) {
      messages.add(
        FBChatItem.ai(
          mode: modeString,
          text: chatModel?.aiOutput!.text ?? '',
          imageUrls: chatModel?.aiOutput!.imageUrls,
        ),
      );
    }

    scrollToBottom();
  }


  void toggleAttachmentPanel() {
    showAttachmentPanel.value = !showAttachmentPanel.value;
  }

  final FocusNode textFocusNode = FocusNode();

  @override
  void dispose() {
    textFocusNode.dispose();
    super.dispose();
  }

  setChatMode(String mode){
    print("mode is $mode");
    if(mode == "illustration" || mode == "Illustration") {
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

