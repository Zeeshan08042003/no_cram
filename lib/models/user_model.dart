import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? userId;
  String? email;
  String? firstName;
  DateTime? createdAt;

  UserModel({this.userId, this.email, this.firstName, this.createdAt});

  static Map<String, dynamic> toFireStore(UserModel user,String id) {
    return {
      'id':id,
      "user_id": user.userId,
      "email": user.email,
      "firstName": user.firstName,
      "createdAt": user.createdAt
    };
  }


  factory UserModel.forMap(
      Map<String, dynamic> map, {
        required String id,
      }) {
    return UserModel(
      userId: map['user_id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }


}
