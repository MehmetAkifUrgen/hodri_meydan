import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/game_controller.dart';
import '../../services/audio_service.dart';

import 'score_view.dart';

class QuizView extends ConsumerStatefulWidget {
  final String? category;
  const QuizView({super.key, this.category});

  @override
  ConsumerState<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<QuizView> {
  @override
  void initState() {
    super.initState();
    // Start game when view opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(gameControllerProvider.notifier)
          .startGame(category: widget.category);
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    // final audioService = ref.read(audioServiceProvider); // Removed to fix unused warning

    // Listen for game over
    ref.listen(gameControllerProvider, (previous, next) {
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        // Play game over sound based on score?
        // audioService.playGameOver();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ScoreView(
              score: next.score,
              totalQuestions: next.questions.length,
              correctAnswers: next.score ~/ 10,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: _buildGlowOrb(Theme.of(context).colorScheme.primary),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _buildGlowOrb(Theme.of(context).colorScheme.secondary),
          ),

          SafeArea(
            child: gameState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : gameState.questions.isEmpty
                ? _buildErrorState(context, controller)
                : _buildModernGameBody(context, gameState, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color) {
    return Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: color.withAlpha(50),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 100,
                spreadRadius: 50,
              ),
            ],
          ),
        )
        .animate()
        .scale(
          duration: 2000.ms,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.2, 1.2),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8));
  }

  Widget _buildModernGameBody(
    BuildContext context,
    GameState state,
    GameController controller,
  ) {
    final question = state.questions[state.currentQuestionIndex];
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height - 100, // Safe area approx
        ),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(100),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBPG3iq9wl6RV5nsmHstHLOL1jhQB9QUrm7054eZ9FnECY8lRlZ41mZsjCnjRHPWhw7RLV8rlJzUKyyJF0u7rj3LhHXN-UtX4f7yCsyCPRhb3aeHSVHETOKzu1rodJXN2BDlstrdEk1HsdzW0y6B04Te3dLbTWod6ldYHi7ptPrAbyKRM1sx6_kF8SGjudEW6FVONHoL3F0zOL5WVGVwqoybUqhE635Fuy7LasrhJU1Rjdaz3OpGtuharFpL7sL3MxKV_woJzvytBYA',
                      ),
                      radius: 24,
                    ),
                  ),

                  // Score
                  Column(
                    children: [
                      const Text(
                        'PUAN',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${state.score}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: state.timeLeft / 15.0,
                          strokeWidth: 4,
                          backgroundColor: Colors.white10,
                          color: state.timeLeft < 5
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      Text(
                        '${state.timeLeft}s',
                        style: TextStyle(
                          color: state.timeLeft < 5
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Soru ${state.currentQuestionIndex + 1}/${state.questions.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            (state.currentQuestionIndex + 1) /
                            state.questions.length,
                        backgroundColor: Colors.white10,
                        color: Theme.of(context).colorScheme.secondary,
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Question Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1E293B,
                  ).withAlpha(200), // Glass looking surface
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (question.flagSvg != null &&
                        question.flagSvg!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SvgPicture.network(
                            question.flagSvg!,
                            height: 120,
                            fit: BoxFit
                                .contain, // Contain flags to avoid cropping
                            placeholderBuilder: (context) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (question.imageUrl != null &&
                        question.imageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            question.imageUrl!,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Text(
                      question.question,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ).animate(key: ValueKey(question)).fadeIn().slideY(begin: 0.2),
            ),

            const SizedBox(height: 40),

            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: List.generate(question.options.length, (index) {
                  final isSelected = state.selectedAnswerIndex == index;
                  final isCorrect = question.correctAnswerIndex == index;
                  final isAnswered = state.selectedAnswerIndex != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ModernOptionButton(
                      text: question.options[index],
                      delay: index * 100,
                      onTap: isAnswered
                          ? () {}
                          : () {
                              ref.read(audioServiceProvider).playClick();
                              ref.read(audioServiceProvider).vibrate();
                              controller.submitAnswer(index);

                              // Check correctness after a slight delay or optimistic update?
                              // Actually answer is processed instantly in controller.
                              // Ideally controller should return result to play sound,
                              // or we listen to state changes.
                              // For now, let's play simple click here.
                            },
                      isSelected: isSelected,
                      isCorrect: isCorrect,
                      isAnswered: isAnswered,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, GameController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Sorular yüklenemedi',
            style: TextStyle(color: Colors.white),
          ),
          TextButton(
            onPressed: () => controller.startGame(),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _ModernOptionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final int delay;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;

  const _ModernOptionButton({
    required this.text,
    required this.onTap,
    required this.delay,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = const Color(0xFF1E293B).withAlpha(150);
    Color borderColor = Theme.of(context).colorScheme.primary.withAlpha(50);
    Color textColor = Colors.white;

    if (isAnswered) {
      if (isCorrect) {
        backgroundColor = Colors.green.withAlpha(200);
        borderColor = Colors.green;
      } else if (isSelected) {
        backgroundColor = Colors.red.withAlpha(200);
        borderColor = Colors.red;
      } else {
        // Did not select this one, and it's not the correct one
        backgroundColor = const Color(0xFF1E293B).withAlpha(100);
        textColor = Colors.white54;
      }
    }

    return ElevatedButton(
      onPressed: onTap,
      style:
          ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 2),
            ),
            elevation: 0,
          ).copyWith(
            overlayColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primary.withAlpha(50),
            ),
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          if (isAnswered)
            Icon(
              isCorrect
                  ? Icons.check_circle
                  : (isSelected ? Icons.cancel : Icons.circle_outlined),
              color: isCorrect
                  ? Colors.white
                  : (isSelected ? Colors.white : Colors.white24),
            )
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.1);
  }
}
