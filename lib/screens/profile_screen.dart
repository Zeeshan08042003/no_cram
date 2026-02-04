import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/credit_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';
import '../utils/app_themes.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var userModel = UserModel();
  var firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final pref = await SharedPreferences.getInstance();
    final userId = pref.getString('userId');

    if (userId == null) return;

    firestore.getUserDetails(userId).listen((user) {
      setState(() {
        userModel = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Header with title and theme toggle
                _buildHeader(context),
                const SizedBox(height: 30),
                // Profile Avatar and Info
                _buildProfileInfo(context),
                const SizedBox(height: 30),
                // Usage Status Card
                _buildUsageStatusCard(context),
                // const SizedBox(height: 30),
                // // Preferences Section
                // _buildSectionTitle(context, "PREFERENCES"),
                // const SizedBox(height: 12),
                // _buildPreferencesCard(context),
                const SizedBox(height: 30),
                // Account & Support Section
                _buildSectionTitle(context, "ACCOUNT & SUPPORT"),
                const SizedBox(height: 12),
                _buildAccountSupportCard(context),
                const SizedBox(height: 30),
                // Logout Button
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Profile",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        // Theme Toggle Button
        GetX<ThemeController>(
          builder: (themeController) {
            return GestureDetector(
              onTap: () => _showThemeSelector(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(context.isDark ? 0.3 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  themeController.themeIcon,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Choose Theme",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select your preferred appearance",
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Theme Options
              Obx(() => _buildThemeOption(
                context,
                icon: Icons.brightness_auto,
                title: "System",
                subtitle: "Follow device settings",
                isSelected: themeController.themeMode.value == AppThemeMode.system,
                onTap: () {
                  themeController.setThemeMode(AppThemeMode.system);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 12),
              Obx(() => _buildThemeOption(
                context,
                icon: Icons.light_mode,
                title: "Light",
                subtitle: "Always use light mode",
                isSelected: themeController.themeMode.value == AppThemeMode.light,
                onTap: () {
                  themeController.setThemeMode(AppThemeMode.light);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 12),
              Obx(() => _buildThemeOption(
                context,
                icon: Icons.dark_mode,
                title: "Dark",
                subtitle: "Always use dark mode",
                isSelected: themeController.themeMode.value == AppThemeMode.dark,
                onTap: () {
                  themeController.setThemeMode(AppThemeMode.dark);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue.withOpacity(0.1)
              : context.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryBlue 
                : context.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primaryBlue.withOpacity(0.2)
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? AppColors.primaryBlue 
                    : context.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryBlue,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    return Row(
      children: [
        // Profile Avatar with Edit Badge
        Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentGold,
                    const Color(0xFFE8B86D),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8B86D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            // Edit Badge
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.accentTeal],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.backgroundColor,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Name and Email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userModel.firstName ?? 'User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userModel.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageStatusCard(BuildContext context) {
    return GetX<CreditController>(
      builder: (controller) {
        final total = controller.totalCreditsEarned;
        final used = controller.usedCredits;
        final progress = total > 0 ? used / total : 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.isDark
                  ? [
                      AppColors.darkCard,
                      AppColors.darkSurface,
                    ]
                  : [
                      const Color(0xFFE8F4F8).withOpacity(0.9),
                      const Color(0xFFF0F8FF).withOpacity(0.9),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.isDark 
                  ? AppColors.darkDivider
                  : Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentTeal.withOpacity(context.isDark ? 0.1 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              SizedBox(height: 5,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "USAGE STATUS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: "Credits Used: ",
                          style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: "$used",
                          style: const TextStyle(
                            color: AppColors.accentTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: " / $total",
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Visibility(
                  visible: progress != 0,
                  child: SizedBox(height: 20)),
              // Progress Bar
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: context.isDark 
                      ? AppColors.darkDivider 
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentTeal, AppColors.primaryGreen],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Buy Credits Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentTeal, AppColors.primaryGreen],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () => controller.showBuyCreditsSheet(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Buy Credits",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Theme Setting
          GetX<ThemeController>(
            builder: (themeController) {
              return _buildSettingTile(
                context,
                icon: themeController.themeIcon,
                iconColor: AppColors.primaryBlue,
                iconBgColor: AppColors.primaryBlue.withOpacity(0.1),
                title: "Theme",
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      themeController.themeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textTertiary,
                      size: 24,
                    ),
                  ],
                ),
                onTap: () => _showThemeSelector(context),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSupportCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSupportTile(
            context,
            icon: Icons.mail_outline_rounded,
            iconColor: const Color(0xFF4A90E2),
            iconBgColor: context.isDark 
                ? const Color(0xFF4A90E2).withOpacity(0.2)
                : const Color(0xFFE3F2FD),
            title: "Contact Us",
            onTap: () => _launchEmail(),
          ),
          _buildDivider(context),
          _buildSupportTile(
            context,
            icon: Icons.description_outlined,
            iconColor: AppColors.primaryPurple,
            iconBgColor: context.isDark 
                ? AppColors.primaryPurple.withOpacity(0.2)
                : const Color(0xFFF3E5F5),
            title: "Terms of Use",
            onTap: () => _launchUrl("https://nocram.app/terms"),
          ),
          _buildDivider(context),
          _buildSupportTile(
            context,
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.primaryGreen,
            iconBgColor: context.isDark 
                ? AppColors.primaryGreen.withOpacity(0.2)
                : const Color(0xFFE0F7EF),
            title: "Privacy Policy",
            onTap: () => _launchUrl("https://nocram.app/privacy"),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textTertiary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 76),
      child: Divider(
        height: 1,
        color: context.dividerColor,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark 
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFFFFE5E5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(context.isDark ? 0.1 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showLogoutDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade400,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  "Log Out",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@nocram.app',
      queryParameters: {
        'subject': 'Support Request - NoCram App',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}