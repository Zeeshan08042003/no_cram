import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import '../services/widgets/credit_balance_widget.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  var controller = Get.put(ChatController());

  // Color palette (from earlier)
  final Color primaryBlue = const Color(0xFF1A73E8);
  final Color accentGreen = const Color(0xFF34A853);
  final Color warmYellow = const Color(0xFFFBBC05);
  final Color softRed = const Color(0xFFEA4335);
  final Color bg = const Color(0xFFF6F8FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
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
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Icon(Icons.school,
                                  color: primaryBlue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Teach Me',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
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
                            children: const [
                              Text(
                                'Hey 👋',
                                style: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text('What shall we learn today?',
                                  style: TextStyle(
                                    color: Colors.grey,
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
                                  color: Colors.grey[700],
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
                                  selectedColor:
                                      primaryBlue, // visible when selected
                                  unselectedColor:
                                      Colors.white, // visible when unselected
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Story',
                                  icon: Icons.menu_book_outlined,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.storyTelling,
                                  onTap: () => controller
                                      .changeMode(ChatMode.storyTelling),
                                  selectedColor:
                                      primaryBlue, // green when selected
                                  unselectedColor: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Image Explanation',
                                  icon: Icons.search,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.explainImage,
                                  onTap: () => controller
                                      .changeMode(ChatMode.explainImage),
                                  selectedColor:
                                      primaryBlue, // green when selected
                                  unselectedColor: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                ChoiceChipCard(
                                  label: 'Video',
                                  icon: Icons.play_circle_outline,
                                  isSelected: controller.selectedMode.value ==
                                      ChatMode.video,
                                  onTap: () =>
                                      controller.changeMode(ChatMode.video),
                                  selectedColor:
                                      primaryBlue, // green when selected
                                  unselectedColor: Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                            );
                          }),
                        ),

                        const SizedBox(height: 18),

                        // INPUT CARD (main)
                        _buildInputCard(),

                        const SizedBox(height: 16),

                        // Try asking chips
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('TRY ASKING:',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w700)),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _pill('Explain photosynthesis', Icons.eco),
                            _pill('Algebra basics', Icons.square_foot),
                            _pill('Why do volcanoes erupt?', Icons.whatshot),
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

  Widget _buildInputCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)
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
                            color: Colors.grey[600],
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
            decoration: const InputDecoration(
              hintText: 'Ask anything you want to learn...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),

          const SizedBox(height: 12),

          // Buttons row aligned to the bottom-right
          Row(
            children: [
              // Spacer pushes the buttons to the right
              const Spacer(),

              // Mic button (compact)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () {

                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.mic, color: Colors.blue),
                ),
              ),

              const SizedBox(width: 10),

              // Teach Me button
              ElevatedButton(
                onPressed: controller.sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07A0FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('Teach Me',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Optional 2x2 chip grid (mirror of your ChatScreen)
          // Column(
          //   children: [
          //     Row(
          //       children: [
          //         Expanded(child: _gridChip(ChatMode.draw, 'Illustration')),
          //         const SizedBox(width: 8),
          //         Expanded(child: _gridChip(ChatMode.story, 'Story')),
          //       ],
          //     ),
          //     const SizedBox(height: 8),
          //     Row(
          //       children: [
          //         Expanded(child: _gridChip(ChatMode.analyze, 'Explain Image', isIcon: true)),
          //         const SizedBox(width: 8),
          //         Expanded(child: _gridChip(ChatMode.video, 'Video')),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _gridChip(ChatMode mode, String label, {bool isIcon = false}) {
    return Obx(() {
      final isSelected = controller.selectedMode.value == mode;
      return GestureDetector(
        onTap: () => controller.changeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
                color: isSelected ? Colors.white : Colors.grey.shade300),
          ),
          child: Center(
            child: isIcon
                ? Icon(Icons.image_search_outlined,
                    size: 16, color: isSelected ? Colors.black : Colors.white)
                : Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      );
    });
  }

  Widget _pill(String text, IconData? icon) {
    return GestureDetector(
      onTap: () {
        controller.textController.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 16, color: Colors.grey[700]),
            if (icon != null) const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Home', true),
          _navItem(Icons.history, 'History', false),
          _navItem(Icons.person, 'Profile', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? const Color(0xFF07A0FF) : Colors.grey),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: active ? const Color(0xFF07A0FF) : Colors.grey,
                fontSize: 12)),
      ],
    );
  }
}

class ChoiceChipCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color selectedColor; // background when selected (outer)
  final Color unselectedColor; // background when unselected (outer)
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final double size;

  const ChoiceChipCard({
    Key? key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.selectedColor = const Color(0xFF1A73E8), // primary
    this.unselectedColor = Colors.white,
    this.selectedIconColor = Colors.black,
    this.unselectedIconColor = const Color(0xFF6B6B6B),
    this.size = 70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Visual decisions
    final outerBg = isSelected ? selectedColor : unselectedColor;
    final borderColor = isSelected ? Colors.transparent : Colors.grey.shade300;
    final innerCircleColor = isSelected ? Colors.white : Colors.transparent;
    final iconColor = isSelected ? selectedIconColor : unselectedIconColor;
    final labelColor = isSelected ? selectedIconColor : Colors.black87;
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
                border: Border.all(color: borderColor),
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
                  color: labelColor,
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
