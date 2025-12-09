import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: "Bilgini Yarıştır",
      description:
          "Binlerce soru ile genel kültürünü test et. Puanları topla, liderlik tablosunda yüksel!",
      icon: Icons.quiz,
      color: Colors.purpleAccent,
      imageAsset: 'assets/images/dynamite_logo_3d.png',
    ),
    OnboardingSlide(
      title: "Arkadaşlarınla Oyna",
      description:
          "Özel odalar kur veya rastgele rakiplerle eşleş. Gerçek zamanlı bilgi yarışması heyecanını yaşa.",
      icon: Icons.people_outline,
      color: Colors.blueAccent,
    ),
    OnboardingSlide(
      title: "Modern İsim Şehir ve Fazlası",
      description:
          "Sadece test değil! İsim Şehir gibi klasik oyunlarla eğlenceye doy. Kelime hazineni göster.",
      icon: Icons.location_city,
      color: Colors.orangeAccent,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (mounted) {
      // Navigate to AuthWrapper (or whatever the main entry point is)
      // Since main.dart determines initial route, we can just pushReplacement to AuthWrapper
      // Assuming AuthWrapper is accessible or we can use named route '/' if setup.
      // But main logic usually sets 'home'.
      // We will pushReplacement specific widget.
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B1121),
                  _slides[_currentPage].color.withAlpha(50),
                  const Color(0xFF0B1121),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                        _isLastPage = index == _slides.length - 1;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _buildSlide(_slides[index]);
                    },
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: 300.ms,
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _slides[_currentPage].color
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next/Done Button
                      ElevatedButton(
                        onPressed: () {
                          if (_isLastPage) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: 500.ms,
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _slides[_currentPage].color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          _isLastPage ? "BAŞLA" : "İLERİ",
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (slide.imageAsset != null)
            Image.asset(
              slide.imageAsset!,
              height: 250,
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack)
          else
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: slide.color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(slide.icon, size: 100, color: slide.color),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 48),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.5),

          const SizedBox(height: 16),

          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? imageAsset;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.imageAsset,
  });
}
