import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/history_controller.dart';
import '../models/chat_mode.dart';
import '../utils/app_themes.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _tabs = [
    Tab(text: 'All'),
    Tab(text: 'Illustration'),
    Tab(text: 'Story'),
    Tab(text: 'Video'),
  ];

  @override
  Widget build(BuildContext context) {
    Get.put(HistoryController());
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildTabBar(context),
              Expanded(child: _buildHistoryList(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- APP BAR ----------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: context.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),

          // Edit button - only show if there are conversations
          Obx(() {
            final controller = Get.find<HistoryController>();
            final hasConversations = controller.allConversations.isNotEmpty;
            
            if (!hasConversations) {
              return const SizedBox.shrink();
            }
            
            final isActive = controller.isDeleteMode.value;

            return ElevatedButton(
              onPressed: controller.toggleDeleteMode,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    isActive ? AppColors.primaryBlue : context.cardColor,
                foregroundColor:
                    isActive ? Colors.white : AppColors.primaryBlue,
                side: BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.5,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                isActive ? 'Done' : 'Edit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  // ---------------- TAB BAR ----------------

  Widget _buildTabBar(BuildContext context) {
    final controller = Get.find<HistoryController>();
    return TabBar(
      isScrollable: true,

      // 👇 This controls start/end spacing precisely
      padding: const EdgeInsets.only(left: 16, right: 16),
      tabAlignment: TabAlignment.start,
      // Disable default indicator
      indicatorColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,

      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      onTap: (index) {
        // Video tab (index 3) - show Coming Soon
        if (index == 3) {
          Get.snackbar(
            '🎬 Coming Soon!',
            'Video explanations are on the way. Stay tuned!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.primaryBlue,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.rocket_launch, color: Colors.white),
          );
          // Stay on current tab
          DefaultTabController.of(context).animateTo(controller.selectedTab.value);
          return;
        }
        controller.changeTab(index);
      },
      tabs: _tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final tab = entry.value;
        // Make Video tab slightly faded
        return _ChipTab(
          label: tab.text!, 
          isDisabled: index == 3,
        );
      }).toList(),
    );
  }

  // ---------------- HISTORY LIST ----------------

  Widget _buildHistoryList(BuildContext context) {
    final controller = Get.find<HistoryController>();

    return Obx(() {
      final grouped = controller.groupedConversations;

      if (controller.allConversations.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              'No history yet',
              style: TextStyle(
                fontSize: 16,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) {
            final dateLabel = entry.key;
            final conversations = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, dateLabel),
                  ...conversations.map((conv) => _buildHistoryItemFromConversation(context, conv)).toList(),
                ],
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------- HISTORY ITEM ----------------

  Widget _buildHistoryItemFromConversation(BuildContext context, FBConversationModel conversation) {
    final controller = Get.find<HistoryController>();
    final iconData = _iconForMode(conversation.latestMode);
    final iconColor = _colorForMode(conversation.latestMode);
    
    // Get the first chat's user input for preview
    final previewText = controller.getConversationPreview(conversation);
    final chatCount = controller.getChatCount(conversation);
    
    // Get first image URL if available
    final firstChat = conversation.chats.isNotEmpty ? conversation.chats.first : null;
    final hasImage = firstChat?.userInput.hasImages ?? false;
    final firstImageUrl = firstChat?.userInput.firstImageUrl;

    return Obx(() {
      final isDeleteMode = controller.isDeleteMode.value;
      final isDark = context.isDark;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 0),

          // ---------- LEADING ----------
          leading: Container(
            padding: hasImage
                ? EdgeInsets.zero
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
              border: hasImage
                  ? Border.all(color: context.dividerColor)
                  : null,
            ),
            child: hasImage && firstImageUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 40,
                width: 40,
                child: Image.network(
                  firstImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(iconData, color: iconColor, size: 22),
                ),
              ),
            )
                : Icon(iconData, color: iconColor, size: 22),
          ),

          // ---------- TEXT ----------
          title: Text(
            previewText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            '${conversation.latestMode.capitalizeFirst} • ${_formatTime(conversation.createdAt)}${chatCount > 1 ? ' • $chatCount chats' : ''}',
            style: TextStyle(fontSize: 11, color: context.textSecondary),
          ),

          // ---------- TRAILING ----------
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),

            child: isDeleteMode
                ? GestureDetector(
              key: const ValueKey('delete'),
              onTap: () {
                Get.defaultDialog(
                  title: 'Delete conversation?',
                  titlePadding: const EdgeInsets.all(16),
                  // contentPadding: EdgeInsets.symmetric(),
                  titleStyle: TextStyle(color: context.textPrimary),
                  middleText:
                  'This conversation and all its chats will be permanently removed.',
                  middleTextStyle: TextStyle(color: context.textSecondary),
                  backgroundColor: context.cardColor,
                  confirm: ConfirmRedButton(
                    onTap: () {
                      Get.back();
                      controller.deleteConversation(conversation);
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
                : Icon(
              Icons.chevron_right,
              key: const ValueKey('arrow'),
              color: context.textTertiary,
            ),
          ),

          // ---------- TAP ----------
          onTap: isDeleteMode
              ? null // 🚫 disable navigation in delete mode
              : () {
            final isLegacy = controller.isLegacyChat(conversation);
            Get.to(() => ResultScreen.conversation(conversation, isLegacy: isLegacy));
          },
        ),
      );
    });
  }
}


class _ChipTab extends StatelessWidget {
  final String label;
  final bool isDisabled;
  const _ChipTab({required this.label, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    final tabController = DefaultTabController.of(context)!;
    final isDark = context.isDark;

    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final isSelected = !isDisabled && tabController.index == _tabIndex(label);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : context.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryBlue : context.dividerColor,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              // Faded text for disabled tabs
              color: isDisabled 
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : (isSelected ? Colors.white : context.textPrimary),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }

  int _tabIndex(String label) {
    switch (label) {
      case 'All':
        return 0;
      case 'Illustration':
        return 1;
      case 'Story':
        return 2;
      case 'Video':
        return 3;
      default:
        return 0;
    }
  }
}

IconData _iconForMode(String mode) {
  switch (mode.toLowerCase()) {
    case 'illustration':
      return Icons.palette_outlined;
    case 'storytelling':
      return Icons.menu_book_outlined;
    case 'explainimage':
      return Icons.image_search_outlined;
    case 'video':
      return Icons.play_circle_outline;
    default:
      return Icons.chat_bubble_outline;
  }
}

Color _colorForMode(String mode) {
  switch (mode.toLowerCase()) {
    case 'illustration':
      return Colors.purple;
    case 'storytelling':
      return Colors.blue;
    case 'explainimage':
      return Colors.green;
    case 'video':
      return Colors.deepOrange;
    default:
      return Colors.grey;
  }
}

String _formatTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} hrs ago';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class HistoryItem {
  final String title;
  final String type;
  final String time;
  final Color iconColor;
  final IconData icon;

  HistoryItem(this.title, this.type, this.time, this.iconColor, this.icon);
}

final historyData = {
  'TODAY': [
    HistoryItem('The French Revolution', 'Story', '2 hours ago', Colors.blue,
        Icons.book),
    HistoryItem('Cell Structure Diagram', 'Illustration', '4 hours ago',
        Colors.purple, Icons.palette),
  ],
  'YESTERDAY': [
    HistoryItem('Calculus Derivatives', 'Scan', '4:00 PM', Colors.green,
        Icons.qr_code_scanner),
    HistoryItem('How engines work', 'Video', '2:15 PM', Colors.deepOrange,
        Icons.play_circle_fill),
  ],
};

class ConfirmRedButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const ConfirmRedButton({
    super.key,
    this.text = 'Delete',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
