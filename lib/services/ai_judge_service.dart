import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class AiJudgeService {
  late final GenerativeModel _model;
  // TODO: Secure this key properly in production (e.g. buildConfigField or retrieving from backend)
  static const String _apiKey = 'AIzaSyCTMjom5WL-DslbKqRpJCvYQTdlWhMs6aQ';

  AiJudgeService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
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
      buffer.writeln("2. Scoring Rules (Range 0-15):");
      buffer.writeln("   - 0 points: Incorrect, Empty, or Wrong start letter.");
      buffer.writeln(
        "   - 1-15 points: Valid answer. Grade granularity based on rarity/creativity.",
      );
      buffer.writeln("     * Example: Common answer = 5-7 pts.");
      buffer.writeln("     * Example: Good answer = 8-10 pts.");
      buffer.writeln("     * Example: Unique/Funny answer = 11-15 pts.");
      buffer.writeln(
        "   - Give precise scores (e.g. 7, 9, 12, 14) not just multiples of 5.",
      );
      buffer.writeln(
        "3. Respond with a JSON object. Key = Player ID. Value = Object with 'total' (int) and 'breakdown' (Map<Category, int>).",
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
