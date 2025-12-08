import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // For ImageFilter
import '../profile/profile_view.dart';
import '../leaderboard/leaderboard_view.dart';
import '../minigame/name_city_view.dart';
import '../multiplayer/lobby_view.dart';
import '../categories/category_selection_view.dart';
import '../../controllers/auth_controller.dart';
import '../settings/settings_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Elements (Grid/Orbs)
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
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileView(),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: NetworkImage(
                                        user?.profileImageUrl ??
                                            'https://lh3.googleusercontent.com/aida-public/AB6AXuBPG3iq9wl6RV5nsmHstHLOL1jhQB9QUrm7054eZ9FnECY8lRlZ41mZsjCnjRHPWhw7RLV8rlJzUKyyJF0u7rj3LhHXN-UtX4f7yCsyCPRhb3aeHSVHETOKzu1rodJXN2BDlstrdEk1HsdzW0y6B04Te3dLbTWod6ldYHi7ptPrAbyKRM1sx6_kF8SGjudEW6FVONHoL3F0zOL5WVGVwqoybUqhE635Fuy7LasrhJU1Rjdaz3OpGtuharFpL7sL3MxKV_woJzvytBYA',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hoşgeldin,',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(180),
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      user?.username ?? 'Misafir',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(100),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white12),
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

                      // Hero Section (Removed Dynamite Image)
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          "Bilgine Güveniyor Musun?",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.start,
                        ).animate().fadeIn().slideX(),
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
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CategorySelectionView(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _GlassMenuCard(
                              title: 'Çok Oyunculu',
                              subtitle: 'Arkadaşlarına meydan oku',
                              icon: Icons.people_outline,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LobbyView(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _GlassMenuCard(
                              title: 'İsim Şehir',
                              subtitle: 'Klasik oyunlar, modern dokunuş',
                              icon: Icons.grid_view,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NameCityView(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                              icon: const Icon(Icons.home, color: Colors.white),
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
