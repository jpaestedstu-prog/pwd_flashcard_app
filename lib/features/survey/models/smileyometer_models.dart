/// Smileyometer — a child-friendly visual feedback scale for learners.
///
/// Unlike the adult [SusSurveyResult] (which teachers complete), this captures
/// the *learner's own* experience using a simple 3-point face scale
/// (Read & MacFarlane, "Fun Toolkit"). It is reported descriptively, not as a
/// usability score, because the respondents are young Deaf/HoH PWD students
/// for whom an abstract Likert instrument would not be valid.
library;

/// A learner's Smileyometer response: one face rating (1–3) per question.
class SmileyometerResult {
  final String id;
  final String profileId;
  final DateTime completedAt;

  /// One rating per question, each 1–3 (sad / okay / happy).
  final List<int> ratings;

  const SmileyometerResult({
    required this.id,
    required this.profileId,
    required this.completedAt,
    required this.ratings,
  });

  /// Mean face rating across answered questions (0 if none).
  double get meanRating {
    if (ratings.isEmpty) return 0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'completedAt': completedAt.toIso8601String(),
        'ratings': ratings,
      };

  factory SmileyometerResult.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'] as List? ?? const [];
    return SmileyometerResult(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      ratings: rawRatings.map((e) => (e as int).clamp(1, 3)).toList(),
    );
  }
}

/// The Smileyometer questions and face scale.
class SmileyometerQuestions {
  const SmileyometerQuestions._();

  static const List<String> english = [
    'Did you have fun?',
    'Was the app easy to use?',
    'Do you want to use it again?',
  ];

  static const List<String> filipino = [
    'Nasiyahan ka ba?',
    'Madali bang gamitin ang app?',
    'Gusto mo bang gamitin ulit?',
  ];

  /// Faces for the 3-point scale, ordered 1 → 3 (sad / okay / happy).
  static const List<String> faces = ['😞', '🙂', '😄'];

  static const List<String> faceLabelsEnglish = ['Not really', 'Okay', 'Yes!'];

  static const List<String> faceLabelsFilipino = ['Hindi masyado', 'Okay', 'Oo!'];
}
