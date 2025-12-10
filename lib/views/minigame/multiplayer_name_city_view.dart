import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../controllers/multiplayer_controller.dart';
import '../multiplayer/multiplayer_results_view.dart';

class MultiplayerNameCityView extends ConsumerStatefulWidget {
  final String roomId;
  final List<String> letters;
  final int initialRound;
  final int endTime;
  final List<String> initialCategories;
  final int gameDuration; // Passed from lobby

  const MultiplayerNameCityView({
    super.key,
    required this.roomId,
    required this.letters,
    required this.initialRound,
    required this.endTime,
    required this.initialCategories,
    this.gameDuration = 60,
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
      duration: Duration(seconds: widget.gameDuration),
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
    _secondsRemaining = (remainingMs / 1000)
        .clamp(0, widget.gameDuration)
        .toInt();

    // Reset controller
    _timerController.duration = Duration(seconds: newRoundDuration());
    // Actually we want the controller to represent the FULL duration visual
    // But we are starting in the middle potentially.
    // Progress = remaining / total

    double progress = _secondsRemaining / widget.gameDuration.toDouble();
    _timerController.value = 1.0 - progress; // value goes 0..1
    _timerController.duration = Duration(seconds: widget.gameDuration);
    _timerController.forward(from: 1.0 - progress);

    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now().millisecondsSinceEpoch;
          final diff = (endTime - now) / 1000;
          _secondsRemaining = diff.ceil().clamp(0, widget.gameDuration);

          if (_secondsRemaining <= 0) {
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

  int newRoundDuration() => widget.gameDuration;

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
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00F6FF)),
            );
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _hostId = data['hostId'] as String?;
          final serverRound = data['currentRound'] as int? ?? 1;
          final status = data['status'] as String? ?? 'playing_nameCity';

