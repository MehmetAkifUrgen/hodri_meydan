import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class AiJudgeService {
  late final GenerativeModel _model;
  // TODO: Secure this key properly in production (e.g. buildConfigField or retrieving from backend)
  static const String _apiKey = 'AIzaSyCa3e7DKe0iNLhd-5iyz8g-UofK-IS4_r8';

  AiJudgeService() {
    _model = GenerativeModel(
      model:
          'gemini-2.5-flash', // Using 1.5 Flash as "2.5" is likely a typo or future version
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
  Future<Map<String, int>> evaluateAnswers({
    required String letter,
    required List<String> categories,
    required Map<String, Map<String, String>> answers,
  }) async {
    try {
      // 1. Construct the Prompt
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
      buffer.writeln("2. Check validity based on the category type:");
      buffer.writeln(
        "   - **Fact-Based Categories** (City, Country, Animal, Name, etc.):",
      );
      buffer.writeln("     - Correct: 10 points.");
      buffer.writeln("     - Incorrect: 0 points.");
      buffer.writeln(
        "   - **Open-Ended / Scenario Categories** (e.g., 'Thing in Fridge', 'Reason to be late'):",
      );
      buffer.writeln(
        "     - **Top Answer (Highly Relevant/Common)**: 20 points (e.g., Category: 'Kitchen Item', Answer: 'Fork').",
      );
      buffer.writeln(
        "     - **Good Answer**: 10 points (e.g., Category: 'Kitchen Item', Answer: 'Radio' - if rare but possible).",
      );
      buffer.writeln("     - **Weak Answer**: 5 points.");
      buffer.writeln("     - **Invalid**: 0 points.");
      buffer.writeln(
        "3. Respond with a JSON object mapping ONLY Player ID to Total Score.",
      );

      final prompt = buffer.toString();
      debugPrint('DEBUG: AI Prompt: $prompt');

      // 2. Call Gemini (with 10s timeout)
      final content = [Content.text(prompt)];
      final response = await _model
          .generateContent(content)
          .timeout(const Duration(seconds: 10));

      final responseText = response.text;
      debugPrint('DEBUG: AI Response: $responseText');

      if (responseText == null) return {};

      // 3. Parse JSON
      final Map<String, dynamic> jsonMap = jsonDecode(responseText);
      return jsonMap.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (e) {
      debugPrint("AI Judge Error: $e");
      // Fallback: Give simple points based on non-empty
      return _fallbackScoring(letter, answers);
    }
  }

  Map<String, int> _fallbackScoring(
    String letter,
    Map<String, Map<String, String>> answers,
  ) {
    final scores = <String, int>{};
    answers.forEach((pid, pAnswers) {
      int score = 0;
      pAnswers.forEach((cat, val) {
        if (val.trim().isNotEmpty &&
            val.trim().toUpperCase().startsWith(letter)) {
          score += 10;
        }
      });
      scores[pid] = score;
    });
    return scores;
  }
}
