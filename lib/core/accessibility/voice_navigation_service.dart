import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'tts_service.dart';

/// Service that provides voice-guided navigation for visually impaired users.
///
/// Announces screen transitions, button interactions, and widget focus
/// using TTS. Queue-based: new announcements cancel previous ones.
class VoiceNavigationService {
  final TtsService _tts;
  bool _enabled = false;
  String _currentLocale = 'en';

  VoiceNavigationService(this._tts);

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  void setLocale(String locale) {
    _currentLocale = locale;
  }

  /// Announce a screen transition.
  Future<void> announceScreen(String screenName, {String? description}) async {
    if (!_enabled) return;
    final text = description != null
        ? '$screenName. $description'
        : screenName;
    await _speak(text);
  }

  /// Announce a user action (button press, card flip, etc.).
  Future<void> announceAction(String action) async {
    if (!_enabled) return;
    await _speak(action);
  }

  /// Announce a widget focus change.
  Future<void> announceWidget(String label) async {
    if (!_enabled) return;
    await _speak(label);
  }

  /// Announce a game event (correct answer, wrong answer, score, etc.).
  Future<void> announceGameEvent(String event) async {
    if (!_enabled) return;
    await _speak(event);
  }

  Future<void> _speak(String text) async {
    if (_currentLocale == 'fil') {
      await _tts.speakFilipino(text);
    } else {
      await _tts.speakEnglish(text);
    }
  }

  /// Map route paths to human-readable screen descriptions.
  static ({String name, String description}) describeRoute(
    String path, {
    String locale = 'en',
  }) {
    if (locale == 'fil') {
      return _describeRouteFil(path);
    }
    return _describeRouteEn(path);
  }

  static ({String name, String description}) _describeRouteEn(String path) {
    // Strip query parameters
    final cleanPath = path.split('?').first;

    return switch (cleanPath) {
      '/home' => (
        name: 'Home',
        description:
            'Home screen. Explore categories, daily challenge, and quick games.',
      ),
      '/flashcards' => (
        name: 'Flashcard Decks',
        description: 'Choose a vocabulary category to study.',
      ),
      '/games' => (
        name: 'Games',
        description: 'Pick a game to practice vocabulary.',
      ),
      '/progress' => (
        name: 'Progress',
        description: 'View your learning progress and achievements.',
      ),
      '/settings' => (
        name: 'Settings',
        description: 'Adjust accessibility, audio, and app settings.',
      ),
      '/dashboard' => (
        name: 'Dashboard',
        description: 'View detailed progress report.',
      ),
      '/shop' => (
        name: 'Star Shop',
        description: 'Spend stars on avatars, themes, and borders.',
      ),
      '/smart-review' => (
        name: 'Smart Review',
        description: 'Review words you need to practice.',
      ),
      '/stories' => (
        name: 'Stories',
        description: 'Read stories and answer comprehension questions.',
      ),
      '/multi-dashboard' => (
        name: 'All Students',
        description: 'View progress for all student profiles.',
      ),
      '/classroom' => (
        name: 'Classroom',
        description: 'Monitor students during a classroom session.',
      ),
      '/backup' => (
        name: 'Backup and Restore',
        description: 'Back up or restore all app data.',
      ),
      '/profile' => (
        name: 'Profile Selection',
        description: 'Choose or create a profile.',
      ),
      '/weekly-reports' => (
        name: 'Weekly Reports',
        description:
            'Generate and share weekly progress reports as PDF for each child.',
      ),
      '/adaptive-analytics' => (
        name: 'Adaptive Analytics',
        description:
            'View advanced charts including spaced repetition heatmap and difficulty history.',
      ),
      '/multiplayer-quiz' => (
        name: 'Multiplayer Quiz',
        description:
            'A two-player vocabulary quiz game. Take turns answering questions.',
      ),
      '/voice-guided' => (
        name: 'Voice-Guided Mode',
        description:
            'Configure voice navigation settings and take a guided tour of the app.',
      ),
      '/create-flashcard-enhanced' => (
        name: 'Enhanced Flashcard Creator',
        description:
            'Create a flashcard with image, voice dictation, and a live preview.',
      ),
      _ => _describeGameRoute(cleanPath),
    };
  }

