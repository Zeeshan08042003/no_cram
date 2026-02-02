import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme modes available in the app
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Controller to manage app theme state globally
class ThemeController extends GetxController {
  static const String _themeKey = 'theme_mode';
  
  /// Current theme mode preference
  final Rx<AppThemeMode> themeMode = AppThemeMode.system.obs;
  
  /// Whether dark mode is currently active (based on preference + system)
  final RxBool isDarkMode = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
    _listenToSystemBrightness();
  }
  
  /// Load saved theme preference from storage
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);
    
    if (savedMode != null) {
      themeMode.value = AppThemeMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => AppThemeMode.system,
      );
    }
    
    _updateDarkModeState();
  }
  
  /// Listen to system brightness changes
  void _listenToSystemBrightness() {
    final window = SchedulerBinding.instance.platformDispatcher;
    window.onPlatformBrightnessChanged = () {
      if (themeMode.value == AppThemeMode.system) {
        _updateDarkModeState();
        Get.forceAppUpdate();
      }
    };
  }
  
  /// Get current system brightness
  Brightness get systemBrightness {
    return SchedulerBinding.instance.platformDispatcher.platformBrightness;
  }
  
  /// Update the isDarkMode state based on current preference
  void _updateDarkModeState() {
    switch (themeMode.value) {
      case AppThemeMode.system:
        isDarkMode.value = systemBrightness == Brightness.dark;
        break;
      case AppThemeMode.light:
        isDarkMode.value = false;
        break;
      case AppThemeMode.dark:
        isDarkMode.value = true;
        break;
    }
  }
  
  /// Set theme mode and persist preference
  Future<void> setThemeMode(AppThemeMode mode) async {
    themeMode.value = mode;
    _updateDarkModeState();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    
    // Force update app theme
    Get.changeThemeMode(_getThemeMode());
  }
  
  /// Toggle between light and dark (ignores system)
  Future<void> toggleTheme() async {
    if (isDarkMode.value) {
      await setThemeMode(AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.dark);
    }
  }
  
  /// Cycle through: System -> Light -> Dark -> System
  Future<void> cycleTheme() async {
    switch (themeMode.value) {
      case AppThemeMode.system:
        await setThemeMode(AppThemeMode.light);
        break;
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        await setThemeMode(AppThemeMode.system);
        break;
    }
  }
  
  /// Get Flutter ThemeMode for GetMaterialApp
  ThemeMode _getThemeMode() {
    switch (themeMode.value) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
  
  /// Get current theme mode for GetMaterialApp
  ThemeMode get currentThemeMode => _getThemeMode();
  
  /// Get icon for current theme mode
  IconData get themeIcon {
    switch (themeMode.value) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
    }
  }
  
  /// Get label for current theme mode
  String get themeLabel {
    switch (themeMode.value) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }
}
