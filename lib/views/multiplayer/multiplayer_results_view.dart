import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/multiplayer_controller.dart';
import '../../services/ad_service.dart';

class MultiplayerResultsView extends ConsumerStatefulWidget {
  final String roomId;
  final Map<String, dynamic> finalScores;
  final int totalQuestions;

  const MultiplayerResultsView({
    super.key,
    required this.roomId,
    required this.finalScores,
    required this.totalQuestions,
  });

  @override
  ConsumerState<MultiplayerResultsView> createState() =>
      _MultiplayerResultsViewState();
}

class _MultiplayerResultsViewState
    extends ConsumerState<MultiplayerResultsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processGameResults();
    });
  }

  Future<void> _processGameResults() async {
    final controller = ref.read(multiplayerControllerProvider.notifier);
    final myId = controller.userId;

    // Show Ad
    ref.read(adServiceProvider).showInterstitialAd();

    // Sort scores
    final sortedEntries = widget.finalScores.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final myScore = widget.finalScores[myId] as int? ?? 0;

    // Determine winner (first in sorted list)
    final winnerId = sortedEntries.isNotEmpty ? sortedEntries.first.key : null;
    final isWin = winnerId == myId;

    // Trigger Finalize
    await controller.finalizeGame(widget.roomId, myScore, isWin);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(multiplayerControllerProvider.notifier);
    final myId = controller.userId;

    // Sort scores
    final sortedEntries = widget.finalScores.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
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
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                'SONUÇLAR',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.5),

              const SizedBox(height: 40),

              // Winner Podium (Top 1)
              if (sortedEntries.isNotEmpty)
                StreamBuilder<DocumentSnapshot>(
                  stream: controller.roomStream(widget.roomId),
                  builder: (context, snapshot) {
                    final roomData =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    final playersData =
                        roomData?['playersData'] as Map<String, dynamic>? ?? {};
                    return _buildWinnerCard(
                      context,
                      sortedEntries.first,
                      playersData,
                    );
                  },
                ),

              const SizedBox(height: 32),

              // Leaderboard List
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: controller.roomStream(widget.roomId),
                  builder: (context, snapshot) {
                    final roomData =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    final playersData =
                        roomData?['playersData'] as Map<String, dynamic>? ?? {};

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListView.separated(
                        itemCount: sortedEntries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final entry = sortedEntries[index];
                          final playerId = entry.key;
                          final score = entry.value as int;
                          final isMe = playerId == myId;

                          final pData =
                              playersData[playerId] as Map<String, dynamic>?;
                          final name =
                              pData?['username'] as String? ?? 'Oyuncu';
                          final avatar = pData?['avatar'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isMe
                                  ? Colors.blueAccent.withAlpha(50)
                                  : Colors.white10,
                              backgroundImage: avatar != null
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar == null
                                  ? Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              isMe ? 'Sen ($name)' : name,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.blueAccent
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '$score Puan',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ).animate().fadeIn(
                            delay: Duration(milliseconds: 200 * index),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await controller
                              .leaveRoom(); // Clear state and leave room
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: const Text('Lobiye Dön'),
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
  }

  Widget _buildWinnerCard(
    BuildContext context,
    MapEntry<String, dynamic> winner,
    Map<String, dynamic> playersData,
  ) {
    final pid = winner.key;
    final pData = playersData[pid] as Map<String, dynamic>?;
    final name = pData?['username'] as String? ?? 'Oyuncu';
    final avatar = pData?['avatar'] as String?;

    return Column(
      children: [
        if (avatar != null)
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(avatar),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut)
        else
          const Icon(
            Icons.emoji_events,
            color: Colors.amber,
            size: 64,
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

        const SizedBox(height: 16),
        Text(
          'KAZANAN',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.amber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${winner.value} Puan',
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}
