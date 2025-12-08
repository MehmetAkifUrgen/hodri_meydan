import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? profileImageUrl;
  final int coins;
  final int xp;
  final int level;
  final int gamesPlayed;
  final int wins;
  final int totalScore;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.coins = 0,
    this.xp = 0,
    this.level = 1,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.totalScore = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'coins': coins,
      'xp': xp,
      'level': level,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'totalScore': totalScore,
      'lastActive': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      username: map['username'] ?? 'Anonymous',
      profileImageUrl: map['profileImageUrl'],
      coins: map['coins'] ?? 0,
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      gamesPlayed: map['gamesPlayed'] ?? 0,
      wins: map['wins'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
    );
  }

  UserModel copyWith({
    String? username,
    String? profileImageUrl,
    int? coins,
    int? xp,
    int? level,
    int? gamesPlayed,
    int? wins,
    int? totalScore,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      totalScore: totalScore ?? this.totalScore,
    );
  }
}
