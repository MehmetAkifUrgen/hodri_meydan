import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/user_model.dart';
import '../../services/firestore_service.dart';

final leaderboardProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getGlobalLeaderboard();
});

class LeaderboardView extends ConsumerWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Liderlik Tablosu',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: leaderboardAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Henüz veri yok.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Top 3
          final top3 = users.take(3).toList();
          final rest = users.skip(3).toList();

          return Column(
            children: [
              // Filters (Mock for now)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFilterChip(context, 'Global', true),
                    const SizedBox(width: 12),
                    _buildFilterChip(context, 'Arkadaşlar', false),
                  ],
                ),
              ),

              // Podium
              if (top3.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 2nd Place
                      if (top3.length > 1)
                        Positioned(
                          left: 40,
                          bottom: 40,
                          child: _buildPodiumItem(context, top3[1], 2),
                        ),
                      // 1st Place
                      if (top3.isNotEmpty)
                        Positioned(
                          bottom: 70,
                          child: _buildPodiumItem(context, top3[0], 1),
                        ),
                      // 3rd Place
                      if (top3.length > 2)
                        Positioned(
                          right: 40,
                          bottom: 20,
                          child: _buildPodiumItem(context, top3[2], 3),
                        ),
                    ],
                  ),
                ),

              // List
              Expanded(
                child: ListView.builder(
                  itemCount: rest.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final user = rest[index];
                    return _buildRankItem(context, user, index + 4);
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Hata: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPodiumItem(BuildContext context, UserModel user, int rank) {
    final double size = rank == 1 ? 100 : 80;
    final Color color = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : const Color(0xFFCD7F32); // Bronze

    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(100),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(
                    user.profileImageUrl ??
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBPG3iq9wl6RV5nsmHstHLOL1jhQB9QUrm7054eZ9FnECY8lRlZ41mZsjCnjRHPWhw7RLV8rlJzUKyyJF0u7rj3LhHXN-UtX4f7yCsyCPRhb3aeHSVHETOKzu1rodJXN2BDlstrdEk1HsdzW0y6B04Te3dLbTWod6ldYHi7ptPrAbyKRM1sx6_kF8SGjudEW6FVONHoL3F0zOL5WVGVwqoybUqhE635Fuy7LasrhJU1Rjdaz3OpGtuharFpL7sL3MxKV_woJzvytBYA',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: -10,
              child: rank == 1
                  ? const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFFFD700),
                      size: 32,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '${user.totalScore}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ).animate().scale(delay: (rank * 200).ms, curve: Curves.easeOutBack);
  }

  Widget _buildRankItem(BuildContext context, UserModel user, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundImage: NetworkImage(
              user.profileImageUrl ??
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBPG3iq9wl6RV5nsmHstHLOL1jhQB9QUrm7054eZ9FnECY8lRlZ41mZsjCnjRHPWhw7RLV8rlJzUKyyJF0u7rj3LhHXN-UtX4f7yCsyCPRhb3aeHSVHETOKzu1rodJXN2BDlstrdEk1HsdzW0y6B04Te3dLbTWod6ldYHi7ptPrAbyKRM1sx6_kF8SGjudEW6FVONHoL3F0zOL5WVGVwqoybUqhE635Fuy7LasrhJU1Rjdaz3OpGtuharFpL7sL3MxKV_woJzvytBYA',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              user.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '${user.totalScore}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
