import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class FBConversationModel {
  final String id;
  final String userId;
  final String mode;
  final DateTime createdAt;
  final List<FBChatItem> chats;

  FBConversationModel({
    required this.id,
    required this.userId,
    required this.mode,
    required this.createdAt,
    required this.chats,
  });

  factory FBConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FBConversationModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      mode: data['mode'] ?? 'default',
      createdAt:
      (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      chats: (data['chats'] as List<dynamic>? ?? [])
          .map((e) => FBChatItem.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'user_id': userId,
      'mode': mode,
      'created_at': Timestamp.fromDate(createdAt),
      'chats': chats.map((e) => e.toMap()).toList(),
    };
  }
}


class FBChatItem {
  final String id;
  final DateTime createdAt;
  final String mode;
  final UserInput userInput;
  final AIResponse? aiOutput;
  
  /// True if this is a user message (no AI output yet)
  final bool isUserMessage;

  FBChatItem({
    required this.id,
    required this.createdAt,
    required this.mode,
    required this.userInput,
    this.aiOutput,
    required this.isUserMessage,
  });

  /// Factory for creating a user message
  factory FBChatItem.user({
    required String prompt,
    required String mode,
    List<String>? imageUrl,
    List<Uint8List>? imageBytesList,
  }) {
    return FBChatItem(
      id: '',
      createdAt: DateTime.now(),
      mode: mode,
      isUserMessage: true,
      userInput: UserInput(
        prompt: prompt,
        imageUrl: imageUrl,
        imageBytesList: imageBytesList,
      ),
      aiOutput: null,
    );
  }

  /// Factory for creating an AI response message
  factory FBChatItem.ai({
    required String mode,
    String? text,
    List<String>? imageUrls,
    List<Uint8List>? imageBytesList,
  }) {
    return FBChatItem(
      id: '',
      createdAt: DateTime.now(),
      mode: mode,
      isUserMessage: false,
      userInput: UserInput(prompt: ''),
      aiOutput: AIResponse(
        text: text,
        imageUrls: imageUrls,
        imageBytesList: imageBytesList,
      ),
    );
  }

  factory FBChatItem.fromMap(Map<String, dynamic> map) {
    final hasAiOutput = map['ai_output'] != null;
    return FBChatItem(
      id: map['id'] ?? '',
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      mode: map['mode'] ?? 'default',
      isUserMessage: !hasAiOutput,
      userInput: UserInput.fromMap(
        Map<String, dynamic>.from(map['user_input'] ?? {}),
      ),
      aiOutput: hasAiOutput
          ? AIResponse.fromMap(
              Map<String, dynamic>.from(map['ai_output']),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': Timestamp.fromDate(createdAt),
      'mode': mode,
      'user_input': userInput.toMap(),
      'ai_output': aiOutput?.toMap(),
    };
  }

  /// Get display text (user prompt or AI response text)
  String get displayText => isUserMessage ? userInput.prompt : (aiOutput?.text ?? '');

  /// Get image URLs for display
  List<String>? get displayImageUrls => isUserMessage ? userInput.imageUrl : aiOutput?.imageUrls;

  /// Get image bytes for display (in-memory, not persisted)
  List<Uint8List>? get displayImageBytes => isUserMessage ? userInput.imageBytesList : aiOutput?.imageBytesList;
}


class UserInput {
  final String prompt;
  /// Stores image URLs - can be a single URL or list of URLs
  /// Firestore stores as List<String> under 'imageUrl' key
  final List<String>? imageUrl;
  /// In-memory image bytes (for live chat before upload, not persisted)
  final List<Uint8List>? imageBytesList;

  UserInput({
    required this.prompt,
    this.imageUrl,
    this.imageBytesList,
  });

  factory UserInput.fromMap(Map<String, dynamic> map) {
    // Handle both legacy single string and new list format
    List<String>? urlList;
    final rawImageUrl = map['imageUrl'];

    if (rawImageUrl is String && rawImageUrl.isNotEmpty) {
      // Legacy: single string format
      urlList = [rawImageUrl];
    } else if (rawImageUrl is List) {
      // New: list format
      urlList = List<String>.from(rawImageUrl);
    }

    return UserInput(
      prompt: map['prompt'] ?? '',
      imageUrl: urlList,
      // imageBytesList is not persisted, so we don't read it from map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'imageUrl': imageUrl,
      // imageBytesList is not persisted
    };
  }

  /// Get first image URL (for backward compatibility)
  String? get firstImageUrl => imageUrl?.isNotEmpty == true ? imageUrl!.first : null;

  /// Check if has any images (URL or bytes)
  bool get hasImages => (imageUrl?.isNotEmpty == true) || (imageBytesList?.isNotEmpty == true);
}


class AIResponse {
  final String? text;
  final List<String>? imageUrls;
  /// In-memory image bytes (for live chat before upload, not persisted)
  final List<Uint8List>? imageBytesList;

  AIResponse({
    this.text,
    this.imageUrls,
    this.imageBytesList,
  });

