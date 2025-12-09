import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrl =
      'https://mehmetakifurgen.github.io/kpssApi/genel_trivia.json';

  Future<List<String>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> root = json.decode(response.body);
        final Map<String, dynamic> categories = root['categories'];
        return categories.keys.toList();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  Future<List<QuestionModel>> fetchQuestions({
    int limit = 10,
    String? category,
  }) async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> root = json.decode(response.body);
        final Map<String, dynamic> data = root['categories'];
        final List<QuestionModel> allQuestions = [];

        if (category != null && data.containsKey(category)) {
          final questionsData = data[category];
          if (questionsData is List) {
            allQuestions.addAll(_parseQuestions(questionsData, category));
          }
        } else {
          // If no category selected or not found, fetch all
          data.forEach((cat, questionsData) {
            if (questionsData is List) {
              allQuestions.addAll(_parseQuestions(questionsData, cat));
            }
          });
        }

        // Shuffle and take limited number
        allQuestions.shuffle();
        return allQuestions.take(limit).toList();
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      throw Exception('Error fetching questions: $e');
    }
  }

  List<QuestionModel> _parseQuestions(List<dynamic> data, String category) {
    List<QuestionModel> parsedQuestions = [];
    List<String> validAnswers = [];

    // Identify parsing strategy based on first valid item
    bool isStandard = true;
    bool isMovie = false;
    bool isCharacter = false;
    bool isFlag = false;

    if (data.isNotEmpty) {
      // Find first non-null map to sniff structure
      final firstItem =
          data.firstWhere(
                (e) => e is Map<String, dynamic>,
                orElse: () => <String, dynamic>{},
              )
              as Map<String, dynamic>;

      if (firstItem.isNotEmpty) {
        if (firstItem.containsKey('question')) {
          isStandard = true;
        } else if (firstItem.containsKey('flag_svg')) {
          isStandard = false;
          isFlag = true;
          // Collect all names/countries for distractors
          validAnswers = data
              .whereType<Map<String, dynamic>>()
              .map((e) => e['name'] as String?)
              .where((e) => e != null && e.isNotEmpty)
              .cast<String>()
              .toList();
        } else if (firstItem.containsKey('movie_title')) {
          isStandard = false;
          isMovie = true;
          // Collect all movie titles for distractors
          validAnswers = data
              .whereType<Map<String, dynamic>>()
              .map((e) => e['movie_title'] as String?)
              .where((e) => e != null && e.isNotEmpty)
              .cast<String>()
              .toList();
        } else if (firstItem.containsKey('name')) {
          isStandard = false;
          isCharacter = true;
          // Collect all names for distractors
          validAnswers = data
              .whereType<Map<String, dynamic>>()
              .map((e) => e['name'] as String?)
              .where((e) => e != null && e.isNotEmpty)
              .cast<String>()
              .toList();
        }
      }
    }

    for (var item in data) {
      if (item is! Map<String, dynamic>) continue;

      try {
        if (isStandard) {
          // Attempt to parse standard question
          if (item.containsKey('question') || item.containsKey('options')) {
            parsedQuestions.add(QuestionModel.fromJson(item));
          }
        } else {
          // Dynamic Generation
          String correctAnswer = '';
          String? imageUrl;
          String? flagSvgVal;
          String questionText = 'Görseldeki nedir?';

          if (isFlag) {
            correctAnswer = item['name'] as String? ?? '';
            flagSvgVal = item['flag_svg'] as String?;
            questionText = 'Görseldeki ülke hangisidir?';
          } else if (isMovie) {
            correctAnswer = item['movie_title'] as String? ?? '';
            imageUrl = item['scene_image_url'] as String?;
            questionText = 'Görseldeki film hangisidir?';
          } else if (isCharacter) {
            correctAnswer = item['name'] as String? ?? '';
            imageUrl = item['image_url'] as String?;
            questionText = 'Görseldeki karakter kimdir?';
          }

          // Only add if we have a valid answer and (image OR flag)
          if (correctAnswer.isNotEmpty &&
              (imageUrl != null || flagSvgVal != null)) {
            // Generate Options
            final options = List<String>.from(validAnswers);
            options.remove(correctAnswer); // Remove self
            options.shuffle(); // Shuffle pool
            final distractors = options.take(3).toList(); // Take 3

            final finalOptions = [...distractors, correctAnswer];
            finalOptions.shuffle(); // Shuffle position

            parsedQuestions.add(
              QuestionModel(
                question: questionText,
                options: finalOptions,
                correctAnswerIndex: finalOptions.indexOf(correctAnswer),
                category: category,
                imageUrl: imageUrl,
                flagSvg: flagSvgVal,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Dynamic Parse Error ($category): $e');
      }
    }

    return parsedQuestions;
  }
}
