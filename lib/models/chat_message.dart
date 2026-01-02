import '../controllers/chat_controller.dart';
import 'chat_mode.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final ChatMode mode;
  final List<String>? imageUrls;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.mode,
    required this.createdAt,
    this.imageUrls,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'mode': mode.key,
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      mode: ChatMode.values.firstWhere(
            (m) => m.key == json['mode'],
        orElse: () => ChatMode.defaultMode,
      ),
      imageUrls: (json['imageUrls'] as List?)?.cast<String>(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
