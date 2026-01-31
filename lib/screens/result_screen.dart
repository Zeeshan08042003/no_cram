import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_mode.dart';
import '../controllers/chat_controller.dart';
import '../services/ai/explain_image_ai_service.dart';
import 'chat_screen.dart';
import 'message_bubble.dart';

/// Enum to distinguish between new generation and viewing history
enum ResultViewMode {
  generation,    // New AI generation in progress
  history,       // Viewing past chat from history (legacy FBChatModel)
  conversation,  // Viewing a conversation with all its chats
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    this.chatModel,
    this.conversationModel,
    this.viewMode = ResultViewMode.generation,
    this.isLegacy = false,
  });
  
  final FBChatModel? chatModel;
  final FBConversationModel? conversationModel;
  final ResultViewMode viewMode;
  final bool isLegacy; // Whether this is a legacy chat from old 'chats' collection
  
  /// Factory constructor for generation mode
  factory ResultScreen.generation() => const ResultScreen(
    viewMode: ResultViewMode.generation,
  );
  
  /// Factory constructor for history mode (legacy - single chat)
  factory ResultScreen.history(FBChatModel chatModel) => ResultScreen(
    chatModel: chatModel,
    viewMode: ResultViewMode.history,
  );
  
  /// Factory constructor for conversation mode (new - full conversation)
  factory ResultScreen.conversation(FBConversationModel conversationModel, {bool isLegacy = false}) => ResultScreen(
    conversationModel: conversationModel,
    viewMode: ResultViewMode.conversation,
    isLegacy: isLegacy,
  );
  
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ChatController controller = Get.find<ChatController>();

  bool get isHistoryMode => widget.viewMode == ResultViewMode.history;
  bool get isConversationMode => widget.viewMode == ResultViewMode.conversation;
  bool get isGenerationMode => widget.viewMode == ResultViewMode.generation;
  
  /// Show input field for conversation mode and history mode (for follow-ups)
  bool get showInputField => isConversationMode || isHistoryMode;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    if (isConversationMode && widget.conversationModel != null) {
      // Load conversation with all its chats
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadConversation(widget.conversationModel!, isLegacy: widget.isLegacy);
      });
    } else if (isHistoryMode && widget.chatModel != null) {
      // Legacy: Load single chat (backwards compatibility)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.callHistory(widget.chatModel!);
      });
    }
  }


  @override
  void dispose() {
    // Defer clearMessage to avoid modifying observables while widget tree is locked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.clearMessage();
    });
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        // Mode is already reset to default after generation completes in ChatController
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessageList()),
              _buildInputField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ================= IMAGE PREVIEW =================
          Obx(() {
            final imageList = controller.selectedImageBytesList;
            if (imageList.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageList.length,
                  itemBuilder: (context, index) {
                    final bytes = imageList[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              bytes,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => controller.removeImageAt(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }),

          // ================= INPUT ROW =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ➕ PLUS BUTTON
              GestureDetector(
                onTap: () async {
                  await ExplainImageAiService().chooseImageSourceForExplain();
                },
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Icon(Icons.photo, color: Colors.blue),
                  ),
                ),

              const SizedBox(width: 8),

              // TEXT FIELD (ALWAYS VISIBLE)
              Expanded(child: _buildTextInput()),

              const SizedBox(width: 8),

              // SEND BUTTON (ALWAYS VISIBLE)
              _buildSendButton(),
            ],
          ),

          // ================= ATTACHMENT PANEL =================
          Obx(() {
            return controller.showAttachmentPanel.value
                ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildAttachmentPanel(),
            )
                : const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  void _handleSend() {
    // TODO: Implement follow-up question logic
    controller.sendMessage();
  }

  Widget _buildSendButton() {
    return Obx(
          () => GestureDetector(
        onTap: controller.isGenerating.isTrue ? null : controller.sendMessage,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: controller.isGenerating.isTrue
                ? Colors.grey
                : const Color(0xFF07A0FF),
            shape: BoxShape.circle,
          ),
          child: controller.isGenerating.isTrue
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    );
  }


  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: controller.textController,
        focusNode: controller.textFocusNode,
        minLines: 1,
        maxLines: null,
        onTap: (){
          controller.showAttachmentPanel.value == false;

          // ✅ ENSURE keyboard opens
          Future.delayed(const Duration(milliseconds: 30), () {
            controller.textFocusNode.requestFocus();
          });
        },
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: 'Ask follow up questions',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildAttachmentPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        children: [
          // const SizedBox(width: 2),
          ChoiceChipCard(
            label: 'Illustration',
            size: 50,
            icon: Icons.image_search_outlined,
            isSelected: controller.selectedMode.value ==
                ChatMode.illustration,
            onTap: () => controller
                .changeMode(ChatMode.illustration),
            selectedColor: Color(0xFF1A73E8), // visible when selected
            unselectedColor:
            Colors.white, // visible when unselected
          ),
          ChoiceChipCard(
            label: 'Story',
            size: 50,
            icon: Icons.menu_book_outlined,
            isSelected: controller.selectedMode.value ==
                ChatMode.storyTelling,
            onTap: () => controller
                .changeMode(ChatMode.storyTelling),
            selectedColor:Color(0xFF1A73E8), // green when selected
            unselectedColor: Colors.white,
          ),
          ChoiceChipCard(
            label: 'Image Explanation',
            icon: Icons.search,
            size: 50,
            isSelected: controller.selectedMode.value ==
                ChatMode.explainImage,
            onTap: () => controller
                .changeMode(ChatMode.explainImage),
            selectedColor:Color(0xFF1A73E8), // green when selected
            unselectedColor: Colors.white,
          ),
          ChoiceChipCard(
            label: 'Video',
            icon: Icons.play_circle_outline,
            size: 50,
            isSelected: controller.selectedMode.value ==
                ChatMode.video,
            onTap: () =>
                controller.changeMode(ChatMode.video),
            selectedColor:Color(0xFF1A73E8), // green when selected
            unselectedColor: Colors.white,
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: const Icon(Icons.arrow_back_ios, color: Colors.black),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Obx(
                  () => Text(
                    "${controller.displayMode.value.label.capitalizeFirst} Mode",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                _buildStatusText(),
              ],
            ),
            const Icon(Icons.more_vert, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    // History mode shows static "From History" text
    // if (isHistoryMode) {
    //   return const Text(
    //     "From History",
    //     style: TextStyle(
    //       fontSize: 10,
    //       fontWeight: FontWeight.w600,
    //       color: Colors.blueGrey,
    //     ),
    //   );
    // }
    
    // Generation mode shows dynamic Generating/Generated status
    return Obx(
      () => Text(
        controller.isGenerating.isTrue ? "Generating..." : "Generated",
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Obx(() {
      final messages = controller.messages;
      if (messages.isEmpty) {
        return const Center(
          child: Text(
            'No messages yet.',
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final m = messages[index];
          // Animate latest AI message only in generation mode
          final isLast = index == messages.length - 1;
          final animate = isGenerationMode && isLast && !m.isUserMessage;
          
          // Convert string mode to ChatMode enum
          final chatMode = ChatModeX.fromString(m.mode);
          
          return MessageBubble(
            text: m.displayText,
            isUser: m.isUserMessage,
            mode: chatMode,
            imageBytesList: m.displayImageBytes,
            imageUrlList: m.displayImageUrls,
            animate: animate,
            explainText: m.isUserMessage ? null : m.aiOutput?.text,
          );
        },
      );
    });
  }
}
