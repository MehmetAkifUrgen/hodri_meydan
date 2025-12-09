class QuestionModel {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String category;
  final String? imageUrl;
  final String? flagSvg;

  QuestionModel({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    this.imageUrl,
    this.flagSvg,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    String? questionText = json['question'] as String?;
    String? imgUrl = json['image_url'] as String?;
    String? flagUrl = json['flag_svg'] as String?;

    if (questionText == null && (imgUrl != null || flagUrl != null)) {
      questionText = 'Görseldeki nedir?';
    }

    return QuestionModel(
      question: questionText ?? 'Soru yüklenemedi',
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswerIndex: (json['correct_answer'] as int?) ?? 0,
      category: json['category'] as String? ?? 'Genel',
      imageUrl: imgUrl,
      flagSvg: flagUrl,
    );
  }

  bool isCorrect(int selectedIndex) {
    return selectedIndex == correctAnswerIndex;
  }
}
