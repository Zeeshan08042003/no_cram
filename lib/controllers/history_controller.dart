import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_mode.dart';
import '../services/firebase/firestore_service.dart';

class HistoryController extends GetxController {
  var firestoreService = FirestoreService();

  final isDeleteMode = false.obs;
  var conversations = <FBConversationModel>[].obs;
  var legacyChats = <FBChatModel>[].obs; // Legacy chats from old 'chats' collection
  final selectedTab = 0.obs; // 0=All, 1=Illustration, 2=Story, 3=Video

  @override
  void onInit() {
    super.onInit();
    init();
  }

  init() async {
    await bindConversations();
    await bindLegacyChats(); // Also fetch legacy chats
  }

  bindConversations() async {
    print("Total conversations fetching started");
    var sharedPref = await SharedPreferences.getInstance();
    var userId = sharedPref.getString('userId');

    firestoreService.getConversationsByUser(userId ?? '').listen(
      (data) {
        conversations(data);
        print("Total conversations fetched : ${conversations.length}");
      },
      onError: (error) {
        print("❌ Error fetching conversations: $error");
      },
    );
  }

  /// Fetch legacy chats from old 'chats' collection for backwards compatibility
  bindLegacyChats() async {
    print("Legacy chats fetching started");
    var sharedPref = await SharedPreferences.getInstance();
    var userId = sharedPref.getString('userId');

    firestoreService.getChatsByUser(userId ?? '').listen(
      (data) {
        legacyChats(data);
        print("Legacy chats fetched : ${legacyChats.length}");
      },
      onError: (error) {
        print("❌ Error fetching legacy chats: $error");
      },
    );
  }

  // 🔹 Change tab
  void changeTab(int index) {
    selectedTab.value = index;
  }

  /// Combined list: new conversations + legacy chats converted to conversations
  List<FBConversationModel> get allConversations {
    // Convert legacy chats to FBConversationModel for uniform display
    final legacyAsConversations = legacyChats.map((chat) {
      return FBConversationModel(
        id: chat.id,
        userId: chat.userId,
        latestMode: chat.mode,
        createdAt: chat.createdAt,
        chats: [
          FBChatItem(
            id: chat.id,
            createdAt: chat.createdAt,
            mode: chat.mode,
            isUserMessage: false,
            userInput: chat.userInput,
            aiOutput: chat.aiOutput,
          ),
        ],
      );
    }).toList();

    // Combine both lists and sort by creation date (newest first)
    final combined = [...conversations, ...legacyAsConversations];
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  // 🔹 Filtered conversations based on tab (using latestMode)
  List<FBConversationModel> get filteredConversations {
    if (selectedTab.value == 0) {
      return allConversations; // All
    }

    final modeKey = _modeForTab(selectedTab.value);

    return allConversations
        .where((c) => c.latestMode.toLowerCase() == modeKey.toLowerCase())
        .toList();
  }

  // 🔹 Group filtered conversations by date
  Map<String, List<FBConversationModel>> get groupedConversations {
    final Map<String, List<FBConversationModel>> grouped = {};

    for (final conversation in filteredConversations) {
      final label = _dateLabel(conversation.createdAt);
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(conversation);
    }

    return grouped;
  }

  /// Get the preview text for a conversation (from first chat's user input)
  String getConversationPreview(FBConversationModel conversation) {
    if (conversation.chats.isEmpty) return 'Empty conversation';
    return conversation.chats.first.userInput.prompt;
  }

  /// Get total number of chats in a conversation
  int getChatCount(FBConversationModel conversation) {
    return conversation.chats.length;
  }

  /// Check if this is a legacy chat (single chat, from old collection)
  bool isLegacyChat(FBConversationModel conversation) {
    return conversation.chats.length == 1 && 
           legacyChats.any((c) => c.id == conversation.id);
  }


  void toggleDeleteMode() {
    isDeleteMode.toggle();
  }

  // 🔥 DELETE CONVERSATION OR LEGACY CHAT
  Future<void> deleteConversation(FBConversationModel conversation) async {
    try {
      // Check if it's a legacy chat
      if (isLegacyChat(conversation)) {
        await firestoreService.db.collection('chats').doc(conversation.id).delete();
      } else {
        await firestoreService.db.collection('conversations').doc(conversation.id).delete();
      }

      Get.snackbar(
        'Deleted',
        'Conversation removed from history',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete conversation',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }




  // ---------------- HELPERS ----------------

  String _modeForTab(int index) {
    switch (index) {
      case 1:
        return 'illustration';
      case 2:
        return 'storyTelling';
      case 3:
        return 'video';
      default:
        return '';
    }
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'TODAY';
    if (diff.inDays == 1) return 'YESTERDAY';
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
