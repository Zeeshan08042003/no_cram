import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/credit_controller.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_themes.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {

  // Initialize controllers globally
  final subscriptionController = Get.put(SubscriptionController());
  final creditController = Get.put(CreditController());

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 800)); // small splash delay

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null && userId.isNotEmpty) {
      // ✅ User already logged in - initialize controllers
      await _initializeControllersForUser(userId);
      Get.offAll(() => MainScreen());
    } else {
      // ❌ No user
      Get.offAll(() =>  SignUpScreen());
    }
  }

  /// Initialize subscription and credit controllers for the logged-in user
  Future<void> _initializeControllersForUser(String userId) async {
    try {
      // Initialize RevenueCat
      await subscriptionController.init(userId);
      
      // CreditController auto-initializes via onInit, 
      // but we can force refresh here
      creditController.listenToCredits(userId);
      
      print('[SPLASH] Controllers initialized for user: $userId');
    } catch (e) {
      print('[SPLASH] Error initializing controllers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetX<ThemeController>(
      builder: (themeController) {
        final isDark = themeController.isDarkMode.value;
        
        return Scaffold(
          backgroundColor: isDark 
              ? AppColors.darkBackground 
              : AppColors.lightBackground,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  'NoCram',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark 
                        ? AppColors.darkTextPrimary 
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Learn smarter, not harder',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark 
                        ? AppColors.darkTextSecondary 
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Loading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
