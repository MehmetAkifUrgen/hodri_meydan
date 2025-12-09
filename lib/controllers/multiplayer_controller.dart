import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/ai_judge_service.dart';
import '../data/constants/name_city_constants.dart';

// Simple model for a multiplayer room
class GameRoom {
  final String id;
  final String status; // 'waiting', 'playing', 'finished'
  final List<String> players;
  final int createdAt;
  final String hostId;
  final List<String> readyPlayers;
  final String? selectedCategory;
  final String gameType; // 'quiz' or 'nameCity'
  final int gameDuration; // 60, 90, 120

  GameRoom({
    required this.id,
    required this.status,
    required this.players,
    required this.createdAt,
    required this.hostId,
    this.readyPlayers = const [],
    this.selectedCategory,
    this.gameType = 'quiz',
    this.gameDuration = 60,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'players': players,
      'createdAt': createdAt,
      'hostId': hostId,
      'readyPlayers': readyPlayers,
      'selectedCategory': selectedCategory,
      'gameType': gameType,
      'gameDuration': gameDuration,
    };
  }
}

// State
class MultiplayerState {
  final bool isLoading;
  final String? currentRoomId;
  final String? error;
  final String? statusMessage; // New field for positive feedback
  final List<String> categories;

  MultiplayerState({
    this.isLoading = false,
    this.currentRoomId,
    this.error,
    this.statusMessage,
    this.categories = const [],
  });

  MultiplayerState copyWith({
    bool? isLoading,
    String? currentRoomId,
    bool clearCurrentRoomId = false,
    String? error,
    String? statusMessage,
    List<String>? categories,
  }) {
    return MultiplayerState(
      isLoading: isLoading ?? this.isLoading,
      currentRoomId: clearCurrentRoomId
          ? null
          : (currentRoomId ?? this.currentRoomId),
      error: error, // Can accept null to clear
      statusMessage: statusMessage, // Can accept null to clear
      categories: categories ?? this.categories,
    );
  }
}

