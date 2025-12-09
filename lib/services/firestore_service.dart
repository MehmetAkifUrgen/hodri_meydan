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
  Future<void> saveUser(User user, {String? usernameOverride}) async {
    try {
      final userDoc = await _usersRef.doc(user.uid).get();

      if (!userDoc.exists) {
        // Create new user
        final newUser = UserModel(
          id: user.uid,
          email: user.email ?? '',
          username:
              usernameOverride ??
              user.displayName ??
              'Misafir${Random().nextInt(90000) + 10000}',
          profileImageUrl: user.photoURL,
          coins: 100, // Starting coins
          xp: 0,
          level: 1,
          lives: 5,
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
        .asyncMap((snapshot) async {
          if (snapshot.exists && snapshot.data() != null) {
            UserModel user = UserModel.fromMap(
              uid,
              snapshot.data() as Map<String, dynamic>,
            );
            return await _checkLifeRegen(user);
          }
          return null;
        })
        .handleError((e) {
          debugPrint('Firestore Error (getUserStream): $e');
          return null;
        });
  }

  Future<UserModel> _checkLifeRegen(UserModel user) async {
    if (user.lives >= 5) return user;

    final now = DateTime.now();
    final lastRegen = user.lastLifeRegen ?? now;
    final difference = now.difference(lastRegen).inMinutes;
    const regenInterval = 15; // 15 minutes per life

    if (difference >= regenInterval) {
      final livesKeyValue = (difference / regenInterval).floor();
      final livesToAdd = min(5 - user.lives, livesKeyValue);

      if (livesToAdd > 0) {
        final newLives = user.lives + livesToAdd;
        // Update DB
        // If we added lives, we should update lastLifeRegen to "now - remainder".
        // But simply setting to 'now' is safer to prevent exploits/bugs, though slightly unfair if they waited 29 mins (gets 1 life + reset).
        // A better approach: `lastRegen.add(Duration(minutes: livesToAdd * regenInterval))`
        final newLastRegen = lastRegen.add(
          Duration(minutes: livesToAdd * regenInterval),
        );

        await _usersRef.doc(user.id).update({
          'lives': newLives,
          'lastLifeRegen': Timestamp.fromDate(newLastRegen),
        });

        return user.copyWith(lives: newLives, lastLifeRegen: newLastRegen);
      }
    }
    return user;
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
          debugPrint('Firestore Error (getGlobalLeaderboard): $e');
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

  // Update Lives (Deduct or Add)
  Future<void> updateLives(String uid, int change) async {
    try {
      if (change == 0) return;

      final userRef = _usersRef.doc(uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        int currentLives = data['lives'] ?? 5;

        // Calculate new lives
        int newLives = (currentLives + change).clamp(0, 5);

        // Logic for Regen Timestamp:
        // If dropping below 5 (and was 5), set Timestamp.now().
        // If we heal to 5, set null.

        DateTime? lastRegen = data['lastLifeRegen'] != null
            ? (data['lastLifeRegen'] as Timestamp).toDate()
            : null;

        if (currentLives == 5 && newLives < 5) {
          lastRegen = DateTime.now();
        } else if (newLives == 5) {
          lastRegen = null;
        }

        transaction.update(userRef, {
          'lives': newLives,
          'lastLifeRegen': lastRegen != null
              ? Timestamp.fromDate(lastRegen)
              : null,
        });
      });
    } catch (e) {
      debugPrint('Error updating user lives: $e');
    }
  }

  // Save FCM Token
  Future<void> saveFcmToken(String uid, String token) async {
    try {
      await _usersRef.doc(uid).update({
        'fcmToken': token,
        'tokenLastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  // Update User Profile (Email & Username)
  Future<void> updateUserProfile(
    String uid,
    String username,
    String email,
  ) async {
    try {
      await _usersRef.doc(uid).update({
        'username': username,
        'email': email,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating user profile: $e");
    }
  }

  // Update Profile Image
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    try {
      await _usersRef.doc(uid).update({
        'profileImageUrl': imageUrl,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating profile image: $e");
      throw Exception("Profil resmi güncellenemedi");
    }
  }
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
