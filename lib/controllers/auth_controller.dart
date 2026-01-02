import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/main_screen.dart';
import '../services/firebase/firestore_service.dart';

class AuthController extends GetxController{
  var obscurePassword = true.obs;
  var isLoading = false.obs;
  var loginLoading = false.obs;


  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final loginEmailCtrl = TextEditingController();
  final loginPasswordCtrl = TextEditingController();

  // Focus nodes
  final nameFocus = FocusNode();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  final loginEmailFocus = FocusNode();
  final loginPasswordFocus = FocusNode();


  Future<void> registerUser() async {
    isLoading(true);
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    final name = nameCtrl.text.trim();

    // 🔴 VALIDATION
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      isLoading(false);
      Get.snackbar(
        'Missing fields',
        'All fields are required',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    if (!GetUtils.isEmail(email)) {
      isLoading(false);
      Get.snackbar(
        'Invalid email',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    if (password.length < 8) {
      isLoading(false);
      Get.snackbar(
        'Weak password',
        'Password must be at least 8 characters',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // 🔐 REGISTER USER
      await FirestoreService().registerAndStoreUser(
        email,
        password,
        name,
      );



      // ✅ SUCCESS
      Get.offAll(() => MainScreen());
      isLoading(false);
      Get.snackbar(
        'Success',
        'Account created successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } catch (e) {
      // ❌ ERROR
      print(e.toString());
      Get.snackbar(
        'Registration failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueAccent,
        colorText: Colors.white,
      );
    }
    isLoading(false);
  }


  Future<void> loginUser() async {
    loginLoading(true);
    final email = loginEmailCtrl.text.trim();
    final password = loginPasswordCtrl.text.trim();

    // 🔴 VALIDATION
    if (email.isEmpty || password.isEmpty) {
      loginLoading(false);
      Get.snackbar(
        'Missing fields',
        'Email and password are required',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    if (!GetUtils.isEmail(email)) {
      loginLoading(false);
      Get.snackbar(
        'Invalid email',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    if (password.length < 8) {
      loginLoading(false);
      Get.snackbar(
        'Invalid password',
        'Password must be at least 8 characters',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // 🔐 LOGIN USER
      await FirestoreService().loginUser(email, password);


      // ✅ SUCCESS → clear back stack
      Get.offAll(() => MainScreen());
      loginLoading(false);

      Get.snackbar(
        'Welcome back',
        'Logged in successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } catch (e) {
      // ❌ ERROR
      Get.snackbar(
        'Login failed',
        _mapAuthError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
    loginLoading(false);
  }




  String _mapAuthError(dynamic error) {
    final message = error.toString();

    if (message.contains('user-not-found')) {
      return 'No account found with this email';
    } else if (message.contains('wrong-password')) {
      return 'Incorrect password';
    } else if (message.contains('invalid-email')) {
      return 'Invalid email address';
    } else if (message.contains('too-many-requests')) {
      return 'Too many attempts. Try again later';
    } else {
      return 'Something went wrong. Please try again';
    }
  }



}