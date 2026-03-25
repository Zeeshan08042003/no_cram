import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_mode.dart';
import '../screens/result_screen.dart';
import '../services/ai/explain_image_ai_service.dart';
import '../services/ai/image_ai_service.dart';
import '../services/ai/story_telling_ai_services.dart';
import '../services/ai/text_ai_service.dart';
import '../services/firebase/firestore_service.dart';
import 'package:uid/uid.dart';
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
  final selectedMode = ChatMode.illustration.obs;
  /// Display mode for header - shows the original/first mode selected (doesn't change after generation)
  final displayMode = ChatMode.illustration.obs;
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
  
  /// Track current generation ID to prevent race conditions
  String? currentGenerationId;
  
  /// Cached CreditController for ultra-fast credit checks
  CreditController? _creditController;
  
  /// Cached userId — populated once at init so AI services skip SharedPreferences on every call
  static String? cachedUserId;

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
  
  void _initCreditController() async {
    try {
      _creditController = Get.find<CreditController>();
    } catch (e) {
      // Will be null if not found
    }
    // Cache userId once — avoids SharedPreferences.getInstance() on every AI call
    final prefs = await SharedPreferences.getInstance();
    cachedUserId = prefs.getString('userId');
    print('[CHAT] Cached userId: $cachedUserId');
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
    // If same mode is tapped, do nothing (no deselect)
    if (selectedMode.value == mode) {
      return;
    }

    // Clear images when switching modes
    clearImages();
    
    selectedMode.value = mode;
    print("🎯 Mode selected: ${mode.label}");

    // Only open image picker if no images are already selected
    if (mode == ChatMode.explainImage && selectedImageBytesList.isEmpty) {
      await explainImageServices.chooseImageSourceForExplain();
    }
  }

  void stopGeneration() {
    if (isGenerating.isFalse) return;
    
    isGenerating.value = false;
    print("🛑 Generation stopped by user");
    
    // Update the last message (which is the AI placeholder) to show it was stopped
    if (messages.isNotEmpty) {
      final lastIdx = messages.length - 1;
      final lastMessage = messages[lastIdx];
      
      if (!lastMessage.isUserMessage) {
        final stoppedOutput = AIResponse(text: "Stop Generating");
        
        // Update local UI
        messages[lastIdx] = FBChatItem(
          id: lastMessage.id,
          createdAt: lastMessage.createdAt,
          mode: lastMessage.mode,
          userInput: lastMessage.userInput,
          aiOutput: stoppedOutput,
          isUserMessage: false,
        );
        
        // Sync with Firestore so history also reflects the stopped state
        if (currentConversationId.value != null) {
          FirestoreService().updateAiResponseInConversation(
            conversationId: currentConversationId.value!,
            chatId: lastMessage.id,
            outputText: stoppedOutput.text ?? "Stop Generating",
          );
        }
      }
    }
  }

  sendMessage({bool forceNew = false}) async {
    // Prevent double-tap / duplicate calls while already generating
    if (isGenerating.isTrue) {
      print("⚠️ sendMessage blocked - already generating");
      return;
    }

    if (forceNew) {
      currentConversationId.value = null;
    }

    final actionId = UId.getId();
    currentGenerationId = actionId;

    final bool initialIsFollowUp = isFollowUp;
    final text = textController.text.trim();
    final mode = selectedMode.value;
    final hasImages = selectedImageBytesList.isNotEmpty;

    print("Mode is called ${mode.label}");
    print("📨 sendMessage | mode=${mode.key} | text='$text'");

    // Note: Learning style is recommended but not enforced for initial search anymore
    // to allow 'Teach Me' to work with default text mode.

    // 🔒 INSTANT CREDIT CHECK - Uses cached controller, no lookup overhead
    if (_creditController != null && !_creditController!.canSearch) {
      _creditController!.showCreditsExhaustedSheet();
      return;
    }

    // 🚀 IMMEDIATE STATE UPDATE - No delays
    isGenerating.value = true;
    
    // Set display mode (first message only)
    if (!initialIsFollowUp) {
      messages.clear();
      displayMode.value = mode;
    }

    // 1️⃣ INITIAL FIRESTORE PERSISTENCE (USER MESSAGE + AI PLACEHOLDER)
    final userId = cachedUserId ?? '';
    final userChatId = UId.getId();
    final aiChatId = UId.getId();

    // Create user chat item
    final userChatItem = FBChatItem(
      id: userChatId,
      createdAt: DateTime.now(),
      mode: mode.key,
      isUserMessage: true,
      userInput: UserInput(
        prompt: text,
        imageBytesList: List<Uint8List>.from(selectedImageBytesList),
      ),
    );

    // Create AI placeholder item
    final aiPlaceholderItem = FBChatItem(
      id: aiChatId,
      createdAt: DateTime.now().add(const Duration(milliseconds: 10)),
      mode: mode.key,
      isUserMessage: false,
      userInput: UserInput(prompt: text),
      aiOutput: AIResponse(text: _getLoadingText(mode, hasImages)),
    );

    // Add to local UI immediately
    messages.add(userChatItem);
    messages.add(aiPlaceholderItem);
    
    // Save to Firestore immediately
    final firestoreService = FirestoreService();
    if (initialIsFollowUp) {
      // Add both to existing conversation
      await firestoreService.addChatToConversation(
        conversationId: currentConversationId.value!,
        chatItem: userChatItem,
      );
      await firestoreService.addChatToConversation(
        conversationId: currentConversationId.value!,
        chatItem: aiPlaceholderItem,
      );
    } else {
      // Create new conversation with user message
      final convId = await firestoreService.createConversation(
        userId: userId,
        mode: mode.key,
        chatItem: userChatItem,
      );
      currentConversationId.value = convId;
      // Add AI placeholder to the new conversation
      await firestoreService.addChatToConversation(
        conversationId: convId,
        chatItem: aiPlaceholderItem,
      );
    }

    textController.clear();
    
    // Only clear images if they aren't about to be used for an explanation
    final willExplain = mode == ChatMode.explainImage || (mode == ChatMode.defaultMode && hasImages);
    if (!willExplain) {
      clearImages();
    }

    scrollToBottom();

    // 2️⃣ Explain Image flow (Explicit mode or default mode with images)
    if (mode == ChatMode.explainImage || (mode == ChatMode.defaultMode && hasImages)) {
      // Navigate to result screen so user sees the result view
      if (!initialIsFollowUp) Get.to(() => ResultScreen.generation());
      await explainImageServices.imageExplanation(text, aiChatId: aiChatId, generationId: actionId);
      // Reset mode to default for follow-up questions
    selectedMode.value = ChatMode.illustration;
    if (currentGenerationId == actionId) {
      isGenerating(false);
    }
      return;
    }

    // 2️⃣ Normal flow
    if (text.isEmpty) {
    if (currentGenerationId == actionId) {
      isGenerating(false);
    }
      return;
    }

    // Navigate to result screen for modes that produce a "result"
    if (!initialIsFollowUp) Get.to(() => ResultScreen.generation());

    if (mode == ChatMode.illustration) {
      print("✨ Illustration mode started${hasImages ? ' with reference images' : ''}");
      await imageServices.handleIllustrationPrompt(text, aiChatId: aiChatId, generationId: actionId);
    } else if (mode == ChatMode.storyTelling) {
      print("📖 Story telling mode started");
      await storyTellingServices.handleStoryPrompt(text, aiChatId: aiChatId, generationId: actionId);
    } else {
      print("📝 Text mode started");
      await textServices.handleTextGeneration(text, mode, aiChatId: aiChatId, generationId: actionId);
    }
    
    // Reset mode to default for follow-up questions
    selectedMode.value = ChatMode.illustration;
    print("🔄 Mode reset to default for follow-up questions");
    
    if (currentGenerationId == actionId) {
      isGenerating(false);
    }
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
    selectedMode.value = ChatMode.illustration;
    displayMode.value = ChatMode.illustration;
    clearImages();
    isGenerating(false); // Reset generating state
    currentConversationId.value = null; // Start a new conversation
  }

  /// Load a conversation from history
  /// Sets the currentConversationId so follow-ups are added to this conversation
  /// If isLegacy is true, follow-ups will create a new conversation
  loadConversation(FBConversationModel? conversation, {bool isLegacy = false}) {
    if (conversation == null) {
      currentConversationId.value = null;
      messages.clear();
      return;
    }

    // If we are already viewing/generating THIS conversation, don't clear or reload
    // This prevents losing in-progress AI responses when coming back from History
    if (currentConversationId.value == conversation.id && messages.isNotEmpty) {
      print("♻️ loadConversation: Conversation already active, skipping reload");
      return;
    }

    // 🔥 RESET STATE for NEW conversation
    messages.clear();
    isGenerating.value = false;

    print("Loading conversation history (isLegacy: $isLegacy)");

    // Set conversation ID for follow-ups (only for non-legacy)
    currentConversationId.value = isLegacy ? null : conversation.id;
    
    // Assign stored chats
    messages.assignAll(conversation.chats);
    
    // Show correct mode in header
    final modeString = conversation.latestMode;
    displayMode.value = setChatMode(modeString);
    
    // Keep follow-up mode as default text for now
    selectedMode.value = ChatMode.illustration;

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
    selectedMode.value = ChatMode.illustration;
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

  String _getLoadingText(ChatMode mode, bool hasImages) {
    if (mode == ChatMode.explainImage || (mode == ChatMode.defaultMode && hasImages)) {
      return 'Analysing the image and explaining...';
    } else if (mode == ChatMode.illustration) {
      return 'Creating your illustration...';
    } else if (mode == ChatMode.storyTelling) {
      return 'Crafting your story...';
    } else {
      return 'Thinking about your question...';
    }
  }
}

