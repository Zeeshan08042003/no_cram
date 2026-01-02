import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main_screen.dart';
import 'signup_screen.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
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
      // ✅ User already logged in
      Get.offAll(() => MainScreen());
    } else {
      // ❌ No user
      Get.offAll(() =>  SignUpScreen());
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
