import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/question_model.dart';
import '../data/services/api_service.dart';

// State for the game
class GameState {
  final List<QuestionModel> questions;
  final int currentQuestionIndex;
  final int score;
  final bool isLoading;
  final bool isGameOver;
  final int timeLeft;
  final int? selectedAnswerIndex;

  GameState({
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.score = 0,
    this.isLoading = true,
    this.isGameOver = false,
    this.timeLeft = 15,
    this.selectedAnswerIndex,
  });

  GameState copyWith({
    List<QuestionModel>? questions,
    int? currentQuestionIndex,
    int? score,
    bool? isLoading,
    bool? isGameOver,
    int? timeLeft,
    int? selectedAnswerIndex,
    bool clearSelectedAnswer = false,
  }) {
    return GameState(
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
      isGameOver: isGameOver ?? this.isGameOver,
      timeLeft: timeLeft ?? this.timeLeft,
      selectedAnswerIndex: clearSelectedAnswer
          ? null
          : (selectedAnswerIndex ?? this.selectedAnswerIndex),
    );
  }
}

// Provider
final gameControllerProvider =
    StateNotifierProvider.autoDispose<GameController, GameState>((ref) {
      return GameController(ApiService());
    });

class GameController extends StateNotifier<GameState> {
  final ApiService _apiService;
  Timer? _timer;

  GameController(this._apiService) : super(GameState());

  Future<void> startGame({String? category}) async {
    try {
      state = state.copyWith(
        isLoading: true,
        isGameOver: false,
        score: 0,
        currentQuestionIndex: 0,
      );
      final questions = await _apiService.fetchQuestions(
        limit: 10,
        category: category,
      );
      state = state.copyWith(questions: questions, isLoading: false);
      if (questions.isNotEmpty) {
        _startTimer();
      }
    } catch (e) {
      // Handle error state appropriately
      state = state.copyWith(isLoading: false, questions: []);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(timeLeft: 15);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeLeft > 0) {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      } else {
        _timer?.cancel();
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    // Treat as wrong answer or move to next
    nextQuestion();
  }

  void submitAnswer(int selectedIndex) {
    // Prevent multiple answers
    if (state.selectedAnswerIndex != null) return;

    _timer?.cancel();
    final currentQuestion = state.questions[state.currentQuestionIndex];
    final isCorrect = currentQuestion.isCorrect(selectedIndex);

    // Update state to show selection
    state = state.copyWith(
      selectedAnswerIndex: selectedIndex,
      score: isCorrect ? state.score + 10 : state.score,
    );

    // Delay for visual feedback
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        nextQuestion();
      }
    });
  }

  void nextQuestion() {
    if (state.currentQuestionIndex < state.questions.length - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        clearSelectedAnswer: true, // Reset selection
      );
      _startTimer();
    } else {
      endGame();
    }
  }

  void endGame() {
    _timer?.cancel();
    state = state.copyWith(isGameOver: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
