import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../controllers/multiplayer_controller.dart';
import '../multiplayer/multiplayer_results_view.dart';

class MultiplayerNameCityView extends ConsumerStatefulWidget {
  final String roomId;
  final List<String> letters;
  final int initialRound;
  final int endTime;
  final List<String> initialCategories;

  const MultiplayerNameCityView({
    super.key,
    required this.roomId,
    required this.letters,
    required this.initialRound,
    required this.endTime,
    required this.initialCategories,
  });

  @override
  ConsumerState<MultiplayerNameCityView> createState() =>
      _MultiplayerNameCityViewState();
}

class _MultiplayerNameCityViewState
    extends ConsumerState<MultiplayerNameCityView>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  // Dynamic Controllers: Key is Category Name
  final Map<String, TextEditingController> _controllers = {};
  List<String> _currentCategories = [];

  int _currentRound = 1;
  String? _hostId;
  Timer? _localTimer;
  int _secondsRemaining = 60;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.initialRound;
    _currentCategories = widget.initialCategories;
    _initializeControllers();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    _startRound(widget.endTime);
  }

  void _initializeControllers() {
    // Clear old if any (though usually empty on init)
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    for (var category in _currentCategories) {
      _controllers[category] = TextEditingController();
    }
  }

  void _startRound(int endTime) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = endTime - now;
    _secondsRemaining = (remainingMs / 1000).clamp(0, 60).toInt();

    _timerController.duration = const Duration(seconds: 60);
    double startValue = 1.0 - (_secondsRemaining / 60.0);
    _timerController.forward(from: startValue);

    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timerController.stop();
            timer.cancel();
            _autoSubmit();

            // Host Logic to End Round
            if (_hostId != null &&
                ref.read(multiplayerControllerProvider.notifier).userId ==
                    _hostId) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  ref
                      .read(multiplayerControllerProvider.notifier)
                      .endNameCityRound(widget.roomId);
                }
              });
            }
          }
        });
      }
    });

    _submitted = false;
  }

  void _autoSubmit() {
    if (!_submitted) {
      _submitAnswers();
    }
  }

  Future<void> _submitAnswers() async {
    setState(() {
      _submitted = true;
    });

    // Scoring: 10 points per filled field for local feedback
    int points = 0;
    for (var controller in _controllers.values) {
      if (controller.text.trim().isNotEmpty) {
        points += 10;
      }
    }
    debugPrint('DEBUG: Local auto-score calculated: $points');

    // Submit to Firestore
    final answers = <String, String>{};
    _controllers.forEach((key, value) {
      answers[key] = value.text.trim();
    });

    try {
      await ref
          .read(multiplayerControllerProvider.notifier)
          .submitNameCityAnswers(widget.roomId, answers);
    } catch (e) {
      debugPrint('Error submitting answers: $e');
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _localTimer?.cancel();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get currentLetter {
    if (_currentRound - 1 < widget.letters.length) {
      return widget.letters[_currentRound - 1];
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final roomStream = ref
        .watch(multiplayerControllerProvider.notifier)
        .roomStream(widget.roomId);

    return Scaffold(
      backgroundColor: const Color(0xFF100C1A),
      body: StreamBuilder<DocumentSnapshot>(
        stream: roomStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            _hostId = data['hostId'] as String?;
            final serverRound = data['currentRound'] as int? ?? 1;
            final status = data['status'] as String? ?? 'playing_nameCity';

            // Check Game Over
            if (status == 'finished') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MultiplayerResultsView(
                      roomId: widget.roomId,
                      finalScores: Map<String, dynamic>.from(
                        data['playerScores'] ?? {},
                      ),
                      totalQuestions: widget.letters.length,
                    ),
                  ),
                );
              });
              return const Center(child: CircularProgressIndicator());
            }

            // Detect Round Change
            if (serverRound != _currentRound) {
              final lastRoundScores = Map<String, dynamic>.from(
                data['lastRoundScores'] ?? {},
              );

              if (lastRoundScores.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showRoundSummary(context, serverRound - 1, lastRoundScores);
                });
              }

              // Update Round
              _currentRound = serverRound;
              // Update Categories if changed
              final newCategories = List<String>.from(
                data['currentCategories'] ?? [],
              );
              if (newCategories.isNotEmpty &&
                  newCategories.toString() != _currentCategories.toString()) {
                _currentCategories = newCategories;
                _initializeControllers();
              }
              // Restart Timer
              final endTime = data['endTime'] as int? ?? 0;
              _startRound(endTime);
            }
          }

          return SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          ref
                              .read(multiplayerControllerProvider.notifier)
                              .leaveRoom();
                          Navigator.pop(context);
                        },
                      ),
                      Text(
                        'Round $_currentRound/5',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 40),
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
                        width: 100,
                        height: 100,
                        child: AnimatedBuilder(
                          animation: _timerController,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: 1.0 - _timerController.value,
                              strokeWidth: 6,
                              backgroundColor: const Color(0xFF2F2249),
                              color: const Color(0xFF00F6FF),
                            );
                          },
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentLetter,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 42,
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
                            '$_secondsRemaining',
                            style: const TextStyle(
                              color: Color(0xFF00F6FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic Inputs
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ..._currentCategories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInputField(
                              category,
                              '$category girin (${currentLetter})',
                              _controllers[category] ?? TextEditingController(),
                            ),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Footer
                if (!_submitted)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitAnswers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F6FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'BİTİR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            enabled: !_submitted,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFFA490CB).withOpacity(0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRoundSummary(
    BuildContext context,
    int roundNumber,
    Map<String, dynamic> scores,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 4), () {
          if (context.mounted) Navigator.of(context).pop();
        });

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            "Round $roundNumber Sonuçları",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: scores.entries.map((e) {
              return ListTile(
                title: Text(
                  // Show abbreviated ID if no username available locally
                  "Oyuncu ${e.key.substring(0, 4)}",
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Text(
                  "+${e.value} Puan",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
