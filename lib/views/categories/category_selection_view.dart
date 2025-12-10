import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/services/api_service.dart';
import '../game/quiz_view.dart';
import '../../controllers/auth_controller.dart';
import '../../services/firestore_service.dart';
import '../../services/ad_service.dart';

class CategorySelectionView extends ConsumerStatefulWidget {
  const CategorySelectionView({super.key});

  @override
  ConsumerState<CategorySelectionView> createState() =>
      _CategorySelectionViewState();
}

class _CategorySelectionViewState extends ConsumerState<CategorySelectionView> {
  final ApiService _apiService = ApiService();
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _apiService.fetchCategories();
  }

  void _checkLivesAndStart(String category) {
    final userAsync = ref.read(userProvider);
    final user = userAsync.value;

    if (user == null) return;

    if (user.lives > 0) {
      // Deduct life
      ref.read(firestoreServiceProvider).updateLives(user.id, -1);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizView(category: category)),
      );
    } else {
      _showNoLivesDialog(context, user.id);
    }
  }

  void _showNoLivesDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Yetersiz Can!",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Canınız kalmadı. Reklam izleyerek can kazanabilirsiniz.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tamam", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _watchAdForLife(context, uid);
            },
            child: const Text("İzle (+3 ❤️)"),
          ),
        ],
      ),
    );
  }

  void _watchAdForLife(BuildContext context, String uid) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Kategoriler',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Kategoriler yüklenemedi',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _categoriesFuture = _apiService.fetchCategories();
                      });
                    },
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Kategori bulunamadı',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final categories = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(categories[index], index);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category, int index) {
    // Generate a consistent color based on category name length/hash
    final colorBranch = index % 4;
    Color color;
    IconData icon;

    switch (colorBranch) {
      case 0:
        color = const Color(0xFF4F46E5); // Indigo
        icon = Icons.bolt;
        break;
      case 1:
        color = const Color(0xFFEC4899); // Pink
        icon = Icons.auto_awesome;
        break;
      case 2:
        color = const Color(0xFF06B6D4); // Cyan
        icon = Icons.science;
        break;
      default:
        color = const Color(0xFF8B5CF6); // Violet
        icon = Icons.grid_view;
    }

    return GestureDetector(
      onTap: () => _checkLivesAndStart(category),
      child:
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).animate().scale(
            delay: (index * 50).ms,
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}
