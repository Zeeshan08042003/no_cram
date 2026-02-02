import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import '../services/ai/explain_image_ai_service.dart';
import '../services/widgets/credit_balance_widget.dart';
import '../utils/app_themes.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  var controller = Get.put(ChatController());

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        // allow bottom nav to handle the bottom inset, avoid double padding
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // ensures scrolling when content is taller than available space
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                // make the SingleChildScrollView fill the available height so
                // Spacer() and layout behave properly
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Top Row...
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Icon(Icons.school,
                                  color: AppColors.primaryBlue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No Cram',
                                style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary),
                              ),
                            ),
                            // Dynamic credit balance widget
                            const CreditBalanceWidget(compact: true),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // Greeting
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey 👋',
                                style: TextStyle(
                                    fontSize: 28, 
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Text('What shall we learn today?',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                  )),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Choose a learning style - circular horizontal list
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Choose a learning style',
                              style: TextStyle(
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: Obx(() {
                            return ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                const SizedBox(width: 2),
                                ChoiceChipCard(
                                  label: 'Illustration',
                                  icon: Icons.image_search_outlined,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.illustration,
                                  onTap: () => controller
                                      .changeMode(ChatMode.illustration),
                                  selectedColor: AppColors.primaryBlue,
                                  unselectedColor: context.cardColor,
                                  labelColor: isDark ? Colors.white : Colors.black,
                                  selectedLabelColor: isDark ? Colors.white : Colors.black,
                                  borderColor: context.dividerColor,
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Story',
                                  icon: Icons.menu_book_outlined,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.storyTelling,
                                  onTap: () => controller
                                      .changeMode(ChatMode.storyTelling),
                                  selectedColor: AppColors.primaryBlue,
                                  unselectedColor: context.cardColor,
                                  labelColor: isDark ? Colors.white : Colors.black,
                                  selectedLabelColor: isDark ? Colors.white : Colors.black,
                                  borderColor: context.dividerColor,
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Image Explanation',
                                  icon: Icons.search,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.explainImage,
                                  onTap: () => controller
                                      .changeMode(ChatMode.explainImage),
                                  selectedColor: AppColors.primaryBlue,
                                  unselectedColor: context.cardColor,
                                  labelColor: isDark ? Colors.white : Colors.black,
                                  selectedLabelColor: isDark ? Colors.white : Colors.black,
                                  borderColor: context.dividerColor,
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Video',
                                  icon: Icons.play_circle_outline,
                                  isSelected: false, // Never selected since it's coming soon
                                  onTap: () {
                                    // Show Coming Soon snackbar
                                    Get.snackbar(
                                      '',
                                      '',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.primaryBlue,
                                      duration: const Duration(seconds: 2),
                                      margin: const EdgeInsets.all(16),
                                      borderRadius: 12,
                                      icon: const Icon(Icons.rocket_launch, color: Colors.white),

                                      titleText: const Text(
                                        '🎬 Coming Soon!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),

                                      messageText: const Text(
                                        'Video explanations are on the way. Stay tuned!',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                  selectedColor: AppColors.primaryBlue,
                                  unselectedColor: context.cardColor,
                                  labelColor: isDark ? Colors.white70 : Colors.black45, // Slightly faded to indicate unavailable
                                  selectedLabelColor: isDark ? Colors.white : Colors.black,
                                  borderColor: context.dividerColor,
                                ),
                                const SizedBox(width: 6),
                              ],
                            );
                          }),
                        ),

                        const SizedBox(height: 18),

                        // INPUT CARD (main)
                        _buildInputCard(context),

                        const SizedBox(height: 16),

                        // Try asking chips
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('TRY ASKING:',
                              style: TextStyle(
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w700)),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _pill(context, 'Explain photosynthesis', Icons.eco),
                            _pill(context, 'Algebra basics', Icons.square_foot),
                            _pill(context, 'Why do volcanoes erupt?', Icons.whatshot),
                          ],
                        ),

                        // This pushes content up so bottom nav doesn't overlap
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final isDark = context.isDark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 12)
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded multi-line TextField (min 4 lines, grows as needed)
          Obx(() {
            final imageList = controller.selectedImageBytesList;

            if (imageList.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image count indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '${imageList.length} image${imageList.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (imageList.length > 1)
                          GestureDetector(
                            onTap: () => controller.clearImages(),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Horizontal scrollable image thumbnails
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageList.length,
                      itemBuilder: (context, index) {
                        final bytes = imageList[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  var imageWidget = Image.memory(bytes, fit: BoxFit.cover);
                                  controller.showImageInDialog(imageWidget);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    bytes,
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => controller.removeImageAt(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),

          TextField(
            controller: controller.textController,
            minLines: 4,
            maxLines: null, // unlimited
            keyboardType: TextInputType.multiline,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: "Help me understand Newton's 2nd law of motion...",
              hintStyle: TextStyle(color: context.textTertiary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),

          const SizedBox(height: 12),

          // Buttons row aligned to the bottom-right
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppColors.primaryBlue.withOpacity(0.15)
                      : const Color(0xFFEFF7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () async {
                    await ExplainImageAiService().chooseImageSourceForExplain();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(Icons.photo, color: AppColors.primaryBlue),
                ),
              ),

              const SizedBox(width: 10),

              // Spacer pushes the buttons to the right
              const Spacer(),

              // Teach Me button - Optimized for fast response
              Obx(() {
                final text = controller.textValue.value.trim();
                final mode = controller.selectedMode.value;
                final hasImages = controller.selectedImageBytesList.isNotEmpty;
                
                final isEnabled = mode != ChatMode.defaultMode &&
                    text.isNotEmpty &&
                    (mode != ChatMode.explainImage || hasImages);
                
                return ElevatedButton(
                  onPressed: () {
                    if (isEnabled) {
                      controller.sendMessage();
                    } else {
                      _showRequirementDialog(context, mode, text.isEmpty, hasImages);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled 
                        ? AppColors.primaryBlue 
                        : AppColors.primaryBlue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text('Teach Me',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, 
                          color: isEnabled ? Colors.white : Colors.white.withOpacity(0.6))),
                );
              }),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRequirementDialog(BuildContext context, ChatMode mode, bool textEmpty, bool hasImages) {
    String title;
    String message;
    
    if (mode == ChatMode.defaultMode && textEmpty) {
      title = 'Get Started';
      message = 'Please choose a learning style and enter what you want to learn.';
    } else if (mode == ChatMode.defaultMode && !textEmpty) {
      title = 'Choose a Learning Style';
      message = 'Please select how you want to learn (Illustration, Story, Image Explanation, or Video) before proceeding.';
    } else if (mode != ChatMode.defaultMode && textEmpty) {
      title = 'Enter Your Question';
      message = "Ask a question and let's learn it step by step.";
    } else if (mode == ChatMode.explainImage && !hasImages) {
      title = 'Add an Image';
      message = 'Please select at least one image to explain.';
    } else {
      title = 'Almost There!';
      message = 'Please complete all required fields to continue.';
    }
    
    Get.dialog(
      AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.school, 
              color: AppColors.primaryBlue,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Got it',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text, IconData? icon) {
    final isDark = context.isDark;
    
    return GestureDetector(
      onTap: () {
        controller.textController.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03), 
                blurRadius: 6)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 16, color: context.textSecondary),
            if (icon != null) const SizedBox(width: 8),
            Text(text,
                style: TextStyle(fontSize: 13, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class ChoiceChipCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color? labelColor;
  final Color? selectedLabelColor;
  final Color? borderColor;
  final double size;

  const ChoiceChipCard({
    Key? key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.selectedColor = const Color(0xFF1A73E8),
    this.unselectedColor = Colors.white,
    this.selectedIconColor = Colors.black,
    this.unselectedIconColor = const Color(0xFF6B6B6B),
    this.labelColor,
    this.selectedLabelColor,
    this.borderColor,
    this.size = 70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Visual decisions
    final outerBg = isSelected ? selectedColor : unselectedColor;
    final effectiveBorderColor = isSelected ? Colors.transparent : (borderColor ?? Colors.grey.shade300);
    final innerCircleColor = isSelected ? Colors.white : Colors.transparent;
    final iconColor = isSelected ? selectedIconColor : unselectedIconColor;
    final effectiveLabelColor = isSelected 
        ? (selectedLabelColor ?? selectedIconColor) 
        : (labelColor ?? Colors.black87);
    final shadow = isSelected
        ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: outerBg,
                shape: BoxShape.circle,
                border: Border.all(color: effectiveBorderColor),
                boxShadow: shadow ?? [],
              ),
              child: Center(
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    color: innerCircleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: size * 0.36, color: iconColor)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: effectiveLabelColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