  static ({String name, String description}) _describeRouteFil(String path) {
    final cleanPath = path.split('?').first;

    return switch (cleanPath) {
      '/home' => (
        name: 'Home',
        description:
            'Home screen. Tingnan ang mga kategorya, araw-araw na hamon, at mabilisang laro.',
      ),
      '/flashcards' => (
        name: 'Mga Flashcard',
        description: 'Pumili ng kategorya ng bokabularyo para pag-aralan.',
      ),
      '/games' => (
        name: 'Mga Laro',
        description: 'Pumili ng laro para magsanay ng bokabularyo.',
      ),
      '/progress' => (
        name: 'Progreso',
        description: 'Tingnan ang progreso at mga achievement.',
      ),
      '/settings' => (
        name: 'Mga Setting',
        description: 'I-adjust ang accessibility, audio, at app settings.',
      ),
      '/stories' => (
        name: 'Mga Kwento',
        description: 'Basahin ang mga kwento at sagutin ang mga tanong.',
      ),
      _ => _describeGameRoute(cleanPath),
    };
  }

  static ({String name, String description}) _describeGameRoute(String path) {
    if (path.contains('word-match')) {
      return (name: 'Word Match', description: 'Match pictures to words.');
    }
    if (path.contains('spelling-bee')) {
      return (
        name: 'Spelling Bee',
        description: 'Unscramble letters to spell words.',
      );
    }
    if (path.contains('memory-match')) {
      return (
        name: 'Memory Match',
        description: 'Find matching pairs of cards.',
      );
    }
    if (path.contains('drag-drop')) {
      return (
        name: 'Drag and Drop',
        description: 'Drag words to matching pictures.',
      );
    }
    if (path.contains('flashcard-quiz')) {
      return (
        name: 'Flashcard Quiz',
        description: 'Swipe cards to test your knowledge.',
      );
    }
    if (path.contains('pronunciation')) {
      return (
        name: 'Pronunciation Practice',
        description: 'Listen and pick the correct word.',
      );
    }
    if (path.contains('sentence-builder')) {
      return (
        name: 'Sentence Builder',
        description: 'Fill in the missing word.',
      );
    }
    if (path.contains('fsl-practice/sign-to-word')) {
      return (
        name: 'FSL Sign to Word',
        description: 'Watch a sign language video and pick the correct word.',
      );
    }
    if (path.contains('fsl-practice/word-to-sign')) {
      return (
        name: 'FSL Word to Sign',
        description: 'See a word and pick the correct sign language video.',
      );
    }
    if (path.contains('fsl-practice')) {
      return (
        name: 'FSL Practice',
        description: 'Practice Filipino Sign Language. Choose a mode.',
      );
    }
    if (path.contains('viewer')) {
      return (
        name: 'Flashcard Viewer',
        description: 'Viewing flashcards. Swipe or tap to navigate.',
      );
    }
    if (path.contains('stories/read')) {
      return (
        name: 'Story Reader',
        description: 'Reading a story. Tap to hear sentences aloud.',
      );
    }
    if (path.contains('stories/quiz')) {
      return (
        name: 'Story Quiz',
        description: 'Answer questions about the story.',
      );
    }
    return (name: 'Page', description: '');
  }
}

/// Provider for [VoiceNavigationService].
final voiceNavigationProvider = Provider<VoiceNavigationService>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final settings = ref.watch(settingsProvider);
  final service = VoiceNavigationService(tts);
  service.setEnabled(settings.voiceNavigation);
  service.setLocale(settings.locale);
  return service;
});
