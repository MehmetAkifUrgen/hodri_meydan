import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiJudgeService {
  late final GenerativeModel _model;

  AiJudgeService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      debugPrint("ERROR: GEMINI_API_KEY not found in .env");
      // Fail gracefully or throw
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey ?? '',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // Force JSON
      ),
    );
  }

  /// Evaluates answers for a Name City game round.
  ///
  /// [letter]: The target letter (e.g., 'A').
  /// [categories]: List of categories (e.g., ['Name', 'City']).
  /// [answers]: Map of PlayerID -> {Category -> Answer}.
  ///
  /// Returns a Map of PlayerID -> Score for this round.
  /// Evaluates answers with detailed breakdown.
  Future<Map<String, AiEvaluationResult>> evaluateAnswersDetailed({
    required String letter,
    required List<String> categories,
    required Map<String, Map<String, String>> answers,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        "You are the judge of a 'Name City' (İsim Şehir) game in Turkish.",
      );
      buffer.writeln("Target Letter: '$letter'.");
      buffer.writeln("Categories: ${categories.join(', ')}.");
      buffer.writeln("Players' Answers: ${jsonEncode(answers)}");

      buffer.writeln("\nInstructions:");
      buffer.writeln(
        "1. Evaluate each answer. It MUST start with the target letter.",
      );
      buffer.writeln("2. Scoring Rules (Human-like Judge):");
      buffer.writeln(
        "   - 10 points: Strong, correct answer. Clearly fits the category.",
      );
      buffer.writeln(
        "   - 5 points: Debatable / Weak answer. Technically correct but a stretch, or a very generic synonym. (Think 'Family Feud' - 'Show me... Answer!' logic).",
      );
      buffer.writeln(
        "   - 0 points: Clearly incorrect or wrong starting letter.",
      );
      buffer.writeln(
        "   - FLEXIBILITY: Use your intelligence. If an answer is 'conceptually' correct or a common association, accept it.",
      );
      buffer.writeln(
        "   - Example: Category 'Living Room Object', Letter 'T'. Answer 'TV' (English) -> Accept as 10 (Common usage).",
      );
      buffer.writeln(
        "   - Example: Category 'City', Letter 'I'. Answer 'Istanbul' (Starts with I or İ) -> Accept.",
      );
      buffer.writeln(
        "3. Comparison/Context: Judge each answer on its own merit, but be consistent.",
      );
      buffer.writeln(
        "4. Respond with a JSON object. Key = Player ID. Value = Object with 'total' (int) and 'breakdown' (Map<Category, int>).",
      );
      buffer.writeln("Example JSON structure:");
      buffer.writeln('''
      {
        "player1": {
          "total": 30,
          "breakdown": {
            "Name": 10,
            "City": 10,
            "Animal": 0,
            "Plant": 10
          }
        }
      }
      ''');

      final prompt = buffer.toString();
      debugPrint('DEBUG: AI detailed Prompt: $prompt');

      final content = [Content.text(prompt)];
      final response = await _model
          .generateContent(content)
          .timeout(const Duration(seconds: 15));

      final responseText = response.text;
      debugPrint('DEBUG: AI detailed Response: $responseText');

      if (responseText == null) return {};

      // Cleanup markdown code blocks if present
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> jsonMap = jsonDecode(cleanJson);
      return jsonMap.map((key, value) {
        final valMap = value as Map<String, dynamic>;
        return MapEntry(
          key,
          AiEvaluationResult(
            totalScore: (valMap['total'] as num).toInt(),
            breakdown: Map<String, int>.from(valMap['breakdown']),
          ),
        );
      });
    } catch (e) {
      debugPrint("AI Judge Detailed Error: $e");
      return {};
    }
  }

  // Keep original for backward compatibility if needed, or update it to use the detailed one
  Future<Map<String, int>> evaluateAnswers({
    required String letter,
    required List<String> categories,
    required Map<String, Map<String, String>> answers,
  }) async {
    // Re-use detailed logic to ensure consistency
    final detailed = await evaluateAnswersDetailed(
      letter: letter,
      categories: categories,
      answers: answers,
    );
    return detailed.map((key, value) => MapEntry(key, value.totalScore));
  }
}

class AiEvaluationResult {
  final int totalScore;
  final Map<String, int> breakdown;

  AiEvaluationResult({required this.totalScore, required this.breakdown});
}
