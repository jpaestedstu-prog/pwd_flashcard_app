/// SUS (System Usability Scale) survey models for thesis research data.
///
/// The SUS is a validated 10-question usability instrument (Brooke, 1996)
/// that produces a score from 0–100. Scores above 68 are considered
/// above-average usability.
library;

/// A single SUS survey response containing all 10 Likert-scale answers.
class SusSurveyResult {
  final String id;
  final String profileId;
  final DateTime completedAt;

  /// 10 responses, each 1–5 (Strongly Disagree to Strongly Agree).
  final List<int> responses;

  /// Optional free-text feedback.
  final String? feedback;

  const SusSurveyResult({
    required this.id,
    required this.profileId,
    required this.completedAt,
    required this.responses,
    this.feedback,
  });

  /// Calculate the SUS score (0–100).
  ///
  /// Odd-numbered questions (1,3,5,7,9): score contribution = response - 1
  /// Even-numbered questions (2,4,6,8,10): score contribution = 5 - response
  /// Total = sum of contributions × 2.5
  double get susScore {
    if (responses.length != 10) return 0;
    double sum = 0;
    for (int i = 0; i < 10; i++) {
      if (i.isEven) {
        // Odd questions (0-indexed even): positive phrasing
        sum += responses[i] - 1;
      } else {
        // Even questions (0-indexed odd): negative phrasing
        sum += 5 - responses[i];
      }
    }
    return sum * 2.5;
  }

  /// SUS grade label based on score.
  String get gradeLabel {
    final s = susScore;
    if (s >= 85) return 'Excellent';
    if (s >= 72) return 'Good';
    if (s >= 52) return 'OK';
    if (s >= 38) return 'Poor';
    return 'Awful';
  }

  String get gradeEmoji {
    final s = susScore;
    if (s >= 85) return '🌟';
    if (s >= 72) return '😊';
    if (s >= 52) return '🙂';
    if (s >= 38) return '😕';
    return '😟';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'completedAt': completedAt.toIso8601String(),
        'responses': responses,
        'feedback': feedback,
      };

  factory SusSurveyResult.fromJson(Map<String, dynamic> json) {
    final rawResponses = json['responses'] as List;
    return SusSurveyResult(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      responses: rawResponses
          .map((e) => (e as int).clamp(1, 5))
          .toList(),
      feedback: json['feedback'] as String?,
    );
  }

  SusSurveyResult copyWith({
    String? id,
    String? profileId,
    DateTime? completedAt,
    List<int>? responses,
    String? Function()? feedback,
  }) {
    return SusSurveyResult(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      completedAt: completedAt ?? this.completedAt,
      responses: responses ?? this.responses,
      feedback: feedback != null ? feedback() : this.feedback,
    );
  }
}

/// The standard 10 SUS questions.
class SusQuestions {
  const SusQuestions._();

  static const List<String> english = [
    'I think that I would like to use this app frequently.',
    'I found the app unnecessarily complex.',
    'I thought the app was easy to use.',
    'I think that I would need the support of a teacher to be able to use this app.',
    'I found the various functions in this app were well integrated.',
    'I thought there was too much inconsistency in this app.',
    'I would imagine that most students would learn to use this app very quickly.',
    'I found the app very awkward to use.',
    'I felt very confident using the app.',
    'I needed to learn a lot of things before I could get going with this app.',
  ];

  static const List<String> filipino = [
    'Sa tingin ko, gusto kong gamitin ang app na ito nang madalas.',
    'Nakita kong hindi kinakailangang kumplikado ang app.',
    'Sa tingin ko, madaling gamitin ang app.',
    'Sa tingin ko, kakailanganin ko ang tulong ng guro para magamit ang app na ito.',
    'Nakita ko na magkakaugnay ang iba\'t ibang bahagi ng app.',
    'Sa tingin ko, masyadong maraming hindi pare-pareho sa app na ito.',
    'Isipin ko na karamihan sa mga mag-aaral ay matututong gamitin ang app na ito nang mabilis.',
    'Nakita kong napakahirap gamitin ng app.',
    'Naging tiwala ako sa paggamit ng app.',
    'Kailangan kong matuto ng maraming bagay bago ko magamit ang app na ito.',
  ];

  /// Labels for the 5-point Likert scale.
  static const List<String> scaleLabelsEnglish = [
    'Strongly Disagree',
    'Disagree',
    'Neutral',
    'Agree',
    'Strongly Agree',
  ];

  static const List<String> scaleLabelsFilipino = [
    'Lubos na Hindi Sang-ayon',
    'Hindi Sang-ayon',
    'Neutral',
    'Sang-ayon',
    'Lubos na Sang-ayon',
  ];
}