          // Check insufficient players
          final players = List<String>.from(data['players'] ?? []);
          if (players.length < 2 && status != 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Diğer oyuncular ayrıldı, oyun bitti.'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Oyun kapatılıyor...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          // Analyzing Phase
          if (status == 'analyzing_nameCity') {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00F6FF)),
                  SizedBox(height: 16),
                  Text(
                    "Tüm oyuncular tamamladı.\nAI Değerlendiriyor...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Intermission: Round Results
          if (status == 'name_city_round_results') {
            final lastRoundScores = Map<String, dynamic>.from(
              data['lastRoundScores'] ?? {},
            );
            final playersData =
                data['playersData'] as Map<String, dynamic>? ?? {};
            final breakdown = Map<String, dynamic>.from(
              data['lastRoundBreakdown'] ?? {},
            );

            // Host Logic has been moved to _buildRoundResultsView to ensure timed execution

            return _buildRoundResultsView(
              context,
              serverRound, // It's the round that just finished?
              lastRoundScores,
              playersData,
              breakdown,
              data['endTime'] as int? ?? 0,
            );
          }

          // Normal Gameplay: Check Early End (Host Only)
          if (status == 'playing_nameCity') {
            final roundAnswersMap =
                data['roundAnswers'] as Map<String, dynamic>? ?? {};
            // Only check if we have enough players to matter (avoid solo bugs though we fixed solo exit)
            if (players.isNotEmpty &&
                roundAnswersMap.length >= players.length) {
              if (_hostId != null &&
                  ref.read(multiplayerControllerProvider.notifier).userId ==
                      _hostId) {
                // Debounce slightly to ensure all writes propagate?
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(multiplayerControllerProvider.notifier)
                      .endNameCityRound(widget.roomId);
                });
              }
            }
          }

          // Check Game Over
          if (status == 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Prevent multiple triggers
              if (_submitted && !Navigator.canPop(context)) {
                // Already processing finish or summary open
              }

              // Show Final Round Summary if available
              final lastRoundScores = Map<String, dynamic>.from(
                data['lastRoundScores'] ?? {},
              );
              if (lastRoundScores.isNotEmpty &&
                  _currentRound == widget.letters.length) {
                // We rely on the final results screen now.
                // If we want to show the last round specific breakdown, we'd need to
                // use a different flow, but for now we skip the dialog to avoid errors.
              }

              // Navigate after delay to let user see summary
              Future.delayed(const Duration(seconds: 5), () {
                if (context.mounted) {
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
                }
              });
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Detect Round Change
          if (serverRound != _currentRound) {
            final lastRoundScores = Map<String, dynamic>.from(
              data['lastRoundScores'] ?? {},
            );

            if (lastRoundScores.isNotEmpty) {
              // Removed Old Summary Dialog Logic to prevent conflict
              /*
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final playersData =
                      data['playersData'] as Map<String, dynamic>? ?? {};
                  _showRoundSummary(
                    context,
                    serverRound - 1,
                    lastRoundScores,
                    playersData,
                    Map<String, dynamic>.from(data['lastRoundBreakdown'] ?? {}),
                  );
                });
                */
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

                // Leaderboard

                // Timer & Letter (Collapsible)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: MediaQuery.of(context).viewInsets.bottom == 0
                      ? 220
                      : 0,
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    // Prevent overflow during animation
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // ... content preserved via Stack children ...
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
                              '$category girin ($currentLetter)',
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
                if (_submitted)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            "Diğer oyuncular bekleniyor...",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
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
                color: const Color(0xFFA490CB).withValues(alpha: 0.5),
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

  Widget _buildRoundResultsView(
    BuildContext context,
    int roundNumber,
    Map<String, dynamic> scores,
    Map<String, dynamic> playersData,
    Map<String, dynamic> breakdown,
    int endTimeMillis,
  ) {
    // Sort scores for this round
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Round $roundNumber Sonuç Tablosu",
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Current Round Scoreboard
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Puan Durumu",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...sortedEntries.map((e) {
                        final pid = e.key;
                        final score = e.value as int;
                        final pData = playersData[pid] as Map<String, dynamic>?;
                        final name = pData?['username'] ?? "Oyuncu";
                        final avatar = pData?['avatar'] as String?;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: avatar != null
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar == null
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                "+$score",
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Best of Categories
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "En İyiler (Kategori Bazlı)",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildBreakdownList(breakdown, playersData),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final remaining = ((endTimeMillis - now) / 1000)
                        .ceil()
                        .clamp(0, 99);

                    // Host Auto-Advance Check
                    if (remaining <= 0) {
                      final controller = ref.read(
                        multiplayerControllerProvider.notifier,
                      );
                      // We can't access _hostId directly here easily unless we pass it or read it.
                      // But we know if we are host if the controller says so or we passed it.
                      // Let's check against our local cached ID if possible, but reading from provider is safer.
                      // However, _buildRoundResultsView is a method on the State class, so we can access `ref`.
                      // We also need to know if we are the host.
                      // We can check `ref.read(multiplayerControllerProvider).value?.hostId` if available?
                      // Or better, pass `isHost` boolean to this method.

                      // BUT, simpler: Use a fire-and-forget check if we haven't already.
                      // We need a flag to prevent 60 calls per second.

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        // Re-verify host status if needed, or just fire.
                        // The controller method handles safety? No, controller doesn't check host in startNext.
                        // Actually, let's just use the `_hostId` from the parent state?
                        // Yes, `_hostId` is a member of `_MultiplayerNameCityViewState`.
                        if (_hostId != null && controller.userId == _hostId) {
                          controller.startNextNameCityRound(widget.roomId);
                        }
                      });
                    }

                    // If it's the last round (5), logic handles redirection elsewhere,
                    // but UI should reflect game is checking results.
                    return Text(
                      roundNumber >= 5
                          ? "Oyun Bitiyor..."
                          : "Sonraki tur başlıyor: $remaining",
                      style: const TextStyle(color: Colors.white54),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreakdownList(
    Map<String, dynamic> breakdown,
    Map<String, dynamic> playersData,
  ) {
    if (breakdown.isEmpty)
      return [const Text("Veri yok", style: TextStyle(color: Colors.white54))];

    final categoryWinners = <String, String>{};
    final firstPlayer = breakdown.keys.first;
    final categories = (breakdown[firstPlayer] as Map).keys.toList();

    for (var cat in categories) {
      String winner = "-";
      int maxScore = -1;

      breakdown.forEach((pid, pBreakdown) {
        final pMap = Map<String, int>.from(pBreakdown as Map);
        final score = pMap[cat] ?? 0;
        if (score > maxScore && score > 0) {
          maxScore = score;
          final pData = playersData[pid] as Map<String, dynamic>?;
          winner = pData?['username'] ?? "Oyuncu ${pid.substring(0, 4)}";
        }
      });

      if (maxScore > 0) {
        categoryWinners[cat as String] = "$winner ($maxScore)";
      }
    }

    if (categoryWinners.isEmpty) {
      return [
        const Text(
          "Bu turda geçerli puan yok.",
          style: TextStyle(color: Colors.white54),
        ),
      ];
    }

    return categoryWinners.entries.map((e) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${e.key}: ", style: const TextStyle(color: Colors.white70)),
            Expanded(
              child: Text(
                e.value, // "Ahmet (10)"
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF00F6FF),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
