import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../home/home_view.dart';
import 'quiz_view.dart';
import '../../services/ad_service.dart';
import '../../services/firestore_service.dart';
import '../../controllers/auth_controller.dart';

class ScoreView extends ConsumerStatefulWidget {
  final int score;
  final int totalQuestions;
  final int correctAnswers;

  const ScoreView({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
  });

  @override
  ConsumerState<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends ConsumerState<ScoreView> {
  @override
  void initState() {
    super.initState();
    // Show Interstitial Ad when results load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).showInterstitialAd();
      _saveScore();
    });
  }

  Future<void> _saveScore() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      // Single player "win" condition could be > 50% correct, or just participation.
      // For now let's say > 50% is a "win" for bonus stats.
      final isWin = widget.correctAnswers >= (widget.totalQuestions / 2);

      try {
        await ref
            .read(firestoreServiceProvider)
            .updateUserStats(
              uid: user.uid,
              earnedScore: widget.score,
              isWin: isWin,
            );
        debugPrint("Single player score saved successfully.");
      } catch (e) {
        debugPrint("Error saving single player score: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'SONUÇLAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text('PUAN', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard(
                    'Doğru',
                    '${widget.correctAnswers}',
                    Colors.green,
                  ),
                  const SizedBox(width: 20),
                  _buildStatCard(
                    'Yanlış',
                    '${widget.totalQuestions - widget.correctAnswers}',
                    Colors.red,
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeView()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                        ),
                        child: const Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _checkLivesAndReplay,
                        child: const Text('TEKRAR OYNA'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  void _checkLivesAndReplay() {
    final userAsync = ref.read(userProvider);
    final user = userAsync.value;

    if (user != null && user.lives > 0) {
      ref.read(firestoreServiceProvider).updateLives(user.id, -1);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuizView()),
      );
    } else {
      _showNoLivesDialog();
    }
  }

  void _showNoLivesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Yetersiz Can!",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Canınız kalmadı. Reklam izleyerek can kazanabilirsiniz.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tamam", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _watchAdForLife(ref.read(userProvider).value?.id ?? "");
            },
            child: const Text("İzle (+3 ❤️)"),
          ),
        ],
      ),
    );
  }

  void _watchAdForLife(String uid) {
    if (uid.isEmpty) return;
    ref
        .read(adServiceProvider)
        .showRewardedAdWaitIfNeeded(
          context,
          onUserEarnedReward: (reward) {
            ref.read(firestoreServiceProvider).updateLives(uid, 3);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tebrikler! +3 Can kazandın."),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
  }
}
