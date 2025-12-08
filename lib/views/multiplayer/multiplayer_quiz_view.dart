import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/multiplayer_controller.dart';
import 'multiplayer_results_view.dart';

class MultiplayerQuizView extends ConsumerStatefulWidget {
  final String roomId;

  const MultiplayerQuizView({super.key, required this.roomId});

  @override
  ConsumerState<MultiplayerQuizView> createState() =>
      _MultiplayerQuizViewState();
}

class _MultiplayerQuizViewState extends ConsumerState<MultiplayerQuizView> {
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  Timer? _timer;
  int _timeLeft = 20;
  int _currentQuestionIndexCache = -1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocalTimer(int startTimeMillis) {
    _timer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = ((now - startTimeMillis) / 1000).floor();
    setState(() {
      _timeLeft = (20 - elapsedSeconds).clamp(0, 20);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        // Handle timeout if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(multiplayerControllerProvider.notifier);
    final myId = controller.userId;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'ÇOK OYUNCULU',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            // Show exit confirmation
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(
              'assets/images/background.png',
            ), // Fallback or use color
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              const Color(0xFF0B1121).withAlpha(240),
              BlendMode.darken,
            ),
            onError: (_, __) {},
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: controller.roomStream(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Center(child: Text("Oda kapandı"));

            final questions = data['questions'] as List<dynamic>? ?? [];
            final currentQuestionIndex =
                data['currentQuestionIndex'] as int? ?? 0;
            final startTime = data['startTime'] as int? ?? 0;
            final hostId = data['hostId'] as String?;
            final isHost = hostId == myId;

            // Reset local state on new question
            if (currentQuestionIndex != _currentQuestionIndexCache) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _currentQuestionIndexCache = currentQuestionIndex;
                    _selectedAnswerIndex = null;
                    _hasAnswered = false;
                  });
                  _startLocalTimer(startTime);
                }
              });
            }

            if (questions.isEmpty) {
              return const Center(
                child: Text(
                  'Soru yükleniyor...',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Check Game Over
            if (currentQuestionIndex >= questions.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MultiplayerResultsView(
                      roomId: widget.roomId,
                      finalScores: Map<String, dynamic>.from(
                        data['scores'] ?? {},
                      ),
                      totalQuestions: questions.length,
                    ),
                  ),
                );
              });
              return const Center(
                child: CircularProgressIndicator(),
              ); // Placeholder while navigating
            }

            final questionData =
                questions[currentQuestionIndex] as Map<String, dynamic>;
            final questionText = questionData['question'] as String;
            final imageUrl = questionData['image_url'] as String?;
            final options = List<String>.from(questionData['options'] ?? []);
            final correctAnswerIndex = questionData['correct_answer'] as int;

            return SafeArea(
              child: Column(
                children: [
                  // Timer and Progress
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGlassBadge(
                          context,
                          icon: Icons.question_mark,
                          text:
                              '${currentQuestionIndex + 1}/${questions.length}',
                          color: Colors.blueAccent,
                        ),

                        // Circular Timer
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _timeLeft / 20,
                              backgroundColor: Colors.white24,
                              color: _getTimerColor(_timeLeft),
                            ),
                            Text(
                              '$_timeLeft',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                        _buildGlassBadge(
                          context,
                          icon: Icons.star,
                          text:
                              '${data['scores']?[myId] ?? 0}', // Current Score
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Image if available
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            Container(
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(100),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white10,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, _) => const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                          // Question Text
                          Text(
                            questionText,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn().slideY(begin: 0.3),

                          const SizedBox(height: 32),

                          // Options
                          ...options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final text = entry.value;
                            final isSelected = _selectedAnswerIndex == index;
                            final isCorrect = index == correctAnswerIndex;

                            // Determine color state
                            Color optionColor = const Color(0xFF1E293B);
                            Color borderColor = Colors.white10;

                            if (_hasAnswered) {
                              if (isSelected) {
                                optionColor = isCorrect
                                    ? Colors.green.shade900
                                    : Colors.red.shade900;
                                borderColor = isCorrect
                                    ? Colors.green
                                    : Colors.red;
                              } else if (isCorrect) {
                                // Show correct answer even if didn't pick it
                                borderColor = Colors.green;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: _hasAnswered
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedAnswerIndex = index;
                                          _hasAnswered = true;
                                        });
                                        controller.submitAnswer(
                                          widget.roomId,
                                          currentQuestionIndex,
                                          index,
                                          _timeLeft,
                                        );
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: optionColor.withAlpha(200),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? borderColor
                                          : Colors.white12,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: borderColor.withAlpha(100),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          String.fromCharCode(
                                            65 + index,
                                          ), // A, B, C, D
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (_hasAnswered && isSelected)
                                        Icon(
                                          isCorrect
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 20),

                          // Host Controls (Next Question)
                          if (isHost && _hasAnswered)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  controller.nextQuestion(widget.roomId),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text("SONRAKİ SORU"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ).animate().fadeIn(),

                          if (!isHost && _hasAnswered)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Diğer oyuncular bekleniyor...",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassBadge(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTimerColor(int timeLeft) {
    if (timeLeft > 10) return Colors.green;
    if (timeLeft > 5) return Colors.amber;
    return Colors.red;
  }
}
