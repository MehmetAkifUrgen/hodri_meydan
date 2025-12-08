import 'package:flutter/material.dart';
import '../game/quiz_view.dart';
import '../../data/services/api_service.dart'; // Import ApiService
import 'package:flutter_animate/flutter_animate.dart';

class CategorySelectionView extends StatefulWidget {
  const CategorySelectionView({super.key});

  @override
  State<CategorySelectionView> createState() => _CategorySelectionViewState();
}

class _CategorySelectionViewState extends State<CategorySelectionView> {
  final ApiService _apiService = ApiService();
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _apiService.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Seç'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: FutureBuilder<List<String>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kategoriler Yüklenemedi',
                        style: TextStyle(color: Colors.white70),
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
                    'Kategori bulunamadı.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final categories = snapshot.data!;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return _CategoryCard(
                      title: categories[index],
                      delay: index * 100,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuizView(category: categories[index]),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final int delay;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(
            20,
          ), // Use withValues if preferred, allowing alpha for glass logic
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star, // Dynamic icon based on category would be better
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).scale();
  }
}
