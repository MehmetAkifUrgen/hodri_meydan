import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/login_view.dart';

class FeaturesView extends StatelessWidget {
  const FeaturesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Dinamit\'i Keşfet',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _navigateToLogin(context),
            child: const Text(
              'Geç',
              style: TextStyle(
                color: Color(0xFFA490CB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.bolt,
                    title: 'Gerçek Zamanlı Çok Oyunculu',
                    subtitle:
                        'Canlı bilgi yarışmalarında arkadaşlarına veya dünya çapındaki oyunculara meydan oku.',
                    delay: 100,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    icon: Icons.category,
                    title: 'Çeşitli Kategoriler',
                    subtitle: 'Yüzlerce heyecan verici konuda binlerce soru.',
                    delay: 200,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    icon: Icons.gamepad, // Joystick approximation
                    title: 'Heyecanlı Mini Oyunlar',
                    subtitle:
                        'Maçlar arasında hızlı turlar ve benzersiz meydan okumalar.',
                    delay: 300,
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(active: false),
                      const SizedBox(width: 12),
                      _buildDot(active: true),
                      const SizedBox(width: 12),
                      _buildDot(active: false),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _navigateToLogin(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF4F46E5,
                        ), // Indigo Primary
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'İleri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF221834),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF433168)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFA490CB),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.1);
  }

  Widget _buildDot({required bool active}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4F46E5) : const Color(0xFF433168),
        shape: BoxShape.circle,
      ),
    );
  }
}
