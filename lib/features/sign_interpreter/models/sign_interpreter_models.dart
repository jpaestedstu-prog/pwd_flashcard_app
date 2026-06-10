import '../../../core/services/fsl_assets_service.dart';

/// One item of a glossed sentence, in spoken order. Either a vocabulary word
/// matched to a manifest entry (playable) or an unmatched word shown as a
/// text placeholder during playback.
class SignPlayItem {
  /// The word as it will be displayed — the manifest's English label for
  /// matched items, the spoken token for unmatched ones.
  final String word;

  /// Matched manifest entry, or null when the vocabulary has no sign for
  /// this word yet.
  final FslManifestEntry? entry;

  const SignPlayItem.matched(this.entry) : word = '';
  const SignPlayItem.unmatched(this.word) : entry = null;

  bool get isMatched => entry != null;

  String get displayEnglish => entry?.wordEnglish ?? word;
  String get displayFilipino => entry?.wordFilipino ?? '';
}

/// One Speech→Sign session, logged for the research export
/// (`speech_to_sign_usage.csv`). Stored as JSON in the progress box.
class SignUsageEvent {
  final DateTime timestamp;

  /// STT locale ('en-US' / 'fil-PH'), or 'typed' input language hint.
  final String locale;

  /// How the sentence was entered: 'mic' or 'typed'.
  final String source;

  final int tokenCount;
  final int matchedCount;
  final List<String> unmatchedWords;
  final int durationMs;

  const SignUsageEvent({
    required this.timestamp,
    required this.locale,
    required this.source,
    required this.tokenCount,
    required this.matchedCount,
    required this.unmatchedWords,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'locale': locale,
        'source': source,
        'tokenCount': tokenCount,
        'matchedCount': matchedCount,
        'unmatchedWords': unmatchedWords,
        'durationMs': durationMs,
      };

  factory SignUsageEvent.fromJson(Map<String, dynamic> json) => SignUsageEvent(
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                DateTime.now(),
        locale: json['locale'] as String? ?? 'en-US',
        source: json['source'] as String? ?? 'mic',
        tokenCount: (json['tokenCount'] as num?)?.toInt() ?? 0,
        matchedCount: (json['matchedCount'] as num?)?.toInt() ?? 0,
        unmatchedWords: List<String>.from(
          (json['unmatchedWords'] as List?) ?? const [],
        ),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      );
}
