import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/login_screen.dart';
import '../controllers/auth_controller.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({super.key});

  final AuthController controller = Get.put(AuthController());

  // Controllers


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sign Up",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// Icon
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.withOpacity(.1),
              child: const Icon(Icons.school,
                  size: 40, color: Color(0xFF00BFFF)),
            ),

            const SizedBox(height: 30),

            const Text(
              "Let's get started!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create an account to begin your\nlearning journey.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 30),

            /// Name
            InputField(
              label: "Full Name",
              hint: "Your name",
              icon: Icons.person_outline,
              controller: controller.nameCtrl,
              focusNode: controller.nameFocus,
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
                suffix: IconButton(
                  icon: Icon(
                    controller.obscurePassword.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
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
              child: ElevatedButton(
                onPressed: () async {
                 controller.isLoading.value ? null : await controller.registerUser();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: controller.isLoading.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  "Sign Up",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// Divider
            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "OR CONTINUE WITH",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 30),

            /// Social buttons
            Row(
              children: [
                Expanded(child: GoogleButton()),
                const SizedBox(width: 16),
                Expanded(child: AppleButton()),
              ],
            ),

            const SizedBox(height: 30),

            /// Login
            GestureDetector(
              onTap: () => Get.to(() => LoginScreen()),
              child: RichText(
                text: TextSpan(
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 14),
                  children: [
                    const TextSpan(text: "Already have an account? "),
                    TextSpan(
                      text: "Log In",
                      style: TextStyle(
                        color: Colors.blue.shade500,
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
    );
  }
}


class GoogleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        // TODO: Google Sign-In
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png',
            height: 22,
          ),
          const SizedBox(width: 10),
          const Text(
            "Google",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class AppleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        // TODO: Apple Sign-In
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apple),
          const SizedBox(width: 10),
          const Text(
            "Apple",
            style: TextStyle(
              color: Colors.black,
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

  const InputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    this.obscureText = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.grey),
                suffixIcon: suffix,
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                ),
                enabledBorder: _border(
                    isActive ? const Color(0xFF00BFFF) : Colors.grey.shade300),
                focusedBorder:
                _border(const Color(0xFF00BFFF)),
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
