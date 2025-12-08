import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Hata: $error')),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      data: (user) {
        // Fallback for null user (e.g. Guest or missing doc)
        final displayUser =
            user ??
            UserModel(
              id: 'guest',
              email: '',
              username: 'Misafir',
              profileImageUrl: null,
              coins: 0,
              xp: 0,
              level: 1,
            );

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  // Settings logic
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Glow
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(100),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary.withAlpha(100),
                                      blurRadius: 20,
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      displayUser.profileImageUrl ??
                                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPG3iq9wl6RV5nsmHstHLOL1jhQB9QUrm7054eZ9FnECY8lRlZ41mZsjCnjRHPWhw7RLV8rlJzUKyyJF0u7rj3LhHXN-UtX4f7yCsyCPRhb3aeHSVHETOKzu1rodJXN2BDlstrdEk1HsdzW0y6B04Te3dLbTWod6ldYHi7ptPrAbyKRM1sx6_kF8SGjudEW6FVONHoL3F0zOL5WVGVwqoybUqhE635Fuy7LasrhJU1Rjdaz3OpGtuharFpL7sL3MxKV_woJzvytBYA',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // Edit Profile Logic
                                  },
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            displayUser.username,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          Text(
                            'ID: ${displayUser.id.substring(0, min(8, displayUser.id.length))}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Level Progress
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Seviye ${displayUser.level}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${displayUser.xp} / 1000 XP',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: (displayUser.xp % 1000) / 1000,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(context).colorScheme.secondary,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sign Up Button for Guest Users
                          if (FirebaseAuth.instance.currentUser?.isAnonymous ??
                              false)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _showLinkAccountDialog(context, ref);
                                },
                                icon: const Icon(
                                  Icons.security,
                                  color: Colors.white,
                                ),
                                label: const Text("Hesabı Kaydet (Kayıt Ol)"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ).animate().shimmer(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Stats Grid
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        context,
                        'Oyunlar',
                        '${displayUser.gamesPlayed}',
                        Icons.sports_esports,
                      ),
                      _buildStatCard(
                        context,
                        'Kazanma',
                        '${displayUser.gamesPlayed > 0 ? (displayUser.wins / displayUser.gamesPlayed * 100).toStringAsFixed(1) : 0}%',
                        Icons.emoji_events,
                      ),
                      _buildStatCard(
                        context,
                        'Skor',
                        '${displayUser.totalScore}',
                        Icons.star,
                      ),
                    ],
                  ),
                ),

                // Match History
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Son Maçlar',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Mock Match History for now (until we have MatchModel)
                      _buildMatchHistoryItem(context, 'Zafer', '+150 XP', true),
                      _buildMatchHistoryItem(
                        context,
                        'Yenilgi',
                        '+20 XP',
                        false,
                      ),
                      _buildMatchHistoryItem(context, 'Zafer', '+200 XP', true),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper methods
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistoryItem(
    BuildContext context,
    String result,
    String reward,
    bool won,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: won ? Colors.green.withAlpha(100) : Colors.red.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: won
                      ? Colors.green.withAlpha(20)
                      : Colors.red.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  won ? Icons.emoji_events : Icons.close,
                  color: won ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Genel Kültür',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Text(
            reward,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for safe substring
  int min(int a, int b) => a < b ? a : b;

  void _showLinkAccountDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Hesabı Kaydet',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Misafir hesabınızı kaybetmemek için e-posta ve şifre belirleyin.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                ),
                validator: (value) =>
                    value!.contains('@') ? null : 'Geçerli bir e-posta girin',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                ),
                validator: (value) =>
                    value!.length >= 6 ? null : 'En az 6 karakter',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  Navigator.pop(context); // Close dialog
                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hesap bağlanıyor...')),
                  );

                  await ref
                      .read(authControllerProvider.notifier)
                      .linkAccount(
                        emailController.text.trim(),
                        passwordController.text.trim(),
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hesap başarıyla kaydedildi! 🎉'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
