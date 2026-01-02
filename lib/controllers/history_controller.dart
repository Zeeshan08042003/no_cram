import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_mode.dart';
import '../services/firebase/firestore_service.dart';

class HistoryController extends GetxController {
  var firestoreService = FirestoreService();

  final isDeleteMode = false.obs;
  var chats = <FBChatModel>[].obs;
  final selectedTab = 0.obs; // 0=All, 1=Illustration, 2=Story, 3=Video

  @override
  void onInit() {
    super.onInit();
    init();
  }

  init() async {
    await bindChats();
  }

  bindChats() async {
    print("Total chat fetching started");
    var sharedPref = await SharedPreferences.getInstance();
    var userId = sharedPref.getString('userId');


    await firestoreService.getChatsByUser(userId??'').listen((data) {
      chats(data);
      print("Total chat fetched : ${chats.length}");
    });
  }

  // 🔹 Change tab
  void changeTab(int index) {
    selectedTab.value = index;
  }

  // 🔹 Filtered chats based on tab
  List<FBChatModel> get filteredChats {
    if (selectedTab.value == 0) {
      return chats; // All
    }

    final modeKey = _modeForTab(selectedTab.value);

    return chats.where((c) => c.mode == modeKey).toList();
  }

  // 🔹 Group filtered chats by date
  Map<String, List<FBChatModel>> get groupedChats {
    final Map<String, List<FBChatModel>> grouped = {};

    for (final chat in filteredChats) {
      final label = _dateLabel(chat.createdAt);
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(chat);
    }

    return grouped;
  }


  void toggleDeleteMode() {
    isDeleteMode.toggle();
  }

  // 🔥 DELETE SINGLE CHAT
  Future<void> deleteChat(FBChatModel chat) async {
    try {

      await firestoreService.db.collection('chats').doc(chat.id).delete();

      Get.snackbar(
        'Deleted',
        'Chat removed from history',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete chat',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }




  // ---------------- HELPERS ----------------

  String _modeForTab(int index) {
    switch (index) {
      case 1:
        return 'Illustration';
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
