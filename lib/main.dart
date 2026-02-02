import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controllers/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'services/firebase/firebase_config.dart';
import 'utils/app_themes.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupFirebaseRemoteConfig();
  await Constants().checkAndRequestPermissions();
  
  // Initialize theme controller before running app
  Get.put(ThemeController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return GetX<ThemeController>(
      builder: (themeController) {
        return GetMaterialApp(
          title: 'NoCram',
          debugShowCheckedModeBanner: false,
          
          // Theme configuration
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeController.currentThemeMode,
          
          home: Splashscreen(),
        );
      },
    );
  }
}