// Controller
class MultiplayerController extends StateNotifier<MultiplayerState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();
  final String _tempGuestId = const Uuid().v4(); // Fallback for guests

  MultiplayerController() : super(MultiplayerState()) {
    _loadCategories();
  }

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? _tempGuestId;

  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Try to get from Firestore for latest profile, fallback to Auth
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          return {
            'username': data['username'] ?? user.displayName ?? 'Misafir',
            'avatar': data['profileImageUrl'] ?? user.photoURL,
          };
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
      return {
        'username': user.displayName ?? 'Misafir',
        'avatar': user.photoURL,
      };
    }
    return {'username': 'Misafir', 'avatar': null};
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.fetchCategories();
      state = state.copyWith(categories: ['Genel', ...categories]);
    } catch (e) {
      debugPrint('Error loading categories: $e');
      // Fallback
      state = state.copyWith(
        categories: ['Genel', 'Sinema', 'Tarih', 'Coğrafya', 'Spor', 'Bilim'],
      );
    }
  }

  Future<void> createRoom() async {
    try {
      state = state.copyWith(isLoading: true);

      // Generate 6 digit room code
      String roomCode = (100000 + Random().nextInt(900000)).toString();

      final userData = await _getUserData();

      final room = GameRoom(
        id: roomCode,
        status: 'waiting',
        players: [userId],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        hostId: userId,
        readyPlayers: [userId],
        gameType: 'quiz', // Default
        gameDuration: 60, // Default
      );

      final roomMap = room.toMap();
      roomMap['playersData'] = {userId: userData};

      await _firestore.collection('rooms').doc(roomCode).set(roomMap);

      state = state.copyWith(isLoading: false, currentRoomId: roomCode);
    } catch (e) {
      debugPrint("Firestore Error (createRoom): $e");
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleReady(String roomId) async {
    try {
      final docRef = _firestore.collection('rooms').doc(roomId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      List<String> readyPlayers = List<String>.from(data['readyPlayers'] ?? []);

      if (readyPlayers.contains(userId)) {
        readyPlayers.remove(userId);
      } else {
        readyPlayers.add(userId);
      }

      await docRef.update({'readyPlayers': readyPlayers});
    } catch (e) {
      debugPrint("Firestore Error (toggleReady): $e");
    }
  }

  Future<void> setGameType(String roomId, String type) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'gameType': type,
      });
    } catch (e) {
      debugPrint("Firestore Error (setGameType): $e");
    }
  }

  Future<void> setCategory(String roomId, String category) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'selectedCategory': category,
      });
    } catch (e) {
      debugPrint("Firestore Error (setCategory): $e");
    }
  }

  Future<void> setGameDuration(String roomId, int duration) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'gameDuration': duration,
      });
    } catch (e) {
      debugPrint("Firestore Error (setGameDuration): $e");
    }
  }

  Future<void> startMultiplayerGame(String roomId) async {
    try {
      debugPrint('DEBUG: Attempting to start game for room: $roomId');
      // 1. Verify everyone is ready
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) {
        debugPrint('DEBUG: Room does not exist!');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final players = List<String>.from(data['players'] ?? []);
      final readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
      final selectedCategory = data['selectedCategory'] as String?;
      final hostId = data['hostId'] as String?;
      final gameType = data['gameType'] as String? ?? 'quiz';
      final gameDuration = data['gameDuration'] as int? ?? 60;

      // Validate Host
      if (hostId != userId) {
        debugPrint('Error: Only host can start game');
        return;
      }

      if (readyPlayers.length != players.length) {
        state = MultiplayerState(
          isLoading: false,
          error: "Tüm oyuncular hazır olmalı!",
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (state.error == "Tüm oyuncular hazır olmalı!") {
            state = state.copyWith(error: null); // Fix: don't reset room ID
          }
        });
        return;
      }

      if (gameType == 'nameCity') {
        // Name City Logic
        debugPrint('DEBUG: Starting Name City Game...');

        // Generate 5 random letters
        const alphabet = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ";
        final random = Random();
        final List<String> letters = [];
        for (int i = 0; i < 5; i++) {
          letters.add(alphabet[random.nextInt(alphabet.length)]);
        }

        // Select 5 random categories for the first round
        final allCategories = List<String>.from(NameCityConstants.categories);
        allCategories.shuffle();
        final selectedCategories = allCategories.take(5).toList();

        await _firestore.collection('rooms').doc(roomId).update({
          'status': 'playing_nameCity',
          'letters': letters,
          'currentRound': 1,
          'endTime': DateTime.now()
              .add(Duration(seconds: gameDuration))
              .millisecondsSinceEpoch,
          'currentCategories': selectedCategories, // Store dynamic categories
        });
      } else {
        // Quiz Logic
        final apiService = ApiService();
        debugPrint('DEBUG: Fetching questions from API...');
        // Fetch 10 questions for the room
        final questions = await apiService.fetchQuestions(
          limit: 10,
          category: selectedCategory == 'Rastgele' ? null : selectedCategory,
        );

        // Convert to list of Maps to store in Firestore
        final questionsData = questions
            .map(
              (q) => {
                'question': q.question,
                'options': q.options,
                'correct_answer': q.correctAnswerIndex,
                'category': q.category,
                'image_url': q.imageUrl,
              },
            )
            .toList();

        debugPrint('DEBUG: Updating room status to playing...');
        await _firestore.collection('rooms').doc(roomId).update({
          'status': 'playing',
          'questions': questionsData,
          'currentQuestionIndex': 0,
          'startTime': DateTime.now().millisecondsSinceEpoch,
        });
      }

      debugPrint('DEBUG: Game started successfully!');
    } catch (e) {
      debugPrint("Firestore Error (startMultiplayerGame): $e");
      state = MultiplayerState(
        isLoading: false,
        error: "Oyun başlatılamadı: $e",
      );
    }
  }

  Future<void> joinRoom(String roomCode) async {
    try {
      state = MultiplayerState(isLoading: true);

      DocumentSnapshot doc = await _firestore
          .collection('rooms')
          .doc(roomCode)
          .get();

      if (!doc.exists) {
        state = MultiplayerState(isLoading: false, error: "Oda bulunamadı");
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final List<String> players = List<String>.from(data['players'] ?? []);

      if (players.length >= 8) {
        state = state.copyWith(
          isLoading: false,
          error: "Oda dolu (Max 8 kişi)",
        );
        return;
      }

      if (players.contains(userId)) {
        // Already joined, just enter
        state = state.copyWith(isLoading: false, currentRoomId: roomCode);
        return;
      }

      final userData = await _getUserData();

      await _firestore.collection('rooms').doc(roomCode).update({
        'players': FieldValue.arrayUnion([userId]),
        'playersData.$userId': userData,
      });

      state = state.copyWith(isLoading: false, currentRoomId: roomCode);
    } catch (e) {
      debugPrint("Firestore Error (joinRoom): $e");
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Stream to listen to room changes
  Stream<DocumentSnapshot> roomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  // Get available rooms stream
  Stream<List<Map<String, dynamic>>> get availableRoomsStream {
    // 1 Hour ago
    final oneHourAgo = DateTime.now()
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;

    return _firestore
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                // Filter out stale rooms (older than 1 hour)
                final data = doc.data();
                final createdAt = data['createdAt'] as int? ?? 0;
                return createdAt > oneHourAgo;
              })
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .toList();
        })
        .handleError((e) {
          debugPrint('Firestore Error (availableRoomsStream): $e');
          return const <Map<String, dynamic>>[];
        });
  }

  Future<void> quickMatch() async {
    try {
      state = state.copyWith(isLoading: true);

      // Find a room with status 'waiting'
      final querySnapshot = await _firestore
          .collection('rooms')
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      String? targetRoomId;
      debugPrint(
        "Quick Match: Found ${querySnapshot.docs.length} waiting rooms",
      );

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final players = List<String>.from(data['players'] ?? []);
        // Also check creation time for quick match
        final createdAt = data['createdAt'] as int? ?? 0;
        final oneHourAgo = DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch;

        if (players.length < 8 && createdAt > oneHourAgo) {
          targetRoomId = doc.id;
          break;
        }
      }

      if (targetRoomId != null) {
        await joinRoom(targetRoomId);
        state = state.copyWith(
          statusMessage: "Hızlı Eşleşme Başarılı! Odaya katıldın.",
        );
      } else {
        // No room found, create one
        await createRoom();
        state = state.copyWith(
          statusMessage:
              "Uygun açık oda bulunamadı. Senin için yeni bir oda oluşturuldu.",
        );
      }
    } catch (e) {
      debugPrint("Firestore Error (quickMatch): $e");
      String errorMessage = e.toString();
      if (errorMessage.contains('failed-precondition')) {
        errorMessage =
            "Sistem yapılandırılıyor. Lütfen 1 dakika sonra tekrar deneyin.";
      } else if (errorMessage.contains('requires an index')) {
        errorMessage = "Sunucu dizini oluşturuluyor. Lütfen biraz bekleyin.";
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> submitAnswer(
    String roomId,
    int questionIndex,
    int answerIndex,
    int timeRemaining,
  ) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);

      // 1. Get current room data to validate answer
      final doc = await roomRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final questions = data['questions'] as List<dynamic>;
      final currentQuestionIdx = data['currentQuestionIndex'] as int;

      // Prevent late answers
      if (questionIndex != currentQuestionIdx) return;

      final questionData = questions[questionIndex] as Map<String, dynamic>;
      final correctAnswer = questionData['correct_answer'] as int;

      // 2. Calculate Score
      int points = 0;
      if (answerIndex == correctAnswer) {
        // Base points + Time bonus
        points = 10 + (timeRemaining ~/ 2);
      }

      // 3. Update Player Score in Firestore
      // Using a 'scores' map: { 'userId': score }
      await roomRef.update({
        'scores.$userId': FieldValue.increment(points),
        'answers.$userId': {
          'questionIndex': questionIndex,
          'answer': answerIndex,
          'correct': answerIndex == correctAnswer,
        },
      });

      // 4. Check if everyone answered (Auto-Advance)
      // We need to fetch the updated doc to check total answers count
      final updatedDoc = await roomRef.get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      final updatedAnswers =
          updatedData['answers'] as Map<String, dynamic>? ?? {};
      final players = List<String>.from(updatedData['players'] ?? []);
      final hostId = updatedData['hostId'] as String?;

      if (updatedAnswers.length >= players.length) {
        // Everyone answered
        if (hostId == userId) {
          // Only Host triggers next question
          Future.delayed(const Duration(seconds: 2), () {
            nextQuestion(roomId);
          });
        }
      }
    } catch (e) {
      debugPrint("Firestore Error (submitAnswer): $e");
    }
  }

  Future<void> leaveRoom() async {
    final roomId = state.currentRoomId;
    if (roomId == null) return;

    try {
      final docRef = _firestore.collection('rooms').doc(roomId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Proceed to clear local state
      } else {
        final data = doc.data() as Map<String, dynamic>;
        final hostId = data['hostId'] as String?;
        final players = List<String>.from(data['players'] ?? []);

        if (hostId == userId) {
          // Host leaving -> Delete Room
          debugPrint("DEBUG: Host leaving, deleting room $roomId");
          await docRef.delete();
        } else {
          // Guest leaving -> Remove from lists
          debugPrint("DEBUG: Guest leaving room $roomId");
          await docRef.update({
            'players': FieldValue.arrayRemove([userId]),
            'readyPlayers': FieldValue.arrayRemove([userId]),
          });

          // If room becomes empty (shouldn't happen if host logic works, but safe fallback)
          if (players.length <= 1) {
            await docRef.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Firestore Error (leaveRoom): $e");
      // Fallthrough to clear state
    } finally {
      // ALWAYS clear local state to unblock UI
      state = state.copyWith(clearCurrentRoomId: true);
    }
  }

  void onRoomClosed() {
    state = state.copyWith(
      clearCurrentRoomId: true,
      statusMessage: "Oda kapatıldı (Host ayrıldı).",
    );
  }

  Future<void> nextQuestion(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'currentQuestionIndex': FieldValue.increment(1),
        'answers': {}, // Reset answers for next round
        'startTime': DateTime.now().millisecondsSinceEpoch, // Reset timer
      });
    } catch (e) {
      debugPrint("Firestore Error (nextQuestion): $e");
    }
  }

  Future<void> finalizeGame(String roomId, int myScore, bool isWin) async {
    try {
      debugPrint(
        'DEBUG: Finalizing game for room $roomId. Score: $myScore, Win: $isWin',
      );

      final firestoreService = FirestoreService();

      await firestoreService.updateUserStats(
        uid: userId,
        earnedScore: myScore,
        isWin: isWin,
      );

      debugPrint('DEBUG: User stats updated successfully.');
    } catch (e) {
      debugPrint("Firestore Error (finalizeGame): $e");
    }
  }
  // --- Name City Logic ---

  bool isHost(String roomId) {
    // We can't check easily without room data, so we rely on View passing hostId
    // or check local cache if we had one.
    // But for now let's just use the isHostWithId helper or rely on caller.
    return false;
  }

  bool isHostWithId(String? hostId) {
    return userId == hostId;
  }

  Future<void> submitNameCityAnswers(
    String roomId,
    Map<String, String> answers,
  ) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'roundAnswers.$userId': answers,
      });
      debugPrint('DEBUG: Answers submitted for $userId');
    } catch (e) {
      debugPrint("Firestore Error (submitNameCityAnswers): $e");
    }
  }

  Future<void> endNameCityRound(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final hostId = data['hostId'] as String?;
      if (hostId != userId) return;

      debugPrint('DEBUG: Host ending round and calling AI Judge...');

      final currentLetter =
          (data['letters'] as List)[(data['currentRound'] as int) - 1]
              as String;
      final currentCategories = List<String>.from(
        data['currentCategories'] ?? [],
      );
      final gameDuration = data['gameDuration'] as int? ?? 60;

      final roundAnswersRaw =
          data['roundAnswers'] as Map<String, dynamic>? ?? {};
      final Map<String, Map<String, String>> roundAnswers = {};

      roundAnswersRaw.forEach((key, value) {
        if (value is Map) {
          roundAnswers[key] = Map<String, String>.from(value);
        }
      });

      final aiService = AiJudgeService();
      final scores = await aiService.evaluateAnswers(
        letter: currentLetter,
        categories: currentCategories,
        answers: roundAnswers,
      );

      debugPrint('DEBUG: AI Scores: $scores');

      final currentScores = Map<String, int>.from(data['playerScores'] ?? {});
      scores.forEach((pid, score) {
        currentScores[pid] = (currentScores[pid] ?? 0) + score;
      });

      final currentRound = data['currentRound'] as int;
      final letters = data['letters'] as List;

      if (currentRound >= letters.length) {
        await _firestore.collection('rooms').doc(roomId).update({
          'status': 'finished',
          'playerScores': currentScores,
        });
        // Clients will handle finalization via stream
      } else {
        final allCategories = List<String>.from(NameCityConstants.categories);
        allCategories.shuffle();
        final nextCategories = allCategories.take(5).toList();

        await _firestore.collection('rooms').doc(roomId).update({
          'currentRound': currentRound + 1,
          'currentCategories': nextCategories,
          'roundAnswers': {},
          'playerScores': currentScores,
          'lastRoundScores': scores, // Store round-specific scores
          'endTime': DateTime.now()
              .add(Duration(seconds: gameDuration))
              .millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint("Error in endNameCityRound: $e");
    }
  }
}

final multiplayerControllerProvider =
    StateNotifierProvider<MultiplayerController, MultiplayerState>((ref) {
      return MultiplayerController();
    });
