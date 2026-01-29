import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/credit_controller.dart';
import '../controllers/subscription_controller.dart';
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

