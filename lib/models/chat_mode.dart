import 'package:cloud_firestore/cloud_firestore.dart';

class FBChatModel {
  final String id;
  final String userId;
  final String mode;
  final DateTime createdAt;

  final UserInput userInput;
  final AIResponse? aiOutput;

  FBChatModel({
    required this.id,
    required this.userId,
    required this.mode,
    required this.createdAt,
    required this.userInput,
    this.aiOutput,
  });

  /// 🔥 FROM FIRESTORE
  factory FBChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FBChatModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      mode: data['mode'] as String? ?? 'default',
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      userInput: UserInput.fromMap(
        Map<String, dynamic>.from(data['userInput'] ?? {}),
      ),

      aiOutput: data['aiOutput'] != null
          ? AIResponse.fromMap(
        Map<String, dynamic>.from(data['aiOutput']),
      )
          : null,
    );
  }

  /// ✅ DO NOT REMOVE — TO FIRESTORE
  static Map<String, dynamic> toFireStore(FBChatModel chat,String id) {
    return {
      'id':id,
      'userId': chat.userId,
      'mode': chat.mode,
      'createdAt': Timestamp.fromDate(chat.createdAt),

      'userInput': chat.userInput.toMap(),

      'aiOutput': chat.aiOutput?.toMap(),
    };
  }

  factory FBChatModel.forMap(
      Map<String, dynamic> map, {
        required String id,
      }) {
    return FBChatModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      mode: map['mode'] as String? ?? 'default',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),

      userInput: UserInput.fromMap(
        Map<String, dynamic>.from(map['userInput'] ?? {}),
      ),

      aiOutput: map['aiOutput'] != null
          ? AIResponse.fromMap(
        Map<String, dynamic>.from(map['aiOutput']),
      )
          : null,
    );
  }



}

/* ================= USER INPUT ================= */

class UserInput {
  final String prompt;
  final String? imageUrl;

  UserInput({
    required this.prompt,
    this.imageUrl,
  });

  factory UserInput.fromMap(Map<String, dynamic> map) {
    return UserInput(
      prompt: map['prompt'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'imageUrl': imageUrl,
    };
  }
}

/* ================= AI RESPONSE ================= */

class AIResponse {
  final String? text;
  final List<String>? imageUrls;

  AIResponse({
    this.text,
    this.imageUrls,
  });

  factory AIResponse.fromMap(Map<String, dynamic> map) {
    return AIResponse(
      text: map['text'] as String?,
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrls': imageUrls,
    };
  }
}
