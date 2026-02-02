import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import '../screens/signup_screen.dart';
import '../utils/app_themes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  var controller = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return GetX<ThemeController>(
      builder: (themeController) {
        final isDark = themeController.isDarkMode.value;
        
        return Scaffold(
          backgroundColor: isDark 
              ? AppColors.darkBackground 
              : AppColors.lightBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                // Logo Container
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school,
                        size: 50, color: AppColors.primaryBlue),
                  ),
                ),

                const SizedBox(height: 40),

                // Header Text
                Text(
                  "Welcome Back",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark 
                          ? AppColors.darkTextPrimary 
                          : AppColors.lightTextPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign in to continue your learning\njourney.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark 
                          ? AppColors.darkTextSecondary 
                          : AppColors.lightTextSecondary,
                      fontSize: 16,
                      height: 1.5),
                ),

                const SizedBox(height: 40),

                // Input Fields
                InputField(
                  label: "Email",
                  hint: "Enter email",
                  icon: Icons.person_outline,
                  controller: controller.loginEmailCtrl,
                  focusNode: controller.loginEmailFocus,
                  isDark: isDark,
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
                    isDark: isDark,
                    suffix: IconButton(
                      icon: Icon(
                        controller.obscurePassword.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: isDark 
                            ? AppColors.darkTextSecondary 
                            : AppColors.lightTextSecondary,
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
                          color: AppColors.primaryBlue, 
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Log In Button
                Obx(() => SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      controller.loginLoading.value
                          ? null
                          : await controller.loginUser();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
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
                )),

                const SizedBox(height: 30),

                // Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: isDark 
                                ? AppColors.darkDivider 
                                : const Color(0xFFE9ECEF),
                            thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Or continue with",
                          style: TextStyle(
                              color: isDark 
                                  ? AppColors.darkTextSecondary 
                                  : AppColors.lightTextSecondary,
                              fontSize: 14)),
                    ),
                    Expanded(
                        child: Divider(
                            color: isDark 
                                ? AppColors.darkDivider 
                                : const Color(0xFFE9ECEF),
                            thickness: 1)),
                  ],
                ),

                const SizedBox(height: 30),

                // Social Buttons
                Row(
                  children: [
                    Expanded(child: GoogleButton(isDark: isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: AppleButton(isDark: isDark)),
                  ],
                ),

                const SizedBox(height: 40),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: TextStyle(
                            color: isDark 
                                ? AppColors.darkTextSecondary 
                                : AppColors.lightTextSecondary)),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                            color: AppColors.primaryBlue, 
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
