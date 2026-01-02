import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  final BottomNavController nav = Get.put(BottomNavController());

  final pages =  [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  final Color bg = const Color(0xFFF6F8FA);

  @override
  Widget build(BuildContext context) {
    return Obx(
          () => WillPopScope(
        onWillPop: () async {
          // 🔙 If not on Home, go to Home instead of exiting
          if (nav.currentIndex.value != 0) {
            nav.changeTab(0);
            return false; // prevent app close
          }
          return true; // allow app close
        },
        child: Scaffold(
          backgroundColor: bg,
          body: IndexedStack(
            index: nav.currentIndex.value,
            children: pages,
          ),
          bottomNavigationBar: _bottomNavBar(),
        ),
      ),
    );
  }

  Widget _bottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: const Color(0xffFFFFFF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Home', 0),
          _navItem(Icons.history, 'History', 1),
          _navItem(Icons.person, 'Profile', 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final nav = Get.find<BottomNavController>();
    final active = nav.currentIndex.value == index;

    return GestureDetector(
      onTap: () => nav.changeTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF07A0FF) : Colors.grey,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF07A0FF) : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomNavController extends GetxController {
  final currentIndex = 0.obs;

  void changeTab(int index) {
    currentIndex.value = index;
  }
}
