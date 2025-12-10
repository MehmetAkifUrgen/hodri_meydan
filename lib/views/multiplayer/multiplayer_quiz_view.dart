import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  int? _lastPrecachedIndex; // Track pre-caching to avoid spam
  late Stream<DocumentSnapshot> _roomStream;

  @override
  void initState() {
    super.initState();
    _roomStream = ref
        .read(multiplayerControllerProvider.notifier)
        .roomStream(widget.roomId);
  }

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
        // Time is up!
        if (!_hasAnswered) {
          setState(() {
            _hasAnswered = true;
          });
          // Submit empty answer (-1) to proceed
          ref
              .read(multiplayerControllerProvider.notifier)
              .submitAnswer(widget.roomId, _currentQuestionIndexCache, -1, 0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(multiplayerControllerProvider.notifier);
    final myId = controller.userId;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(multiplayerControllerProvider.notifier).leaveRoom();
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: _roomStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0B1121),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          // Handle Room Closed (Deleted)
          if (data == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Oda kapatıldı (Yetersiz oyuncu)."),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
            return const Scaffold(
              backgroundColor: Color(0xFF0B1121),
              body: Center(child: Text("Oda kapatılıyor...")),
            );
          }

          final questions = data['questions'] as List<dynamic>? ?? [];
          final currentQuestionIndex =
              data['currentQuestionIndex'] as int? ?? 0;
          final startTime = data['startTime'] as int? ?? 0;
          final hostId = data['hostId'] as String?;
          final isHost = hostId == myId;

          final answers = Map<String, dynamic>.from(data['answers'] ?? {});
          final playersData = Map<String, dynamic>.from(
            data['playersData'] ?? {},
          );
          final players = List<String>.from(data['players'] ?? []);

          // Host Logic: Check if all players answered
          if (isHost &&
              answers.isNotEmpty &&
              answers.length >= players.length &&
              data['nextQuestionTime'] == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.processRoundEnd(widget.roomId);
            });
          }

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
            return const Scaffold(
              backgroundColor: Color(0xFF0B1121),
              body: Center(
                child: Text(
                  'Soru yükleniyor...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          // Check Game Over (Status or Index)
          if (data['status'] == 'finished' ||
              currentQuestionIndex >= questions.length) {
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
            return const Scaffold(
              backgroundColor: Color(0xFF0B1121),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final questionData =
              questions[currentQuestionIndex] as Map<String, dynamic>;
          final questionText = questionData['question'] as String;
          final imageUrl = questionData['image_url'] as String?;
          final flagSvg = questionData['flag_svg'] as String?;
          final options = List<String>.from(questionData['options'] ?? []);
          final correctAnswerIndex = questionData['correct_answer'] as int;

          // Aggressive Pre-caching: Load next 2 images
          if (_lastPrecachedIndex != currentQuestionIndex) {
            _lastPrecachedIndex = currentQuestionIndex;

            // Loop for next 2 items
            for (int i = 1; i <= 2; i++) {
              final nextIndex = currentQuestionIndex + i;
              if (nextIndex < questions.length) {
                final nextQ = questions[nextIndex] as Map<String, dynamic>;
                final nextUrl = nextQ['image_url'] as String?;
                if (nextUrl != null && nextUrl.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      precacheImage(NetworkImage(nextUrl), context);
                      debugPrint('Pre-caching image for Q${nextIndex + 1}');
                    } catch (e) {
                      debugPrint('Error pre-caching: $e');
                    }
                  });
                }
              }
            }
          }

          final nextQuestionTime = data['nextQuestionTime'] as int?;
          final bool isReviewPhase = nextQuestionTime != null;

          return Scaffold(
            backgroundColor: const Color(0xFF0B1121),
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              toolbarHeight: 80, // Increased height for rope
              titleSpacing:
                  0, // Remove default spacing to allow full width control
              centerTitle: false, // Let the widget fill the space
              title: _buildRopeLeaderboard(
                context,
                data['scores'],
                playersData,
                questions.length,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF0B1121).withAlpha(240),
                    BlendMode.darken,
                  ),
                  onError: (_, __) {},
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
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

                              // Circular Timer (Hide during review)
                              if (!isReviewPhase)
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
                                const SizedBox(height: 20),

                                // Image or Flag if available
                                if (flagSvg != null && flagSvg.isNotEmpty)
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: SvgPicture.network(
                                      flagSvg,
                                      fit: BoxFit.contain,
                                      placeholderBuilder: (context) =>
                                          Container(
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                          ),
                                    ),
                                  )
                                else if (imageUrl != null &&
                                    imageUrl.isNotEmpty)
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
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Colors.white10,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, _) =>
                                            const Icon(
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
                                  final isSelected =
                                      _selectedAnswerIndex == index;
                                  final isCorrect = index == correctAnswerIndex;

                                  // Filter players who chose this option
                                  final playersWhoChoseThis = answers.entries
                                      .where(
                                        (a) =>
                                            (a.value['answer'] as int) == index,
                                      )
                                      .map((a) => playersData[a.key])
                                      .where((p) => p != null)
                                      .toList();

                                  // Determine color state
                                  Color optionColor = const Color(0xFF1E293B);
                                  Color borderColor = Colors.white10;

                                  if (isReviewPhase) {
                                    // Reveal Phase: Show Correct/Wrong colors
                                    if (isSelected) {
                                      optionColor = isCorrect
                                          ? Colors.green.shade900
                                          : Colors.red.shade900;
                                      borderColor = isCorrect
                                          ? Colors.green
                                          : Colors.red;
                                    } else if (isCorrect) {
                                      // Highlight correct answer for everyone
                                      borderColor = Colors.green;
                                      optionColor = Colors.green.shade900
                                          .withAlpha(100);
                                    }
                                  } else {
                                    // Answering Phase: Show Blue for selected
                                    if (isSelected) {
                                      optionColor = Colors.blueAccent.withAlpha(
                                        100,
                                      );
                                      borderColor = Colors.blueAccent;
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
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: optionColor.withAlpha(200),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isSelected && !isReviewPhase
                                                ? Colors.blueAccent
                                                : borderColor,
                                            width:
                                                (isSelected ||
                                                    (isReviewPhase &&
                                                        isCorrect))
                                                ? 2
                                                : 1,
                                          ),
                                          boxShadow:
                                              (isSelected ||
                                                  (isReviewPhase && isCorrect))
                                              ? [
                                                  BoxShadow(
                                                    color: borderColor
                                                        .withAlpha(100),
                                                    blurRadius: 10,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  alignment: Alignment.center,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.white10,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Text(
                                                    String.fromCharCode(
                                                      65 + index,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                if (isReviewPhase && isCorrect)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green,
                                                  ),
                                                if (isReviewPhase &&
                                                    isSelected &&
                                                    !isCorrect)
                                                  const Icon(
                                                    Icons.cancel,
                                                    color: Colors.red,
                                                  ),
                                                // Show waiting indicator if selected but not revealed
                                                if (isSelected &&
                                                    !isReviewPhase)
                                                  const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color:
                                                              Colors.blueAccent,
                                                        ),
                                                  ),
                                              ],
                                            ),

                                            // Avatars of other players who chose this
                                            if (isReviewPhase &&
                                                playersWhoChoseThis.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                  left: 46,
                                                ),
                                                child: Row(
                                                  children: [
                                                    ...playersWhoChoseThis.take(5).map((
                                                      p,
                                                    ) {
                                                      final String? pAvatarUrl =
                                                          p['avatar']
                                                              as String?;
                                                      final bool hasValidUrl =
                                                          pAvatarUrl != null &&
                                                          pAvatarUrl.startsWith(
                                                            'http',
                                                          );
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 4,
                                                            ),
                                                        child: CircleAvatar(
                                                          radius: 10,
                                                          backgroundColor:
                                                              Colors.grey[800],
                                                          backgroundImage:
                                                              hasValidUrl
                                                              ? NetworkImage(
                                                                  pAvatarUrl,
                                                                )
                                                              : null,
                                                          child: !hasValidUrl
                                                              ? const Icon(
                                                                  Icons.person,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .white70,
                                                                )
                                                              : null,
                                                        ),
                                                      );
                                                    }),
                                                    if (playersWhoChoseThis
                                                            .length >
                                                        5)
                                                      Text(
                                                        '+${playersWhoChoseThis.length - 5}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 20),

                                if (!isHost && _hasAnswered && !isReviewPhase)
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

                    // Next Question Countdown Overlay
                    if (isReviewPhase)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Sonraki Soru Hazırlanıyor...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder(
                              stream: Stream.periodic(
                                const Duration(milliseconds: 100),
                              ),
                              builder: (context, _) {
                                final timeLeft =
                                    ((nextQuestionTime -
                                                DateTime.now()
                                                    .millisecondsSinceEpoch) /
                                            1000)
                                        .ceil();
                                return Text(
                                  timeLeft > 0 ? "$timeLeft" : "0",
                                  style: GoogleFonts.spaceGrotesk(
                                    color: const Color(0xFF00F6FF),
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate().fadeIn(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRopeLeaderboard(
    BuildContext context,
    Map<String, dynamic>? scores,
    Map<String, dynamic> playersData,
    int totalQuestions,
  ) {
    if (scores == null || scores.isEmpty) return const SizedBox.shrink();

    // maxPossibleScore removed (unused)

    // Convert scores to list for processing
    // Convert scores to list for processing if needed (but we iterate players)
    // entries variable removed as it was unused

    // Get All Players to ensure everyone is shown, even with 0 score
    final playersList = List<String>.from(playersData.keys.toList());
    // Actually simpler: iterate scores? No, some might not have scores.
    // playersData should have everyone. Or roomData['players'].
    // But we only have scores and playersData arguments here.
    // Let's assume playersData has keys for all players.

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 80, // Height for straight text
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // The Track
              SizedBox(
                width: constraints.maxWidth,
                height: 80,
                child: CustomPaint(
                  painter: StraightLinePainter(checkpoints: totalQuestions),
                ),
              ),

              // The Avatars
              ...playersList.map((uid) {
                final score = scores[uid] ?? 0;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;

                    final String? avatarUrl = userData['avatar'] as String?;
                    final bool hasValidUrl =
                        avatarUrl != null && avatarUrl.startsWith('http');

                    final currentUserId = ref
                        .read(multiplayerControllerProvider.notifier)
                        .userId;
                    final isMe = uid == currentUserId;

                    // Correct Bounds: Subtract Avatar Width (32) to keep inside screen
                    final double avatarWidth = 32.0;
                    final double pathWidth = constraints.maxWidth - avatarWidth;

                    // scaling
                    final maxPossibleScore = totalQuestions * 10.0;
                    final displayMax = maxPossibleScore > 0
                        ? maxPossibleScore
                        : 100.0;
                    final percent = (score / displayMax).clamp(0.0, 1.0);

                    // Calculate Exact Position
                    final double left = pathWidth * percent;

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
                      left: left,
                      bottom:
                          24, // Fixed vertical position for straight line (Center 40 - 16)
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: isMe ? Colors.yellow : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage: hasValidUrl
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: !hasValidUrl
                                  ? const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Small dot indicator on the line
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
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

class StraightLinePainter extends CustomPainter {
  final int checkpoints;

  StraightLinePainter({required this.checkpoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerY = size.height / 2;

    // Draw Straight Line
    path.moveTo(16, centerY);
    // Draw to width - 16 to keep padding
    path.lineTo(size.width - 16, centerY);
    canvas.drawPath(path, paint);

    // Draw Checkpoints
    final double availableWidth = size.width - 32;
    // count MUST match question count for "1 step per question"
    final int count = checkpoints > 0 ? checkpoints : 1;

    for (int i = 0; i <= count; i++) {
      final double x = 16 + (availableWidth * (i / count));
      canvas.drawCircle(Offset(x, centerY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
