import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/constants/name_city_constants.dart';
import '../../services/ai_judge_service.dart';
import '../../services/ad_service.dart';

class NameCityView extends ConsumerStatefulWidget {
  const NameCityView({super.key});

  @override
  ConsumerState<NameCityView> createState() => _NameCityViewState();
}

class _NameCityViewState extends ConsumerState<NameCityView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late String _currentLetter;
  late List<String> _currentCategories;
  final Map<String, TextEditingController> _controllers = {};

  // Game State
  bool _isEvaluating = false;
  bool _isGameStarted = false;
  int _selectedDuration = 60; // Default 60s

  final _alphabet = "ABCÇDEFGHIİJKLMNOÖPRSŞTUÜVYZ";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _selectedDuration),
    );

    // Auto-finish when time is up
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isEvaluating && mounted) {
          _submitAnswers();
        }
      }
    });
  }

  void _startGame() {
    setState(() {
      _isGameStarted = true;
      _controller.duration = Duration(seconds: _selectedDuration);
    });
    _initializeRound();
    _controller.forward(from: 0);
  }

  void _initializeRound() {
    // Pick random letter
    _currentLetter = _alphabet[math.Random().nextInt(_alphabet.length)];

    // Pick 5 random categories
    final allCats = List<String>.from(NameCityConstants.categories);
    allCats.shuffle();
    _currentCategories = allCats.take(5).toList();

    // Init controllers
    _controllers.clear();
    for (var cat in _currentCategories) {
      _controllers[cat] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAnswers() async {
    if (_isEvaluating) return;

    setState(() {
      _isEvaluating = true;
    });
    _controller.stop(); // Ensure timer stops

    try {
      // 1. Collect Answers (Handle empty strings gracefully)
      final Map<String, String> myAnswers = {};
      _controllers.forEach((category, controller) {
        myAnswers[category] = controller.text.trim();
      });

      // 2. Wrap for AI Service
      final allAnswers = {'player': myAnswers};

      // 3. Call AI Judge
      final aiService = AiJudgeService();
      final scores = await aiService.evaluateAnswersDetailed(
        letter: _currentLetter,
        categories: _currentCategories,
        answers: allAnswers,
      );

      final myResult = scores['player'];

      if (!mounted) return;

      // Show Ad
      ref.read(adServiceProvider).showInterstitialAd();

      if (myResult != null) {
        // 4. Show Result
        _showResultDialog(myResult);
      } else {
        // Fallback for extremely rare failures: assume 0
        _showResultDialog(AiEvaluationResult(totalScore: 0, breakdown: {}));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isEvaluating = false;
        });
      }
    }
  }

  void _showResultDialog(AiEvaluationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          "Sonuçlar",
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Toplam: ${result.totalScore}",
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _currentCategories.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final category = _currentCategories[index];
                    final answer = _controllers[category]?.text ?? "";
                    final score = result.breakdown[category] ?? 0;
                    final isCorrect = score > 0;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        answer.isEmpty ? "(Boş bırakıldı)" : answer,
                        style: TextStyle(
                          color: isCorrect
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Colors.green.withAlpha(50)
                              : Colors.red.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCorrect ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          "+$score",
                          style: TextStyle(
                            color: isCorrect ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("Tamam"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Restart same setup? Or go back to setup?
              // Let's restart with same settings effectively
              setState(() {
                _initializeRound();
                _controller.reset();
                _controller.duration = Duration(seconds: _selectedDuration);
                _controller.forward();
              });
            },
            child: const Text("Tekrar Oyna"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGameStarted) {
      return _buildSetupScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF100C1A), // Very Dark
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Round 1/1',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 40), // Spacer
                ],
              ),
            ),

            // Timer & Letter
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        // Calculate remaining time for display
                        final remaining =
                            (_selectedDuration * (1 - _controller.value))
                                .ceil();

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(180, 180),
                              painter: _TimerPainter(
                                progress: _controller.value,
                              ),
                            ),
                            // Fixed: Text inside AnimatedBuilder updates every tick
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentLetter,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      const BoxShadow(
                                        color: Color(0xFF00F6FF),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$remaining',
                                  style: const TextStyle(
                                    color: Color(0xFF00F6FF),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Inputs
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ..._currentCategories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildInputField(
                          category,
                          '$category girin...',
                          _controllers[category]!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Footer Action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF100C1A),
                    const Color(0xFF100C1A).withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isEvaluating ? null : _submitAnswers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF00FF), Color(0xFFFFC700)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF00FF).withAlpha(128),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isEvaluating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'BİTİR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF100C1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "İSİM ŞEHİR",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),

              Text(
                "Süre Seçiniz",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),

              // Duration Toggles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildDurationOption(60)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDurationOption(90)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDurationOption(120)),
                ],
              ),

              const SizedBox(height: 64),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F6FF), Color(0xFF0057FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        "OYUNA BAŞLA",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationOption(int seconds) {
    final isSelected = _selectedDuration == seconds;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDuration = seconds;
        });
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00F6FF).withAlpha(50)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00F6FF) : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          "$seconds sn",
          style: TextStyle(
            color: isSelected ? const Color(0xFF00F6FF) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00F6FF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFFA490CB).withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;

  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background Circle
    final bgPaint = Paint()
      ..color = const Color(0xFF2F2249)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress Arc
    final fgPaint = Paint()
      ..color = const Color(0xFF00F6FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * (1 - progress), // Draw remaining time
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
