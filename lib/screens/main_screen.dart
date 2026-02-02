import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_themes.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  final BottomNavController nav = Get.put(BottomNavController());

  final pages = [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

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
          backgroundColor: context.backgroundColor,
          body: IndexedStack(
            index: nav.currentIndex.value,
            children: pages,
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: _bottomNavBar(context),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(
            color: context.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home, 'Home', 0),
          _navItem(context, Icons.history, 'History', 1),
          _navItem(context, Icons.person, 'Profile', 2),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index) {
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
            color: active 
                ? AppColors.primaryBlue 
                : context.textTertiary,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active 
                  ? AppColors.primaryBlue 
                  : context.textTertiary,
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