  factory AIResponse.fromMap(Map<String, dynamic> map) {
    return AIResponse(
      text: map['text'],
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      // imageBytesList is not persisted
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrls': imageUrls,
      // imageBytesList is not persisted
    };
  }
}


/// Single chat model for storing one user question + AI response pair
/// Used by all AI services and history functionality
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

  /// 🔥 FROM FIRESTORE (DocumentSnapshot)
  factory FBChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FBChatModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      mode: data['mode'] as String? ?? 'default',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  /// ✅ TO FIRESTORE
  static Map<String, dynamic> toFireStore(FBChatModel chat, String id) {
    return {
      'id': id,
      'userId': chat.userId,
      'mode': chat.mode,
      'createdAt': Timestamp.fromDate(chat.createdAt),
      'userInput': chat.userInput.toMap(),
      'aiOutput': chat.aiOutput?.toMap(),
    };
  }

  /// Factory from Map (for stream parsing)
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







// class FBChatModel {
//   final String id;
//   final String userId;
//   final String mode;
//   final DateTime createdAt;
//
//   final UserInput userInput;
//   final AIResponse? aiOutput;
//
//   FBChatModel({
//     required this.id,
//     required this.userId,
//     required this.mode,
//     required this.createdAt,
//     required this.userInput,
//     this.aiOutput,
//   });
//
//   /// 🔥 FROM FIRESTORE
//   factory FBChatModel.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//
//     return FBChatModel(
//       id: doc.id,
//       userId: data['userId'] as String? ?? '',
//       mode: data['mode'] as String? ?? 'default',
//       createdAt:
//       (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//
//       userInput: UserInput.fromMap(
//         Map<String, dynamic>.from(data['userInput'] ?? {}),
//       ),
//
//       aiOutput: data['aiOutput'] != null
//           ? AIResponse.fromMap(
//         Map<String, dynamic>.from(data['aiOutput']),
//       )
//           : null,
//     );
//   }
//
//   /// ✅ DO NOT REMOVE — TO FIRESTORE
//   static Map<String, dynamic> toFireStore(FBChatModel chat,String id) {
//     return {
//       'id':id,
//       'userId': chat.userId,
//       'mode': chat.mode,
//       'createdAt': Timestamp.fromDate(chat.createdAt),
//
//       'userInput': chat.userInput.toMap(),
//
//       'aiOutput': chat.aiOutput?.toMap(),
//     };
//   }
//
//   factory FBChatModel.forMap(
//       Map<String, dynamic> map, {
//         required String id,
//       }) {
//     return FBChatModel(
//       id: id,
//       userId: map['userId'] as String? ?? '',
//       mode: map['mode'] as String? ?? 'default',
//       createdAt: map['createdAt'] is Timestamp
//           ? (map['createdAt'] as Timestamp).toDate()
//           : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
//           DateTime.now(),
//
//       userInput: UserInput.fromMap(
//         Map<String, dynamic>.from(map['userInput'] ?? {}),
//       ),
//
//       aiOutput: map['aiOutput'] != null
//           ? AIResponse.fromMap(
//         Map<String, dynamic>.from(map['aiOutput']),
//       )
//           : null,
//     );
//   }
//
//
//
// }
//
// /* ================= USER INPUT ================= */
//
// class UserInput {
//   final String prompt;
//   /// Stores image URLs - can be a single URL or list of URLs
//   /// Firestore stores as List<String> under 'imageUrl' key
//   final List<String>? imageUrl;
//
//   UserInput({
//     required this.prompt,
//     this.imageUrl,
//   });
//
//   factory UserInput.fromMap(Map<String, dynamic> map) {
//     // Handle both legacy single string and new list format
//     List<String>? urlList;
//     final rawImageUrl = map['imageUrl'];
//
//     if (rawImageUrl is String && rawImageUrl.isNotEmpty) {
//       // Legacy: single string format
//       urlList = [rawImageUrl];
//     } else if (rawImageUrl is List) {
//       // New: list format
//       urlList = List<String>.from(rawImageUrl);
//     }
//
//     return UserInput(
//       prompt: map['prompt'] as String? ?? '',
//       imageUrl: urlList,
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'prompt': prompt,
//       'imageUrl': imageUrl, // Store as list
//     };
//   }
//
//   /// Get first image URL (for backward compatibility)
//   String? get firstImageUrl => imageUrl?.isNotEmpty == true ? imageUrl!.first : null;
//
//   /// Check if has any images
//   bool get hasImages => imageUrl?.isNotEmpty == true;
// }
//
// /* ================= AI RESPONSE ================= */
//
// class AIResponse {
//   final String? text;
//   final List<String>? imageUrls;
//
//   AIResponse({
//     this.text,
//     this.imageUrls,
//   });
//
//   factory AIResponse.fromMap(Map<String, dynamic> map) {
//     return AIResponse(
//       text: map['text'] as String?,
//       imageUrls: map['imageUrls'] != null
//           ? List<String>.from(map['imageUrls'])
//           : null,
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'text': text,
//       'imageUrls': imageUrls,
//     };
//   }
// }
