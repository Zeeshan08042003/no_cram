import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uid/uid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_mode.dart';
import '../../models/fb_user_credit_model.dart';
import '../../models/user_model.dart';

class FirestoreService {
  FirebaseFirestore db = FirebaseFirestore.instance;

  createChat(FBChatModel chat) async {
    String id = UId.getId();
    print(id);
    await db
        .collection('chats')
        .doc(id)
        .set(
          FBChatModel.toFireStore(chat,id),
        )
        .then((value) {
      Get.snackbar('Success', 'Chat sent successfully');
    });
  }



  Stream<List<FBChatModel>> getChatsByUser(String userId) {
    return db
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var data =  snapshot.docs
          .map((doc) => FBChatModel.forMap(doc.data(), id: doc.id))
          .toList();

      print("object function is started ${data.length}");

      return data;
    });
  }


  // ==================== CONVERSATION-BASED METHODS ====================

  /// Create a new conversation with the first chat item
  Future<String> createConversation({
    required String userId,
    required String mode,
    required FBChatItem chatItem,
  }) async {
    String conversationId = UId.getId();
    String chatId = UId.getId();
    
    // Assign ID to the chat item
    final chatWithId = FBChatItem(
      id: chatId,
      createdAt: chatItem.createdAt,
      mode: chatItem.mode,
      userInput: chatItem.userInput,
      aiOutput: chatItem.aiOutput,
      isUserMessage: chatItem.isUserMessage,
    );

    final conversation = FBConversationModel(
      id: conversationId,
      userId: userId,
      latestMode: mode,
      createdAt: DateTime.now(),
      chats: [chatWithId],
    );

    await db
        .collection('conversations')
        .doc(conversationId)
        .set(conversation.toFirestore());

    print('✅ Conversation created with ID: $conversationId');
    return conversationId;
  }

  /// Add a new chat to an existing conversation (for follow-ups)
  /// Note: latestMode is NOT updated here - it stays as the initial mode
  Future<void> addChatToConversation({
    required String conversationId,
    required FBChatItem chatItem,
  }) async {
    String chatId = UId.getId();
    
    // Assign ID to the chat item
    final chatWithId = FBChatItem(
      id: chatId,
      createdAt: chatItem.createdAt,
      mode: chatItem.mode,
      userInput: chatItem.userInput,
      aiOutput: chatItem.aiOutput,
      isUserMessage: chatItem.isUserMessage,
    );

    await db.collection('conversations').doc(conversationId).update({
      // latest_mode is NOT updated - it stays as the initial mode
      'chats': FieldValue.arrayUnion([chatWithId.toMap()]),
    });

    print('✅ Chat added to conversation: $conversationId');
  }

  /// Get all conversations for a user (ordered by created_at desc)
  Stream<List<FBConversationModel>> getConversationsByUser(String userId) {
    return db
        .collection('conversations')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      var data = snapshot.docs
          .map((doc) => FBConversationModel.fromMap(doc.data(), id: doc.id))
          .toList();

      print("Conversations fetched: ${data.length}");
      return data;
    });
  }

  /// Get a single conversation by ID
  Future<FBConversationModel?> getConversationById(String conversationId) async {
    final doc = await db.collection('conversations').doc(conversationId).get();
    
    if (!doc.exists) return null;
    
    return FBConversationModel.fromMap(doc.data()!, id: doc.id);
  }

  /// Update the latest mode of a conversation
  Future<void> updateConversationLatestMode({
    required String conversationId,
    required String latestMode,
  }) async {
    await db.collection('conversations').doc(conversationId).update({
      'latest_mode': latestMode,
    });
    print('✅ Conversation latest_mode updated to: $latestMode');
  }


  Future<void> registerAndStoreUser(
      String email,
      String password,
      String firstName,
      ) async {
    try {
      // 🔐 Create user in Firebase Auth
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        throw Exception('User creation failed');
      }

      // 🧩 Create UserModel
      final userModel = UserModel(
        userId: user.uid,
        email: user.email ?? email,
        firstName: firstName,
        createdAt: DateTime.now(),
      );

      // ☁️ Store in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(UserModel.toFireStore(userModel,user.uid));
      await createCreditsIfNotExists(user.uid);
      SharedPreferences pref  = await SharedPreferences.getInstance();
      pref.setString('userId', user.uid);
      print('✅ User registered and stored successfully');
    } catch (e) {
      print('❌ Error during registration: $e');
      rethrow;
    }
  }

  /// Store Google Sign-In user in Firestore
  /// Creates user profile only if it doesn't exist
  Future<void> storeGoogleUser(User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // New user - create profile
        final userModel = UserModel(
          userId: user.uid,
          email: user.email ?? '',
          firstName: user.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
        
        await docRef.set(UserModel.toFireStore(userModel, user.uid));
        print('✅ New Google user stored in Firestore');
      } else {
        print('ℹ️ Google user already exists in Firestore');
      }
      
      // Ensure credits exist for this user
      await createCreditsIfNotExists(user.uid);
      
    } catch (e) {
      print('❌ Error storing Google user: $e');
      rethrow;
    }
  }

  Future<UserModel> loginUser(
      String email,
      String password,
      ) async {
    try {
      // 🔐 Sign in with Firebase Auth
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        throw Exception('Login failed');
      }

      // ☁️ Fetch user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();


      SharedPreferences pref  = await SharedPreferences.getInstance();
      pref.setString('userId', user.uid);

      // 💰 Ensure credits document exists for existing users
      await createCreditsIfNotExists(user.uid);

      if (!doc.exists) {
        throw Exception('User data not found in Firestore');
      }

      // 🧩 Convert to UserModel
      final userModel = UserModel.forMap(
        doc.data()!,
        id: user.uid,
      );

      print('✅ User logged in successfully');
      return userModel;
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }



  getUserDetails(String userId) {
    return db
        .collection('users')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      var data =  snapshot.docs
          .map((doc) => UserModel.forMap(doc.data(), id: doc.id))
          .toList();

      print("object function is started ${data.length}");

      return data.first;
    });
  }


  Future<void> createCreditsIfNotExists(String userId) async {
    final query = await db
        .collection('user_credits')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();


    if (query.docs.isEmpty) {

      var id = UId.getId();
      final credits = FBUserCreditsModel(
        id: id,
        userId: userId,
        totalCreditsEarned: 10,
        usedCredits: 0,
        remainingCredits: 10,
        freeCreditsGranted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createUserCredits(credits);
    }
  }

  createUserCredits(FBUserCreditsModel credits) async {
    await db
        .collection('user_credits')
        .doc(credits.id) // userId
        .set(
      FBUserCreditsModel.toFireStore(credits, credits.id),
    )
        .then((value) {
      print('User credits created successfully');
    });
  }



  Future<void> addCredits(String userId, int credits) async {
    final ref = FirebaseFirestore.instance
        .collection("user_credits")
        .doc(userId);

    await ref.update({
      "totalCreditsEarned": FieldValue.increment(credits),
      "remainingCredits": FieldValue.increment(credits),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }


  Future<bool> consumeCredit(String userId) async {
    final ref = FirebaseFirestore.instance
        .collection("user_credits")
        .doc(userId);

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final remaining = snapshot["remainingCredits"];

      if (remaining <= 0) return false;

      tx.update(ref, {
        "remainingCredits": remaining - 1,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      return true;
    });
  }




}

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(File file, String userId) async {
    try {

      print("file 1");
      final ref = _storage
          .ref()
          .child('image_explanation')
          .child(userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      print("file 2");

      // 🔴 THIS MUST BE AWAITED
      final uploadTask = await ref.putFile(file);


      print("file 3");

      // 🔴 WAIT FOR COMPLETION
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print("file 4");
      return downloadUrl;
    } catch (e) {
      print('❌ Firebase Storage upload failed: $e');
      rethrow;
    }
  }


  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String userId,
    String ext = 'png',
  }) async {
    final ref = _storage
        .ref()
        .child('illustrations')
        .child(userId)
        .child('${DateTime.now().millisecondsSinceEpoch}.$ext');

    final metadata = SettableMetadata(contentType: 'image/$ext');

    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  /// Upload multiple images and return list of download URLs
  Future<List<String>> uploadMultipleImages({
    required List<Uint8List> bytesList,
    required String userId,
    String folder = 'image_explanation',
    String ext = 'jpg',
  }) async {
    final List<String> downloadUrls = [];
    
    for (int i = 0; i < bytesList.length; i++) {
      try {
        final ref = _storage
            .ref()
            .child(folder)
            .child(userId)
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.$ext');

        final metadata = SettableMetadata(contentType: 'image/$ext');
        final task = await ref.putData(bytesList[i], metadata);
        final url = await task.ref.getDownloadURL();
        downloadUrls.add(url);
        print('[STORAGE] Uploaded image ${i + 1}/${bytesList.length}');
      } catch (e) {
        print('❌ Error uploading image $i: $e');
      }
    }
    
    return downloadUrls;
  }

}
