import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nocram/controllers/subscription_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/main_screen.dart';
import '../services/firebase/firestore_service.dart';

class AuthController extends GetxController{
  var obscurePassword = true.obs;
  var isLoading = false.obs;
  var loginLoading = false.obs;
  var googleLoading = false.obs;
  
  // Google Sign-In instance (6.x API)
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;


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

  var subscriptionController = Get.find<SubscriptionController>();

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
      var pref = await SharedPreferences.getInstance();
      var userId = pref.getString('userId');
      subscriptionController.init(userId??'');

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

  /// Google Sign-In using 6.x API
  Future<void> signInWithGoogle() async {
    googleLoading(true);
    
    try {
      // 1️⃣ Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        googleLoading(false);
        return;
      }
      
      // 2️⃣ Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 3️⃣ Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // 4️⃣ Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user == null) {
        throw Exception('Google Sign-In failed');
      }
      
      // 5️⃣ Store user in Firestore (if new user)
      await FirestoreService().storeGoogleUser(user);
      
      // 6️⃣ Save userId to SharedPreferences
      final pref = await SharedPreferences.getInstance();
      await pref.setString('userId', user.uid);
      
      // 7️⃣ Initialize subscription
      subscriptionController.init(user.uid);
      
      // ✅ SUCCESS → Navigate to main screen
      googleLoading(false);
      Get.offAll(() => MainScreen());
      
      Get.snackbar(
        'Welcome!',
        'Signed in as ${user.displayName ?? user.email}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
      
    } catch (e) {
      googleLoading(false);
      print('❌ Google Sign-In error: $e');
      
      Get.snackbar(
        'Sign-In Failed',
        _mapAuthError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  /// Sign out (for Google and Firebase)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      final pref = await SharedPreferences.getInstance();
      await pref.remove('userId');
      
      print('✅ User signed out');
    } catch (e) {
      print('❌ Sign out error: $e');
    }
  }
}