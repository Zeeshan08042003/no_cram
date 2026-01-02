import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  var controller = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Subtle off-white background
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // Logo Container
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.school,
                    size: 50, color: Color(0xFF00BFFF)),
              ),
            ),

            const SizedBox(height: 40),

            // Header Text
            const Text(
              "Welcome Back",
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 12),
            const Text(
              "Sign in to continue your learning\njourney.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF707B81), fontSize: 16, height: 1.5),
            ),

            const SizedBox(height: 40),

            // Input Fields
            InputField(
              label: "Email",
              hint: "Enter email",
              icon: Icons.person_outline,
              controller: controller.loginEmailCtrl,
              focusNode: controller.loginEmailFocus,
            ),
            const SizedBox(height: 24),
            Obx(() {
              return InputField(
                label: "Password",
                hint: "Min. 8 characters",
                icon: Icons.lock_outline,
                controller: controller.loginPasswordCtrl,
                focusNode: controller.loginPasswordFocus,
                obscureText: controller.obscurePassword.value,
                suffix: IconButton(
                  icon: Icon(
                    controller.obscurePassword.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => controller.obscurePassword.toggle(),
                ),
              );
            }),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                      color: Color(0xFF00BFFF), fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Log In Button
            Obx(()=>
               SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    controller.loginLoading.value
                        ? null
                        : await controller.loginUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Log In",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Divider
            Row(
              children: const [
                Expanded(
                    child: Divider(color: Color(0xFFE9ECEF), thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Or continue with",
                      style: TextStyle(color: Color(0xFF707B81), fontSize: 14)),
                ),
                Expanded(
                    child: Divider(color: Color(0xFFE9ECEF), thickness: 1)),
              ],
            ),

            const SizedBox(height: 30),

            // Social Buttons
            Row(
              children: [
                Expanded(child: GoogleButton()),
                const SizedBox(width: 16),
                Expanded(child: AppleButton()),
              ],
            ),

            const SizedBox(height: 40),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? ",
                    style: TextStyle(color: Color(0xFF707B81))),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                        color: Color(0xFF00BFFF), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Password Field Component
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: "Enter password",
            hintStyle: const TextStyle(color: Color(0xFFC1C7CD)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF707B81)),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
            ),
          ),
        ),
      ],
    );
  }

  // Social Button Component
  Widget _buildSocialButton(
      {required String label, required IconData iconPath}) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconPath, size: 24),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
