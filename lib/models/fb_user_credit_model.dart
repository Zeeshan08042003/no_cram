import 'package:cloud_firestore/cloud_firestore.dart';

class FBUserCreditsModel {
  final String id;
  final String userId;

  final int totalCreditsEarned;
  final int remainingCredits;
  final int usedCredits;

  final bool freeCreditsGranted;

  final DateTime createdAt;
  final DateTime updatedAt;

  FBUserCreditsModel({
    required this.id,
    required this.userId,
    required this.totalCreditsEarned,
    required this.remainingCredits,
    required this.usedCredits,
    required this.freeCreditsGranted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 🔥 FROM FIRESTORE
  factory FBUserCreditsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FBUserCreditsModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',

      totalCreditsEarned: data['totalCreditsEarned'] as int? ?? 0,
      remainingCredits: data['remainingCredits'] as int? ?? 0,
      usedCredits: data['usedCredits'] as int? ?? 0,

      freeCreditsGranted: data['freeCreditsGranted'] as bool? ?? false,

      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
      (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// ✅ TO FIRESTORE
  static Map<String, dynamic> toFireStore(
      FBUserCreditsModel credits,
      String id,
      ) {
    return {
      'id': id,
      'userId': credits.userId,

      'totalCreditsEarned': credits.totalCreditsEarned,
      'remainingCredits': credits.remainingCredits,
      'usedCredits': credits.usedCredits,

      'freeCreditsGranted': credits.freeCreditsGranted,

      'createdAt': Timestamp.fromDate(credits.createdAt),
      'updatedAt': Timestamp.fromDate(credits.updatedAt),
    };
  }

  factory FBUserCreditsModel.fromMap(
      Map<String, dynamic> map, {
        required String id,
      }) {
    return FBUserCreditsModel(
      id: id,
      userId: map['userId'] as String? ?? '',

      totalCreditsEarned: map['totalCreditsEarned'] as int? ?? 0,
      remainingCredits: map['remainingCredits'] as int? ?? 0,
      usedCredits: map['usedCredits'] as int? ?? 0,

      freeCreditsGranted: map['freeCreditsGranted'] as bool? ?? false,

      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),

      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
