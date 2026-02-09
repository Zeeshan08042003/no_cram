import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_mode.dart';
import '../controllers/chat_controller.dart';
import '../services/ai/explain_image_ai_service.dart';
import '../utils/app_themes.dart';
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
  
  // ==================== SEARCH STATE ====================
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  int _totalMatches = 0;
  
  /// GlobalKeys for each message to enable scrolling to specific messages
  final Map<int, GlobalKey> _messageKeys = {};

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    // Defer clearMessage to avoid modifying observables while widget tree is locked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.clearMessage();
    });
    super.dispose();
  }
  
  // ==================== SEARCH METHODS ====================
  
  /// List of (messageIndex, matchCount) for each message that has matches
  List<_MessageMatchInfo> _matchInfoList = [];
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _currentMatchIndex = 0;
        _totalMatches = 0;
        _matchInfoList = [];
      } else {
        // Focus on search field when opening
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }
  
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _currentMatchIndex = 0;
      _countMatches();
    });
    
    // Scroll to first match if found
    if (_totalMatches > 0) {
      _scrollToCurrentMatch();
    }
  }
  
  void _countMatches() {
    if (_searchQuery.isEmpty) {
      _totalMatches = 0;
      _matchInfoList = [];
      return;
    }
    
    _matchInfoList = [];
    int totalCount = 0;
    
    for (int i = 0; i < controller.messages.length; i++) {
      final text = controller.messages[i].displayText.toLowerCase();
      final matchCount = _countOccurrences(text, _searchQuery);
      if (matchCount > 0) {
        _matchInfoList.add(_MessageMatchInfo(
          messageIndex: i,
          matchCount: matchCount,
          startMatchIndex: totalCount,
        ));
        totalCount += matchCount;
      }
    }
    _totalMatches = totalCount;
  }
  
  int _countOccurrences(String text, String pattern) {
    if (pattern.isEmpty) return 0;
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(pattern, index)) != -1) {
      count++;
      index += pattern.length;
    }
    return count;
  }
  
  /// Find which message contains the current match index
  int _getMessageIndexForCurrentMatch() {
    if (_matchInfoList.isEmpty) return 0;
    
    for (final info in _matchInfoList) {
      if (_currentMatchIndex >= info.startMatchIndex &&
          _currentMatchIndex < info.startMatchIndex + info.matchCount) {
        return info.messageIndex;
      }
    }
    return _matchInfoList.first.messageIndex;
  }
  
  /// Scroll to the message containing the current match
  void _scrollToCurrentMatch() {
    if (_matchInfoList.isEmpty) return;
    
    final messageIndex = _getMessageIndexForCurrentMatch();
    
    // Get the GlobalKey for this message
    final key = _messageKeys[messageIndex];
    
    // CASE 1: Widget is already rendered (key.currentContext is not null)
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the message
      );
      return;
    }
    
    // CASE 2: Widget is not rendered (off-screen)
    // We must manually scroll near it first to trigger a build
    if (controller.scrollController.hasClients) {
      // Estimate offset: index * rough item height
      // Using a safer estimate to avoid overscrolling past the list end
      final estimatedOffset = (messageIndex * 150.0)
          .clamp(0.0, controller.scrollController.position.maxScrollExtent);
          
      controller.scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 100), // Fast jump
        curve: Curves.easeOut,
      ).then((_) {
        // After scrolling near, wait a bit for build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Try ensuring visible again
          if (key != null && key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        });
      });
    }
  }
  
  void _nextMatch() {
    if (_totalMatches > 0) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
      });
      _scrollToCurrentMatch();
    }
  }
  
  void _previousMatch() {
    if (_totalMatches > 0) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
      });
      _scrollToCurrentMatch();
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        // Mode is already reset to default after generation completes in ChatController
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: SafeArea(
          bottom: false, // We handle bottom padding in _buildInputField
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildMessageList(context)),
              _buildInputField(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    final isDark = context.isDark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottomPadding),
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
                    child: Icon(Icons.photo, color: AppColors.primaryBlue),
                  ),
                ),

              const SizedBox(width: 8),

              // TEXT FIELD (ALWAYS VISIBLE)
              Expanded(child: _buildTextInput(context)),

              const SizedBox(width: 8),

              // SEND BUTTON (ALWAYS VISIBLE)
              _buildSendButton(context),
            ],
          ),

          // ================= ATTACHMENT PANEL =================
          Obx(() {
            return controller.showAttachmentPanel.value
                ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildAttachmentPanel(context),
            )
                : const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  void _handleSend() {
    controller.sendMessage();
  }

  Widget _buildSendButton(BuildContext context) {
    return Obx(() {
      final isGenerating = controller.isGenerating.isTrue;
      final hasText = controller.textValue.value.trim().isNotEmpty;
      final canSend = !isGenerating && hasText;
      
      return GestureDetector(
        onTap: canSend ? () => controller.sendMessage() : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isGenerating
                ? context.textTertiary
                : (canSend ? AppColors.primaryBlue : AppColors.primaryBlue.withOpacity(0.4)),
            shape: BoxShape.circle,
          ),
          child: isGenerating
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Icon(Icons.send, 
                  color: canSend ? Colors.white : Colors.white.withOpacity(0.6), 
                  size: 20),
        ),
      );
    });
  }


  Widget _buildTextInput(BuildContext context) {
    final isDark = context.isDark;
    
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
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
        style: TextStyle(color: context.textPrimary),
        onTap: (){
          controller.showAttachmentPanel.value == false;

          // ✅ ENSURE keyboard opens
          Future.delayed(const Duration(milliseconds: 30), () {
            controller.textFocusNode.requestFocus();
          });
        },
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: 'Ask follow up questions',
          hintStyle: TextStyle(color: context.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          isDense: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildAttachmentPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        children: [
          ChoiceChipCard(
            label: 'Illustration',
            size: 50,
            icon: Icons.image_search_outlined,
            isSelected: controller.selectedMode.value ==
                ChatMode.illustration,
            onTap: () => controller
                .changeMode(ChatMode.illustration),
            selectedColor: AppColors.primaryBlue,
            unselectedColor: context.cardColor,
            labelColor: context.textPrimary,
            borderColor: context.dividerColor,
          ),
          ChoiceChipCard(
            label: 'Story',
            size: 50,
            icon: Icons.menu_book_outlined,
            isSelected: controller.selectedMode.value ==
                ChatMode.storyTelling,
            onTap: () => controller
                .changeMode(ChatMode.storyTelling),
            selectedColor: AppColors.primaryBlue,
            unselectedColor: context.cardColor,
            labelColor: context.textPrimary,
            borderColor: context.dividerColor,
          ),
          ChoiceChipCard(
            label: 'Image Explanation',
            icon: Icons.search,
            size: 50,
            isSelected: controller.selectedMode.value ==
                ChatMode.explainImage,
            onTap: () => controller
                .changeMode(ChatMode.explainImage),
            selectedColor: AppColors.primaryBlue,
            unselectedColor: context.cardColor,
            labelColor: context.textPrimary,
            borderColor: context.dividerColor,
          ),
          ChoiceChipCard(
            label: 'Video',
            icon: Icons.play_circle_outline,
            size: 50,
            isSelected: controller.selectedMode.value ==
                ChatMode.video,
            onTap: () =>
                controller.changeMode(ChatMode.video),
            selectedColor: AppColors.primaryBlue,
            unselectedColor: context.cardColor,
            labelColor: context.textPrimary,
            borderColor: context.dividerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: _isSearching ? _buildSearchBar(context) : _buildNormalHeader(context),
      ),
    );
  }
  
  Widget _buildNormalHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Icon(Icons.arrow_back_ios, color: context.textPrimary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Obx(
              () => Text(
                "${controller.displayMode.value.label.capitalizeFirst} Mode",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _buildStatusText(context),
          ],
        ),
        // Search button only (removed menu button)
        GestureDetector(
          onTap: _toggleSearch,
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.search, color: context.textPrimary, size: 24),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSearchBar(BuildContext context) {
    final isDark = context.isDark;
    
    return Row(
      children: [
        // Back/Close button
        GestureDetector(
          onTap: _toggleSearch,
          child: Icon(Icons.arrow_back_ios, color: context.textPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        
        // Search input field
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _updateSearchQuery,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search in conversation...',
                hintStyle: TextStyle(
                  color: context.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _updateSearchQuery('');
                        },
                        child: Icon(
                          Icons.close,
                          color: context.textTertiary,
                          size: 18,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        
        // Match count and navigation
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            _totalMatches > 0 
                ? '${_currentMatchIndex + 1}/$_totalMatches'
                : '0/0',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _previousMatch,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.keyboard_arrow_up,
                color: _totalMatches > 0 ? context.textPrimary : context.textTertiary,
                size: 22,
              ),
            ),
          ),
          GestureDetector(
            onTap: _nextMatch,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: _totalMatches > 0 ? context.textPrimary : context.textTertiary,
                size: 22,
              ),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildStatusText(BuildContext context) {
    return Obx(
      () => Text(
        controller.isGenerating.isTrue ? "Generating..." : "Generated",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.success,
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    return Obx(() {
      final messages = controller.messages;
      if (messages.isEmpty) {
        return Center(
          child: Text(
            'No messages yet.',
            style: TextStyle(color: context.textSecondary),
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
          
          // Create or get GlobalKey for this message (for search scrolling)
          _messageKeys[index] ??= GlobalKey();
          
          // Find match info for this message to support internal highlighting logic
          int? startingMatchIndex;
          try {
            final info = _matchInfoList.firstWhere((info) => info.messageIndex == index);
            startingMatchIndex = info.startMatchIndex;
          } catch (_) {}
          
          return Container(
            key: _messageKeys[index],
            child: MessageBubble(
              text: m.displayText,
              isUser: m.isUserMessage,
              mode: chatMode,
              imageBytesList: m.displayImageBytes,
              imageUrlList: m.displayImageUrls,
              animate: animate,
              explainText: m.isUserMessage ? null : m.aiOutput?.text,
              searchQuery: _searchQuery,
              currentMatchIndex: _currentMatchIndex,
              startingMatchIndex: startingMatchIndex,
            ),
          );
        },
      );
    });
  }
}

// ==================== SEARCH HELPER CLASS ====================

/// Helper class to track match information per message
class _MessageMatchInfo {
  final int messageIndex;
  final int matchCount;
  final int startMatchIndex; // Global match index where this message's matches start
  
  const _MessageMatchInfo({
    required this.messageIndex,
    required this.matchCount,
    required this.startMatchIndex,
  });
}
