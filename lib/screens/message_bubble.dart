import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data';
import '../controllers/chat_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:shimmer/shimmer.dart';
import '../services/widgets/download_widget.dart';
import '../utils/app_themes.dart';

class MessageBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final ChatMode? mode;
  final String? imageUrl;
  final String? explainText;
  final Uint8List? imageBytes;
  final List<Uint8List>? imageBytesList;
  final List<String>? imageUrlList;
  final bool animate;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.mode,
    this.imageUrl,
    this.imageBytes,
    this.imageBytesList,
    this.imageUrlList,
    this.explainText,
    this.animate = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  String _visibleText = '';
  Timer? _typingTimer;
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupTypingAnimation();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.mode != widget.mode ||
        oldWidget.animate != widget.animate) {
      _typingTimer?.cancel();
      _visibleText = '';
      _hasAnimated = false;
      _setupTypingAnimation();
    }
  }

  // ───────────────── MARKDOWN RENDERER ─────────────────

  Widget _markdown(String text) {
    final isDark = Get.context != null && Get.context!.isDark;
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        listBullet: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        code: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF4F4F4),
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // ───────────────── TYPING ANIMATION ─────────────────

  void _setupTypingAnimation() {
    final markdownModes = {
      ChatMode.storyTelling,
      ChatMode.explainImage,
      ChatMode.video,
    };

    if (widget.isUser ||
        widget.text.isEmpty ||
        _hasAnimated ||
        !widget.animate ||
        markdownModes.contains(widget.mode) ||
        widget.text.length > 800) {
      _visibleText = widget.text;
      return;
    }

    const delay = Duration(milliseconds: 18);
    int index = 0;

    _typingTimer = Timer.periodic(delay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index >= widget.text.length) {
        timer.cancel();
        _hasAnimated = true;
        return;
      }
      setState(() {
        _visibleText = widget.text.substring(0, index + 1);
      });
      index++;
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isUser && _hasUserImages) {
      return _buildUserImageBubble(context);
    }

    if (!widget.isUser) {
      switch (widget.mode) {
        case ChatMode.illustration:
          return _buildIllustrationBubble(context);
        case ChatMode.video:
          return _buildTextBubble(context,
              label: 'Video Script', icon: Icons.play_circle_outline);
        case ChatMode.explainImage:
          return _buildExplainImageBubble(context);
        case ChatMode.storyTelling:
          return _buildTextBubble(context,
              label: 'Story', icon: Icons.menu_book_outlined);
        case ChatMode.defaultMode:
        default:
          return _buildTextBubble(context,
              label: 'Answer', icon: Icons.school_outlined);
      }
    }

    return _buildUserBubble(context);
  }

  // ───────────────── USER BUBBLES ─────────────────

  /// Check if user message has any images (single or multiple)
  bool get _hasUserImages {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) return true;
    if (widget.imageUrlList != null && widget.imageUrlList!.isNotEmpty) return true;
    if (widget.imageBytesList != null && widget.imageBytesList!.isNotEmpty) return true;
    return false;
  }

  Widget _buildUserBubble(BuildContext context) {
    return UserMessageCard(
      content: SelectableText(widget.text,
          style: const TextStyle(fontSize: 14)),
      accentLabel: 'YOU ASKED',
      accentColor: const Color(0xFF1A73E8),
    );
  }

  Widget _buildUserImageBubble(BuildContext context) {
    // Collect all image widgets (from bytes or URLs)
    final images = <Widget>[];
    
    // 1️⃣ Images from bytes (live chat)
    if (widget.imageBytesList != null && widget.imageBytesList!.isNotEmpty) {
      for (final bytes in widget.imageBytesList!) {
        final img = Image.memory(bytes, fit: BoxFit.cover);
        images.add(_buildUserTapImage(img));
      }
    }
    
    // 2️⃣ Images from URL list (history)
    if (widget.imageUrlList != null && widget.imageUrlList!.isNotEmpty) {
      for (final url in widget.imageUrlList!) {
        final img = url.startsWith('data:image')
            ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover)
            : Image.network(url, fit: BoxFit.cover);
        images.add(_buildUserTapImage(img));
      }
    }
    
    // 3️⃣ Single image URL (legacy)
    if (images.isEmpty && widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      final img = widget.imageUrl!.startsWith('data:image')
          ? Image.memory(base64Decode(widget.imageUrl!.split(',').last), fit: BoxFit.cover)
          : Image.network(widget.imageUrl!, fit: BoxFit.cover);
      images.add(_buildUserTapImage(img));
    }

    // Single image vs multiple images view
    final imageView = images.length == 1
        ? images.first
        : SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: index < images.length - 1 ? 8 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 100, height: 100, child: images[index]),
                ),
              ),
            ),
          );

    return UserMessageCard(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageView,
          ),
          if (widget.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(widget.text,
                style: const TextStyle(fontSize: 14)),
          ]
        ],
      ),
    );
  }

  Widget _buildUserTapImage(Widget image) {
    return GestureDetector(
      onTap: () => showImageInDialog(image),
      child: image,
    );
  }

  // ───────────────── AI BUBBLES ─────────────────

  Widget _buildTextBubble(BuildContext context,
      {String? label, IconData? icon}) {
    return ResponseMessageCard(
      content: _markdown(_visibleText),
      label: label,
      icon: icon,
      isImage: false,
      labelColor: Colors.black,
    );
  }

  Widget _buildExplainImageBubble(BuildContext context) {
    return ResponseMessageCard(
      content: _markdown(_visibleText),
      label: 'Image Explanation',
      icon: Icons.image_search_outlined,
      labelColor: Colors.black,
      isImage: false,
      onCopy: () => _copyCurrentText(context),
    );
  }

  Widget _buildIllustrationBubble(BuildContext context) {
    final images = <Widget>[];

    // 1️⃣ BYTES (live chat)
    if (widget.imageBytesList != null && widget.imageBytesList!.isNotEmpty) {
      for (final b in widget.imageBytesList!) {
        images.add(_buildTapImage(Image.memory(b)));
      }
    }

    // 2️⃣ URLS (history)
    else if (widget.imageUrlList != null && widget.imageUrlList!.isNotEmpty) {
      for (final url in widget.imageUrlList!) {
        images.add(
          _buildTapImage(
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(height: 180, child: _shimmerPage());
              },
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        );
      }
    }

    // 3️⃣ EMPTY STATE (should not normally happen)
    if (images.isEmpty) {
      return ResponseMessageCard(
        label: 'Illustration',
        icon: Icons.image_outlined,
        isImage: true,
        content: Column(
          children: [
            SizedBox(
              height: 200,
              child: _shimmerPage(),
            ),
            SizedBox(height: 8),
            _markdown(_visibleText)
          ],
        ),
      );
    }

    // 4️⃣ SINGLE vs CAROUSEL
    final imageView = images.length == 1
        ? SizedBox(height: 250, child: images.first)
        : SizedBox(
      height: 250,
      child: _ImageCarousel(
        widgets: images,
        isLoading: false,
      ),
    );

    return ResponseMessageCard(
      label: 'Illustration',
      icon: Icons.image_outlined,
      isImage: true,
      onDownload: showDownloadOptions,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageView,
          ),

          // 📝 IMAGE DESCRIPTION (AI TEXT)
          if (widget.explainText?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _markdown(widget.explainText??''),
          ],
        ],
      ),
    );

  }

  Widget _buildTapImage(Widget image) {
    return GestureDetector(
      onTap: () => showImageInDialog(image),
      child: SizedBox(
        height: 180,
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }


  void showDownloadOptions() {
    final isDark = context.isDark;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              title: Text('Download image only', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              onTap: () {
                Get.back();
                downloadImageOnly(
                  imageBytes: widget.imageBytesList?.isNotEmpty == true
                      ? widget.imageBytesList!.first
                      : null,
                  imageUrl: widget.imageUrlList?.isNotEmpty == true
                      ? widget.imageUrlList!.first
                      : null,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              title: Text('Download image with text', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              onTap: () {
                Get.back();
                downloadImageWithText(
                  imageBytes: _primaryImageBytes,
                  imageUrl: _primaryImageUrl,
                  text: widget.explainText ?? widget.text,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? get _primaryImageBytes {
    if (widget.imageBytesList != null &&
        widget.imageBytesList!.isNotEmpty) {
      return widget.imageBytesList!.first;
    }
    return null;
  }

  String? get _primaryImageUrl {
    if (widget.imageUrlList != null &&
        widget.imageUrlList!.isNotEmpty) {
      return widget.imageUrlList!.first;
    }
    return null;
  }

  // ───────────────── HELPERS ─────────────────

  void _copyCurrentText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _downloadImage() async {
    if (!await requestSavePermission()) return;
    if (widget.imageBytesList == null || widget.imageBytesList!.isEmpty) return;

    await SaverGallery.saveImage(
      widget.imageBytesList!.first,
      fileName: 'ai_image_${DateTime.now().millisecondsSinceEpoch}',
      androidRelativePath: 'Pictures/AI Images', skipIfExists: true,
    );
  }

  void showImageInDialog(Widget image) {
    Get.dialog(
      Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: image,
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.85),
    );
  }
}

/// ───────────────── IMAGE CAROUSEL ─────────────────

class _ImageCarousel extends StatefulWidget {
  final List<Widget> widgets;
  final bool isLoading;
  const _ImageCarousel({required this.widgets,this.isLoading = false,});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.isLoading
        ? 3 // shimmer pages count
        : widget.widgets.length;

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: widget.isLoading
                ? List.generate(pageCount, (_) => _shimmerPage())
                : widget.widgets,
          ),
        ),
        const SizedBox(height: 8),

        /// 🔵 Dots Indicator
        // Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: List.generate(
        //     pageCount,
        //         (i) => AnimatedContainer(
        //       duration: const Duration(milliseconds: 200),
        //       margin: const EdgeInsets.symmetric(horizontal: 3),
        //       width: _index == i ? 10 : 6,
        //       height: _index == i ? 10 : 6,
        //       decoration: BoxDecoration(
        //         color: _index == i ? Colors.white : Colors.grey,
        //         shape: BoxShape.circle,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

}

/// ───────────────── PERMISSIONS ─────────────────


Widget _shimmerPage() {
  final isDark = Get.context != null && Get.context!.isDark;
  return Shimmer.fromColors(
    baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
    highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}



Future<bool> requestSavePermission() async {
  if (Platform.isAndroid) {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 29) return true;
    return (await Permission.storage.request()).isGranted;
  }
  if (Platform.isIOS) {
    return (await Permission.photosAddOnly.request()).isGranted;
  }
  return false;
}


class UserMessageCard extends StatelessWidget {
  final Widget content; // Text or Column with text+image
  final String accentLabel;
  final Color accentColor;
  final double maxWidthFactor;

  const UserMessageCard({
    Key? key,
    required this.content,
    this.accentLabel = 'YOU ASKED',
    this.accentColor = const Color(0xFF1A73E8),
    this.maxWidthFactor = 0.88,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : Colors.black87;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1) Vertical accent block behind the card
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 26,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.98),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
          ),
        ),

        // 2) Decorative circle
        Positioned(
          left: 14,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),

        // 3) Card
        Container(
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accentLabel.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontFamily: "Poppins",
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DefaultTextStyle(
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ResponseMessageCard extends StatelessWidget {
  final Widget content;
  final String? label;
  final IconData? icon;
  final Color bgColor;
  final Color labelColor;
  final double maxWidthFactor;
  final VoidCallback? onCopy;
  final bool? isImage;
  final VoidCallback? onDownload;

  const ResponseMessageCard({
    Key? key,
    required this.content,
    this.label,
    this.icon,
    this.bgColor = Colors.white,
    this.labelColor = Colors.blueAccent,
    this.maxWidthFactor = 0.8,
    this.onCopy,
    this.isImage,
    this.onDownload,
  }) : super(key: key);

  bool _isImageWidget(Widget widget) {
    return widget is Image ||
        widget.toString().contains("Image") ||
        widget is SizedBox;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _isImageWidget(content);
    final isDark = context.isDark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkDivider : Colors.black12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * maxWidthFactor,
              minHeight: hasImage ? 500 : 0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: labelColor.withOpacity(isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 14, color: labelColor),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              label!,
                              style: TextStyle(
                                fontSize: 12,
                                color: labelColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // IMAGE → DOWNLOAD | TEXT → COPY
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: labelColor.withOpacity(isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Visibility(
                              visible: isImage == true,
                              child: GestureDetector(
                                onTap: onDownload,
                                child: Icon(
                                  Icons.download_rounded,
                                  size: 16,
                                  color: labelColor,
                                ),
                              ),
                            ),
                            Visibility(
                              visible: isImage == false,
                              child: GestureDetector(
                                onTap: onCopy,
                                child: Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// class MessageBubble extends StatelessWidget {
//   final UIChatMessage message;
//   final bool animate;
//
//   const MessageBubble({
//     super.key,
//     required this.message,
//     this.animate = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (message.isUser) {
//       return _buildUser();
//     }
//
//     switch (message.mode) {
//       case ChatMode.illustration:
//         return _buildIllustration();
//       case ChatMode.explainImage:
//         return _buildText('Image Explanation');
//       case ChatMode.storyTelling:
//         return _buildText('Story');
//       case ChatMode.video:
//         return _buildText('Video');
//       default:
//         return _buildText('Answer');
//     }
//   }
//
//   Widget _buildUser() {
//     return UserMessageCard(
//       content: SelectableText(message.userText ?? ''),
//     );
//   }
//
//   Widget _buildText(String label) {
//     return ResponseMessageCard(
//       label: label,
//       isImage: false,
//       content: MarkdownBody(
//         data: message.aiText ?? '',
//         selectable: true,
//       ),
//     );
//   }
//
//   Widget _buildIllustration() {
//     final images = message.aiImageBytes ?? [];
//
//     return ResponseMessageCard(
//       label: 'Illustration',
//       isImage: true,
//       content: SizedBox(
//         height: 250,
//         child: images.isNotEmpty
//             ? PageView(
//           children: images
//               .map((b) => Image.memory(b, fit: BoxFit.cover))
//               .toList(),
//         )
//             : const Center(child: CircularProgressIndicator()),
//       ),
//     );
//   }
// }
//
//
//
// class UIChatMessage {
//   final bool isUser;
//   final ChatMode mode;
//
//   // USER
//   final String? userText;
//   final String? userImage;
//
//   // AI
//   final String? aiText;
//   final List<String>? aiImageUrls;
//   final List<Uint8List>? aiImageBytes;
//
//   UIChatMessage({
//     required this.isUser,
//     required this.mode,
//     this.userText,
//     this.userImage,
//     this.aiText,
//     this.aiImageUrls,
//     this.aiImageBytes,
//   });
// }
