import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NameCityView extends StatefulWidget {
  const NameCityView({super.key});

  @override
  State<NameCityView> createState() => _NameCityViewState();
}

class _NameCityViewState extends State<NameCityView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100C1A), // Very Dark
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Round 3/5',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 40), // Spacer
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
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _TimerPainter(progress: _controller.value),
                        );
                      },
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'B',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 72,
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
                        '${(60 * (1 - _controller.value)).ceil()}',
                        style: const TextStyle(
                          color: Color(0xFF00F6FF),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Inputs
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildInputField('İsim', 'Bir isim girin'),
                    const SizedBox(height: 16),
                    _buildInputField('Şehir', 'Bir şehir girin'),
                    const SizedBox(height: 16),
                    _buildInputField('Hayvan', 'Bir hayvan girin'),
                    const SizedBox(height: 16),
                    _buildInputField('Bitki', 'Bir bitki girin'),
                    const SizedBox(height: 16),
                    _buildInputField('Eşya', 'Bir eşya girin'),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Footer Action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF100C1A),
                    const Color(0xFF100C1A).withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF00FF), Color(0xFFFFC700)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF00FF).withAlpha(128),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        'BİTİR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00F6FF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFFA490CB).withOpacity(0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;

  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background Circle
    final bgPaint = Paint()
      ..color = const Color(0xFF2F2249)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress Arc
    final fgPaint = Paint()
      ..color = const Color(0xFF00F6FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * (1 - progress), // Draw remaining time
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
