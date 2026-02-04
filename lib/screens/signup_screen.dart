import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/login_screen.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_themes.dart';
import '../utils/asset_utils.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({super.key});

  final AuthController controller = Get.put(AuthController());

  @override
  Widget build(BuildContext context) {
    return GetX<ThemeController>(
      builder: (themeController) {
        final isDark = themeController.isDarkMode.value;
        
        return Scaffold(
          backgroundColor: isDark 
              ? AppColors.darkBackground 
              : AppColors.lightBackground,
          appBar: AppBar(
            title: Text(
              "Sign Up",
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                /// Icon
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryBlue.withOpacity(isDark ? 0.2 : 0.1),
                  child:  Image.asset(AssetUtils.LOGO)
                ),

                const SizedBox(height: 30),

                Text(
                  "Let's get started!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create an account to begin your\nlearning journey.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                /// Name
                InputField(
                  label: "Full Name",
                  hint: "Your name",
                  icon: Icons.person_outline,
                  controller: controller.nameCtrl,
                  focusNode: controller.nameFocus,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                /// Email
                InputField(
                  label: "Email Address",
                  hint: "hello@student.edu",
                  icon: Icons.mail_outline,
                  controller: controller.emailCtrl,
                  focusNode: controller.emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                /// Password
                Obx(() {
                  return InputField(
                    label: "Password",
                    hint: "Min. 8 characters",
                    icon: Icons.lock_outline,
                    controller: controller.passwordCtrl,
                    focusNode: controller.passwordFocus,
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
                      onPressed: () =>
                          controller.obscurePassword.toggle(),
                    ),
                  );
                }),

                const SizedBox(height: 40),

                /// Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: Obx(() => ElevatedButton(
                    onPressed: () async {
                     controller.isLoading.value ? null : await controller.registerUser();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: controller.isLoading.value
                        ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white,))
                        : const Text(
                      "Sign Up",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  )),
                ),

                const SizedBox(height: 30),

                /// Divider
                Row(
                  children: [
                    Expanded(child: Divider(
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "OR CONTINUE WITH",
                        style: TextStyle(
                          color: isDark 
                              ? AppColors.darkTextTertiary 
                              : AppColors.lightTextTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    )),
                  ],
                ),

                const SizedBox(height: 30),

                /// Social buttons
                Row(
                  children: [
                    Expanded(child: GoogleButton(isDark: isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: AppleButton(isDark: isDark)),
                  ],
                ),

                const SizedBox(height: 30),

                /// Login
                GestureDetector(
                  onTap: () => Get.to(() => LoginScreen()),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark 
                            ? AppColors.darkTextSecondary 
                            : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: "Already have an account? "),
                        TextSpan(
                          text: "Log In",
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}


class GoogleButton extends StatelessWidget {
  final bool isDark;
  
  const GoogleButton({super.key, this.isDark = false});
  
  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    
    return Obx(() => OutlinedButton(
      onPressed: authController.googleLoading.value 
          ? null 
          : () => authController.signInWithGoogle(),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: isDark ? AppColors.darkCard : Colors.transparent,
        side: BorderSide(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: authController.googleLoading.value
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png',
                  height: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  "Google",
                  style: TextStyle(
                    color: isDark 
                        ? AppColors.darkTextPrimary 
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    ));
  }
}


class AppleButton extends StatelessWidget {
  final bool isDark;
  
  const AppleButton({super.key, this.isDark = false});
  
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        // TODO: Apple Sign-In
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: isDark ? AppColors.darkCard : Colors.transparent,
        side: BorderSide(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apple,
            color: isDark 
                ? AppColors.darkTextPrimary 
                : AppColors.lightTextPrimary,
          ),
          const SizedBox(width: 10),
          Text(
            "Apple",
            style: TextStyle(
              color: isDark 
                  ? AppColors.darkTextPrimary 
                  : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class InputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType keyboardType;
  final bool isDark;

  const InputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    this.obscureText = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        StatefulBuilder(
          builder: (context, setState) {
            focusNode.addListener(() => setState(() {}));

            final isActive =
                focusNode.hasFocus || controller.text.isNotEmpty;

            return TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: isDark 
                      ? AppColors.darkTextSecondary 
                      : AppColors.lightTextSecondary,
                ),
                suffixIcon: suffix,
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark 
                      ? AppColors.darkTextTertiary 
                      : AppColors.lightTextTertiary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkDivider : const Color(0xFFE9ECEF),
                  ),
                ),
                enabledBorder: _border(
                    isActive 
                        ? AppColors.primaryBlue 
                        : (isDark ? AppColors.darkDivider : Colors.grey.shade300)),
                focusedBorder: _border(AppColors.primaryBlue),
              ),
            );
          },
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return  OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color:color,width: 1.5),
    );
  }
}
