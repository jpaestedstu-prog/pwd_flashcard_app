import '../../../data/models/models.dart';

/// A raw label emitted by the on-device image labeler.
class RecognizedLabel {
  final String label;
  final double confidence;

  const RecognizedLabel({required this.label, required this.confidence});
}

/// A recognized label resolved to a vocabulary flashcard.
class WordMatch {
  final Flashcard card;

  /// The raw labeler output that produced this match (e.g. "Mobile phone").
  final String sourceLabel;
  final double confidence;

  const WordMatch({
    required this.card,
    required this.sourceLabel,
    required this.confidence,
  });
}
