import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _usersRef => _firestore.collection('users');

  // Create or Update User
  Future<void> saveUser(User user) async {
    try {
      final userDoc = await _usersRef.doc(user.uid).get();

      if (!userDoc.exists) {
        // Create new user
        final newUser = UserModel(
          id: user.uid,
          email: user.email ?? '',
          username:
              user.displayName ?? 'Misafir${Random().nextInt(90000) + 10000}',
          profileImageUrl: user.photoURL,
          coins: 100, // Starting coins
          xp: 0,
          level: 1,
        );
        await _usersRef.doc(user.uid).set(newUser.toMap());
      } else {
        // Update last active
        await _usersRef.doc(user.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Firestore Error (saveUser): $e');
      rethrow;
    }
  }

  // Get User Stream
  Stream<UserModel?> getUserStream(String uid) {
    return _usersRef
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return UserModel.fromMap(
              uid,
              snapshot.data() as Map<String, dynamic>,
            );
          }
          return null;
        })
        .handleError((e) {
          debugPrint('Firestore Error (getUserStream): $e');
          return null;
        });
  }

  // Update User Stats (XP, Level, Coins, Score)
  Future<void> updateUserStats({
    required String uid,
    required int earnedScore,
    required bool isWin,
  }) async {
    try {
      final userRef = _usersRef.doc(uid);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;

        // Current values
        int currentXp = data['xp'] ?? 0;
        // int currentLevel = data['level'] ?? 1; // Unused
        int currentCoins = data['coins'] ?? 0;
        int gamesPlayed = data['gamesPlayed'] ?? 0;
        int wins = data['wins'] ?? 0;
        int totalScore = data['totalScore'] ?? 0;

        // Calculate new values
        // Strategy: XP = Score. Level up every 1000 XP.
        // Win bonus = 100 XP + 20 Coins
        // Participation = Score as XP + 5 Coins

        int earnedXp = earnedScore;
        int earnedCoins = 5;

        if (isWin) {
          earnedXp += 100; // Bonus for winning
          earnedCoins += 20;
          wins += 1;
        }

        currentXp += earnedXp;
        currentCoins += earnedCoins;
        totalScore += earnedScore;
        gamesPlayed += 1;

        // Level Calculation (Example: 1000 XP per level)
        // Level 1: 0-999, Level 2: 1000-1999
        int newLevel = (currentXp / 1000).floor() + 1;

        transaction.update(userRef, {
          'xp': currentXp,
          'level': newLevel,
          'coins': currentCoins,
          'gamesPlayed': gamesPlayed,
          'wins': wins,
          'totalScore': totalScore,
          'lastActive': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Firestore Error (updateUserStats): $e');
    }
  }

  // Get Leaderboard (Top 20 Global)
  Stream<List<UserModel>> getGlobalLeaderboard() {
    return _usersRef
        .orderBy('totalScore', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => UserModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
        })
        .handleError((e) {
          print('Firestore Error (getGlobalLeaderboard): $e');
          return const <UserModel>[]; // Return empty list on error
        });
  }

  // Submit Feedback
  Future<void> submitFeedback(String uid, String message) async {
    try {
      await _firestore.collection('feedback').add({
        'userId': uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter',
      });
      debugPrint("Feedback submitted successfully.");
    } catch (e) {
      debugPrint("Error submitting feedback: $e");
      throw Exception("Geri bildirim gönderilemedi");
    }
  }

  // Delete User Data
  Future<void> deleteUserData(String uid) async {
    try {
      await _usersRef.doc(uid).delete();
      debugPrint("User data deleted from Firestore.");
    } catch (e) {
      debugPrint("Error deleting user data: $e");
      throw Exception("Kullanıcı verileri silinemedi");
    }
  }
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
