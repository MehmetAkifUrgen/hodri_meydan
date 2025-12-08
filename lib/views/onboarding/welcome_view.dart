import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'features_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1121), // Dark Void Navy
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withAlpha(50), // Indigo
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withAlpha(50), // Magenta
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo Text
                Text(
                  'DINAMIT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ).animate().fadeIn().slideY(begin: -0.5),

                const Spacer(),

                // Glass Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Dinamit\'e Hoşgeldin',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'En iyi gerçek zamanlı bilgi yarışması. Arkadaşlarına ve rakiplerine meydan oku.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).moveY(begin: 50),

                const Spacer(),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDot(active: true, context: context),
                          const SizedBox(width: 12),
                          _buildDot(active: false, context: context),
                          const SizedBox(width: 12),
                          _buildDot(active: false, context: context),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Get Started Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FeaturesView(),
                                ),
                              );
                            },
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFFEC4899,
                                  ), // Magenta
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ).copyWith(
                                  shadowColor: WidgetStateProperty.all(
                                    const Color(0xFFEC4899).withAlpha(100),
                                  ),
                                  elevation: WidgetStateProperty.all(10),
                                ),
                            child: const Text(
                              'Başla',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 1),
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

  Widget _buildDot({required bool active, required BuildContext context}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEC4899) : Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }
}
