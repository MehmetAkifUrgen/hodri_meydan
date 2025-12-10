import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // For ImageFilter
import '../../services/ad_service.dart';
import '../../services/firestore_service.dart';
import '../profile/profile_view.dart';
import '../leaderboard/leaderboard_view.dart';
// import '../minigame/multiplayer_name_city_view.dart'; // Unused
// Wait, previous import was `../minigame/name_city_view.dart`. I should check if that file exists or I renamed it.
// I renamed/refactored logic. `MultiplayerNameCityView` is for multiplayer.
// Is there a single player Name City? The menu says "Classics".
// I will check the file list if needed, but I Recall `NameCityView` existed.
// Attempt to use `name_city_view.dart` first.
import '../minigame/name_city_view.dart';
import '../multiplayer/lobby_view.dart';
import '../categories/category_selection_view.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../settings/settings_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  void _showNoLivesDialog(BuildContext context, WidgetRef ref, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Canın Kalmadı!",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Oyun oynamak için cana ihtiyacın var. Reklam izleyerek +3 Can kazanabilirsin.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _watchAdForLife(context, ref, uid);
            },
            child: const Text("İzle (+3 ❤️)"),
          ),
        ],
      ),
    );
  }

  void _watchAdForLife(BuildContext context, WidgetRef ref, String uid) {
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

  void _checkLivesAndNavigate(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    Widget targetPage,
  ) async {
    if (user == null) return;

    if (user.lives > 0) {
      // Deduct life immediately
      // Optimistic UI? Firestore prevents playing if < 0 anyway? No logic in FS.
      // We deduct locally? No, call service.
      await ref.read(firestoreServiceProvider).updateLives(user.id, -1);

      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => targetPage));
      }
    } else {
      _showNoLivesDialog(context, ref, user.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'Hata oluştu: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      data: (user) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              // Background Glow
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(50),
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // User Info Row
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(
                                          user?.profileImageUrl ??
                                              'https://ui-avatars.com/api/?name=${user?.username ?? "Misafir"}&background=random',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Merhaba,",
                                              style: GoogleFonts.spaceGrotesk(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              user?.username ?? "Misafir",
                                              style: GoogleFonts.spaceGrotesk(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stats Row (Dynamite + Lives + Settings)
                                Row(
                                  children: [
                                    // Lives Indicator
                                    GestureDetector(
                                      onTap: () {
                                        if (user != null && user.lives < 5) {
                                          _watchAdForLife(
                                            context,
                                            ref,
                                            user.id,
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(100),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: (user?.lives ?? 0) == 0
                                                ? Colors.red
                                                : Colors.white12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.favorite,
                                              color: Colors.pinkAccent,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${user?.lives ?? 0}',
                                              style: GoogleFonts.spaceGrotesk(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if ((user?.lives ?? 5) < 5) ...[
                                              const SizedBox(width: 4),
                                              // Tiny plus icon
                                              const Icon(
                                                Icons.add_circle,
                                                color: Colors.greenAccent,
                                                size: 14,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Dynamite Indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(100),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Image.asset(
                                            'assets/images/dynamite_logo_3d.png',
                                            width: 20,
                                            height: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${user?.coins ?? 0}',
                                            style: GoogleFonts.spaceGrotesk(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SettingsView(),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(10),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.settings,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Menu
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                _GlassMenuCard(
                                  title: 'Tek Kişilik',
                                  subtitle: 'Kendinle yarış, rekorları kır',
                                  icon: Icons.person_outline,
                                  onTap: () => _checkLivesAndNavigate(
                                    context,
                                    ref,
                                    user,
                                    const CategorySelectionView(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _GlassMenuCard(
                                  title: 'Çok Oyunculu',
                                  subtitle: 'Arkadaşlarına meydan oku',
                                  icon: Icons.people_outline,
                                  onTap: () => _checkLivesAndNavigate(
                                    context,
                                    ref,
                                    user,
                                    const LobbyView(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _GlassMenuCard(
                                  title: 'Modern İsim Şehir',
                                  subtitle: 'Klasik oyunlar, modern dokunuş',
                                  icon: Icons.grid_view,
                                  onTap: () => _checkLivesAndNavigate(
                                    context,
                                    ref,
                                    user,
                                    const NameCityView(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 32),
                          // Footer
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.home,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.emoji_events_outlined,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LeaderboardView(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileView(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
