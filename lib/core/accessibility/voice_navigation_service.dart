import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/parent/models/educator_audience.dart';
import '../../providers/app_providers.dart';
import '../../providers/parent_provider.dart';
import 'tts_service.dart';

/// Service that provides voice-guided navigation for visually impaired users.
///
/// Announces screen transitions, button interactions, and widget focus
/// using TTS. Queue-based: new announcements cancel previous ones.
class VoiceNavigationService {
  final TtsService _tts;
  bool _enabled = false;
  String _currentLocale = 'en';

  /// Whose roster the listener owns, for the educator route descriptions.
  ///
  /// Announcements are the one place a Visual-Impairment educator learns what
  /// a screen is, so a Parent hearing "All Students" is the same defect as
  /// reading it — they just cannot see it to report it. Set from
  /// [educatorAudienceProvider] alongside locale and enabled state; defaults to
  /// teacher, which is what these strings have always said.
  EducatorAudience _audience = EducatorAudience.teacher;

  VoiceNavigationService(this._tts);

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  void setLocale(String locale) {
    _currentLocale = locale;
  }

  void setAudience(EducatorAudience audience) {
    _audience = audience;
  }

  /// [describeRoute] for the profile that is actually listening.
  ///
  /// Prefer this over the static from anywhere that holds the service: the
  /// static defaults to the teacher wording, so calling it directly is how a
  /// Parent ends up being told they are looking at "All Students".
  ///
  /// Locale is forwarded as well: the route tables carry both languages side
  /// by side, so a Filipino listener gets a real description rather than the
  /// generic "Pahina" fallback.
  ({String name, String description}) describeRouteForViewer(String path) =>
      describeRoute(path, locale: _currentLocale, audience: _audience);

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
    // Debug builds log what was spoken. The device cannot be asked what it
    // said — a phone mic does not pick up its own speaker, and TTS engines log
    // utterance ids rather than text — so this line is the only way to verify
    // announcements on hardware. Matches the existing `VoiceCmd` / `SttService`
    // debug logging.
    if (kDebugMode) debugPrint('VoiceNav speak [$_currentLocale]: $text');
    if (_currentLocale == 'fil') {
      await _tts.speakFilipino(text);
    } else {
      await _tts.speakEnglish(text);
    }
  }

  /// Map a route path to a spoken screen name and description.
  ///
  /// [path] is the matched route *pattern* (`/child-alarms/:profileId`), which
  /// is what [VoiceRouteAnnouncer.locationOf] hands over. Anything not in the
  /// tables returns an empty description, and the announcer stays silent on it
  /// rather than reading out the bare word "Page".
  static ({String name, String description}) describeRoute(
    String path, {
    String locale = 'en',
    EducatorAudience audience = EducatorAudience.teacher,
  }) {
    final cleanPath = path.split('?').first;
    final entry = _audienceCopy(cleanPath, audience) ?? _routeCopy[cleanPath];
    if (entry == null) {
      return locale == 'fil'
          ? (name: 'Pahina', description: '')
          : (name: 'Page', description: '');
    }
    return locale == 'fil' ? entry.fil : entry.en;
  }

  /// Every route with a spoken description, for the coverage test.
  @visibleForTesting
  static Set<String> get describedRoutes => {
    ..._routeCopy.keys,
    ..._audienceOnlyRoutes,
  };

  /// Routes whose wording depends on who is reading.
  ///
  /// Kept apart from [_routeCopy] because they cannot be `const`: the learner
  /// noun comes from [EducatorAudience], which is the whole point — a Parent
  /// must never be told about "your students".
  static const Set<String> _audienceOnlyRoutes = {
    '/assessment/assign',
    '/child-alarms/:profileId',
    '/child-time-limits/:profileId',
    '/classroom',
    '/multi-dashboard',
    '/parent-teacher-notes',
    '/parent-teacher-notes/:profileId',
    '/progress-timeline/:profileId',
    '/assessment/portfolio/:profileId',
    '/routine-manage/:profileId',
    '/student-comparison',
    '/student-profile-detail',
    '/student-profiles',
    '/teacher-analytics',
    '/weekly-reports',
  };

  static ({({String name, String description}) en, ({String name, String description}) fil})?
  _audienceCopy(String path, EducatorAudience a) {
    // Nouns come from the audience rather than being spelled out per route, so
    // these cannot drift from what the screens themselves render.
    final learners = a.learnerNounPlural;
    final learner = a.learnerNoun;
    final learnersFil = a.learnerNounPluralOf(filipino: true);
    final learnerFil = a.learnerNounOf(filipino: true);

    return switch (path) {
      '/multi-dashboard' => (
        en: (
          name: a.allLearnersTitle,
          description: 'View progress for all your $learners.',
        ),
        fil: (
          name: a.allLearnersTitleOf(filipino: true),
          description: 'Tingnan ang progreso ng lahat ng iyong $learnersFil.',
        ),
      ),
      '/teacher-analytics' => (
        en: (
          name: a.analyticsTitle(filipino: false),
          description:
              'Accuracy, words learned, and a ranked list of your $learners.',
        ),
        fil: (
          name: a.analyticsTitle(filipino: true),
          description:
              'Katumpakan, mga natutunang salita, at ranking ng iyong '
              '$learnersFil.',
        ),
      ),
      '/weekly-reports' => (
        en: (
          name: 'Weekly Reports',
          description:
              'Generate and share weekly progress reports as PDF for each '
              '$learner.',
        ),
        fil: (
          name: 'Lingguhang Ulat',
          description:
              'Gumawa at ibahagi ang lingguhang ulat ng progreso bilang PDF '
              'para sa bawat $learnerFil.',
        ),
      ),
      '/classroom' => (
        en: (
          name: 'Classroom',
          description: 'Monitor your $learners during a live session.',
        ),
        fil: (
          name: 'Silid-aralan',
          description:
              'Subaybayan ang iyong $learnersFil sa isang live na sesyon.',
        ),
      ),
      '/student-comparison' => (
        en: (
          name: a.compareTitle(filipino: false),
          description: 'Put two or three $learners side by side.',
        ),
        fil: (
          name: a.compareTitle(filipino: true),
          description: 'Ihambing ang dalawa o tatlong $learnerFil.',
        ),
      ),
      '/student-profiles' => (
        en: (
          name: a.allLearnersTitle,
          description: 'Every $learner profile on this device.',
        ),
        fil: (
          name: a.allLearnersTitleOf(filipino: true),
          description: 'Lahat ng profile ng $learnerFil sa device na ito.',
        ),
      ),
      '/student-profile-detail' => (
        en: (
          name: '${a.learnerNounPluralCap.substring(0, a.learnerNounPluralCap.length - 1)} Profile',
          description: 'Details and progress for one $learner.',
        ),
        fil: (
          name: 'Profile ng $learnerFil',
          description: 'Mga detalye at progreso ng isang $learnerFil.',
        ),
      ),
      '/progress-timeline/:profileId' => (
        en: (
          name: 'Progress Timeline',
          description: 'Day-by-day history for one $learner.',
        ),
        fil: (
          name: 'Timeline ng Progreso',
          description: 'Araw-araw na kasaysayan ng isang $learnerFil.',
        ),
      ),
      '/assessment/portfolio/:profileId' => (
        en: (
          name: 'Portfolio',
          description:
              'Tests, video answers and feedback for one $learner, with a '
              'PDF for the family.',
        ),
        fil: (
          name: 'Portpolyo',
          description:
              'Mga pagsusulit, sagot sa video at puna ng isang $learnerFil, '
              'may PDF para sa pamilya.',
        ),
      ),
      '/child-alarms/:profileId' => (
        en: (
          name: 'Alarms',
          description: 'Set study reminders for this $learner.',
        ),
        fil: (
          name: 'Mga Alarma',
          description:
              'Magtakda ng paalala sa pag-aaral para sa $learnerFil na ito.',
        ),
      ),
      '/routine-manage/:profileId' => (
        en: (
          name: 'Daily Routine',
          description: 'Build the daily routine this $learner follows.',
        ),
        fil: (
          name: 'Pang-araw-araw na Routine',
          description:
              'Gumawa ng pang-araw-araw na routine para sa $learnerFil na ito.',
        ),
      ),
      '/child-time-limits/:profileId' => (
        en: (
          name: 'Time Limits',
          description: 'Set daily screen time for this $learner.',
        ),
        fil: (
          name: 'Limitasyon sa Oras',
          description:
              'Magtakda ng pang-araw-araw na oras sa screen para sa '
              '$learnerFil na ito.',
        ),
      ),
      '/parent-teacher-notes' => (
        en: (
          name: a.notesTooltip,
          description: 'Notes shared between home and school.',
        ),
        fil: (
          name: a.isParent ? 'Tala ng Guro' : 'Tala ng Magulang',
          description: 'Mga talang pinagsasaluhan ng tahanan at paaralan.',
        ),
      ),
      '/parent-teacher-notes/:profileId' => (
        en: (
          name: a.notesTooltip,
          description: 'Notes about one $learner, shared between home and '
              'school.',
        ),
        fil: (
          name: a.isParent ? 'Tala ng Guro' : 'Tala ng Magulang',
          description:
              'Mga tala tungkol sa isang $learnerFil, pinagsasaluhan ng '
              'tahanan at paaralan.',
        ),
      ),
      '/assessment/assign' => (
        en: (
          name: 'Assign Tasks',
          description: 'Send an assessment to your $learners.',
        ),
        fil: (
          name: 'Magbigay ng Gawain',
          description: 'Magpadala ng pagsusulit sa iyong $learnersFil.',
        ),
      ),
      _ => null,
    };
  }

  /// Every other screen, both languages side by side.
  ///
  /// One entry per route with `en` and `fil` together, so a new screen cannot
  /// be added in English only — which is how the Filipino map came to cover 6
  /// routes out of 18. `test/voice_route_coverage_test.dart` walks the real
  /// router and fails if anything here goes stale or missing.
  static const Map<
    String,
    ({({String name, String description}) en, ({String name, String description}) fil})
  >
  _routeCopy = {
    '/accessibility-setup': (
      en: (
        name: 'Accessibility Setup',
        description: 'Choose the accessibility settings that suit you.',
      ),
      fil: (
        name: 'Pagsasaayos ng Accessibility',
        description: 'Piliin ang mga setting ng accessibility na bagay sa iyo.',
      ),
    ),
    '/adaptive-analytics': (
      en: (
        name: 'Adaptive Analytics',
        description:
            'Advanced charts, including the spaced repetition heatmap and '
            'difficulty history.',
      ),
      fil: (
        name: 'Adaptive Analytics',
        description:
            'Mga detalyadong tsart, kasama ang heatmap ng spaced repetition at '
            'ang kasaysayan ng antas ng hirap.',
      ),
    ),
    '/ai-tutor': (
      en: (
        name: 'AI Tutor',
        description: 'Ask the tutor for help and practise in a conversation.',
      ),
      fil: (
        name: 'AI Tutor',
        description:
            'Humingi ng tulong sa tutor at magsanay sa pamamagitan ng usapan.',
      ),
    ),
    '/alert-settings': (
      en: (
        name: 'Alert Settings',
        description: 'Choose which progress alerts you receive.',
      ),
      fil: (
        name: 'Mga Setting ng Alerto',
        description: 'Piliin kung anong mga alerto sa progreso ang matatanggap mo.',
      ),
    ),
    '/analytics': (
      en: (
        name: 'Analytics',
        description:
            'Charts of your accuracy, study time, and progress per category.',
      ),
      fil: (
        name: 'Analytics',
        description:
            'Mga tsart ng iyong katumpakan, oras ng pag-aaral, at progreso '
            'bawat kategorya.',
      ),
    ),
    '/assessment': (
      en: (
        name: 'Assessments',
        description: 'Take or review an assessment.',
      ),
      fil: (
        name: 'Mga Pagsusulit',
        description: 'Sagutan o balikan ang isang pagsusulit.',
      ),
    ),
    '/assessment/class-report': (
      en: (
        name: 'Class Report',
        description:
            'Learning gain by accessibility category, the hardest questions, '
            'and who has retaken which test.',
      ),
      fil: (
        name: 'Ulat ng Klase',
        description:
            'Pag-unlad ayon sa uri ng accessibility, ang pinakamahihirap na '
            'tanong, at kung sino ang umulit ng pagsusulit.',
      ),
    ),
    '/assessment/builder': (
      en: (
        name: 'Assessment Builder',
        description: 'Build an assessment from your own questions.',
      ),
      fil: (
        name: 'Paggawa ng Pagsusulit',
        description: 'Gumawa ng pagsusulit mula sa sarili mong mga tanong.',
      ),
    ),
    '/assessment/category/:categoryIndex': (
      en: (
        name: 'Category Assessment',
        description: 'Answer questions from one vocabulary category.',
      ),
      fil: (
        name: 'Pagsusulit sa Kategorya',
        description:
            'Sagutin ang mga tanong mula sa isang kategorya ng bokabularyo.',
      ),
    ),
    '/assessment/portfolio': (
      en: (
        name: 'My Portfolio',
        description: 'Your tests, your video answers and your feedback.',
      ),
      fil: (
        name: 'Aking Portpolyo',
        description:
            'Ang iyong mga pagsusulit, sagot sa video at puna.',
      ),
    ),
    '/assessment/results': (
      en: (
        name: 'Assessment Results',
        description: 'See how the assessment was answered.',
      ),
      fil: (
        name: 'Resulta ng Pagsusulit',
        description: 'Tingnan kung paano nasagutan ang pagsusulit.',
      ),
    ),
    '/assessment/summary': (
      en: (
        name: 'Assessment Summary',
        description: 'A summary of the assessment just finished.',
      ),
      fil: (
        name: 'Buod ng Pagsusulit',
        description: 'Buod ng katatapos na pagsusulit.',
      ),
    ),
    '/assessment/take/:id': (
      en: (
        name: 'Take Assessment',
        description: 'Answer the assessment questions one at a time.',
      ),
      fil: (
        name: 'Sagutan ang Pagsusulit',
        description: 'Sagutin ang mga tanong ng pagsusulit nang isa-isa.',
      ),
    ),
    '/assessment/tracking': (
      en: (
        name: 'Track Assessments',
        description: 'See which assigned assessments have been completed.',
      ),
      fil: (
        name: 'Pagsubaybay sa Pagsusulit',
        description: 'Tingnan kung aling mga ibinigay na pagsusulit ang tapos na.',
      ),
    ),
    '/backup': (
      en: (
        name: 'Backup and Restore',
        description: 'Back up or restore all app data.',
      ),
      fil: (
        name: 'Backup at Pagbalik',
        description: 'I-backup o ibalik ang lahat ng datos ng app.',
      ),
    ),
    '/backup-account': (
      en: (
        name: 'Backup Account',
        description:
            'Link an account so progress can be restored on another device.',
      ),
      fil: (
        name: 'Backup na Account',
        description:
            'Mag-link ng account para maibalik ang progreso sa ibang device.',
      ),
    ),
    '/certificates': (
      en: (
        name: 'Certificates',
        description: 'View and share the certificates earned.',
      ),
      fil: (
        name: 'Mga Sertipiko',
        description: 'Tingnan at ibahagi ang mga natamong sertipiko.',
      ),
    ),
    '/classroom-manage': (
      en: (
        name: 'Manage Classes',
        description: 'Create a class and share its join code.',
      ),
      fil: (
        name: 'Pamahalaan ang mga Klase',
        description: 'Gumawa ng klase at ibahagi ang join code nito.',
      ),
    ),
    '/communication-board': (
      en: (
        name: 'Talk Board',
        description: 'Tap pictures to speak words and phrases aloud.',
      ),
      fil: (
        name: 'Talk Board',
        description:
            'Mag-tap ng larawan para bigkasin ang mga salita at parirala.',
      ),
    ),
    '/communication-board/builder': (
      en: (
        name: 'Talk Board Builder',
        description: 'Add and arrange the tiles on the talk board.',
      ),
      fil: (
        name: 'Paggawa ng Talk Board',
        description: 'Magdagdag at ayusin ang mga tile sa talk board.',
      ),
    ),
    // The learner's own day. Described in the second person because this is
    // the one routine surface a learner opens for themselves.
    '/routine': (
      en: (
        name: 'My Day',
        description:
            'Your daily routine, step by step, with pictures and sounds.',
      ),
      fil: (
        name: 'Ang Aking Araw',
        description:
            'Ang iyong pang-araw-araw na routine, hakbang-hakbang, na may '
            'larawan at tunog.',
      ),
    ),
    '/create-flashcard-enhanced': (
      en: (
        name: 'Enhanced Flashcard Creator',
        description:
            'Create a flashcard with image, voice dictation, and a live '
            'preview.',
      ),
      fil: (
        name: 'Paggawa ng Flashcard',
        description:
            'Gumawa ng flashcard na may larawan, boses, at live na preview.',
      ),
    ),
    '/daily-challenge': (
      en: (
        name: 'Daily Challenge',
        description: 'Today’s challenge. Answer it to keep your streak.',
      ),
      fil: (
        name: 'Hamon ng Araw',
        description:
            'Ang hamon ngayong araw. Sagutin para mapanatili ang iyong streak.',
      ),
    ),
    '/dashboard': (
      en: (
        name: 'Dashboard',
        description: 'A detailed progress report for one learner.',
      ),
      fil: (
        name: 'Dashboard',
        description: 'Detalyadong ulat ng progreso ng isang mag-aaral.',
      ),
    ),
    '/edit-profile': (
      en: (
        name: 'Edit Profile',
        description: 'Change the name, avatar, and details of this profile.',
      ),
      fil: (
        name: 'I-edit ang Profile',
        description:
            'Baguhin ang pangalan, avatar, at mga detalye ng profile na ito.',
      ),
    ),
    '/experiment-setup': (
      en: (
        name: 'Experiment Setup',
        description: 'Set up the research experiment groups.',
      ),
      fil: (
        name: 'Setup ng Eksperimento',
        description: 'Ihanda ang mga grupo para sa pananaliksik.',
      ),
    ),
    '/flashcards': (
      en: (
        name: 'Flashcard Decks',
        description: 'Choose a vocabulary category to study.',
      ),
      fil: (
        name: 'Mga Flashcard',
        description: 'Pumili ng kategorya ng bokabularyo na pag-aaralan.',
      ),
    ),
    '/flashcards/create': (
      en: (
        name: 'Create Flashcard',
        description: 'Make your own flashcard.',
      ),
      fil: (
        name: 'Gumawa ng Flashcard',
        description: 'Gumawa ng sarili mong flashcard.',
      ),
    ),
    '/flashcards/templates': (
      en: (
        name: 'Card Templates',
        description: 'Start from a ready-made card template.',
      ),
      fil: (
        name: 'Mga Template ng Kard',
        description: 'Magsimula sa isang handang template ng kard.',
      ),
    ),
    '/flashcards/viewer/:category': (
      en: (
        name: 'Flashcard Viewer',
        description: 'Viewing flashcards. Swipe or tap to move between cards.',
      ),
      fil: (
        name: 'Pagtingin ng Flashcard',
        description:
            'Tinitingnan ang mga flashcard. Mag-swipe o mag-tap para lumipat.',
      ),
    ),
    '/focus-mode': (
      en: (
        name: 'Focus Mode',
        description: 'A calm practice screen with nothing else on it.',
      ),
      fil: (
        name: 'Focus Mode',
        description: 'Tahimik na screen ng pagsasanay na walang ibang laman.',
      ),
    ),
    '/fsl-dictionary': (
      en: (
        name: 'FSL Dictionary',
        description: 'Browse Filipino Sign Language signs by word.',
      ),
      fil: (
        name: 'Diksyunaryo ng FSL',
        description:
            'Tingnan ang mga senyas ng Filipino Sign Language ayon sa salita.',
      ),
    ),
    '/gamepad-practice': (
      en: (
        name: 'Controller Practice',
        description: 'Press any button to hear what it is.',
      ),
      fil: (
        name: 'Pagsasanay sa Controller',
        description: 'Pindutin ang alinmang button para marinig kung ano ito.',
      ),
    ),
    '/gamepad-settings': (
      en: (
        name: 'Controller Settings',
        description: 'Connect and set up a Bluetooth controller.',
      ),
      fil: (
        name: 'Mga Setting ng Controller',
        description: 'Ikonekta at ayusin ang Bluetooth controller.',
      ),
    ),
    '/games': (
      en: (
        name: 'Games',
        description: 'Pick a game to practise vocabulary.',
      ),
      fil: (
        name: 'Mga Laro',
        description: 'Pumili ng laro para magsanay sa bokabularyo.',
      ),
    ),
    '/games/drag-drop': (
      en: (
        name: 'Drag and Drop',
        description: 'Drag words to matching pictures.',
      ),
      fil: (
        name: 'I-drag at I-drop',
        description: 'Hilahin ang salita papunta sa tamang larawan.',
      ),
    ),
    '/games/first-letter': (
      en: (
        name: 'First Letter',
        description: 'Pick the letter each word starts with.',
      ),
      fil: (
        name: 'Unang Letra',
        description: 'Piliin ang unang letra ng bawat salita.',
      ),
    ),
    '/games/flashcard-quiz': (
      en: (
        name: 'Flashcard Quiz',
        description: 'Swipe cards to test your knowledge.',
      ),
      fil: (
        name: 'Flashcard Quiz',
        description: 'I-swipe ang mga kard para subukin ang iyong nalalaman.',
      ),
    ),
    '/games/fsl-practice': (
      en: (
        name: 'FSL Practice',
        description: 'Practise Filipino Sign Language. Choose a mode.',
      ),
      fil: (
        name: 'Pagsasanay sa FSL',
        description: 'Magsanay sa Filipino Sign Language. Pumili ng mode.',
      ),
    ),
    '/games/fsl-practice/sign-it': (
      en: (
        name: 'Sign It',
        description: 'Copy the sign with your own hands using the camera.',
      ),
      fil: (
        name: 'Senyas Mo',
        description: 'Gayahin ang senyas gamit ang iyong kamay at ang camera.',
      ),
    ),
    '/games/fsl-practice/sign-to-word': (
      en: (
        name: 'FSL Sign to Word',
        description: 'Watch a sign language video and pick the correct word.',
      ),
      fil: (
        name: 'FSL Senyas Papuntang Salita',
        description:
            'Panoorin ang video ng senyas at piliin ang tamang salita.',
      ),
    ),
    '/games/fsl-practice/word-to-sign': (
      en: (
        name: 'FSL Word to Sign',
        description: 'See a word and pick the correct sign language video.',
      ),
      fil: (
        name: 'FSL Salita Papuntang Senyas',
        description: 'Tingnan ang salita at piliin ang tamang video ng senyas.',
      ),
    ),
    '/games/jigsaw-puzzle': (
      en: (
        name: 'Jigsaw Puzzle',
        description: 'Drag the pieces to complete the picture.',
      ),
      fil: (
        name: 'Palaisipang Jigsaw',
        description: 'Hilahin ang mga piraso para mabuo ang larawan.',
      ),
    ),
    '/games/memory-match': (
      en: (
        name: 'Memory Match',
        description: 'Find matching pairs of cards.',
      ),
      fil: (
        name: 'Memory Match',
        description: 'Hanapin ang magkatugmang pares ng kard.',
      ),
    ),
    '/games/odd-one-out': (
      en: (
        name: 'Odd One Out',
        description: 'Pick the picture that does not belong.',
      ),
      fil: (
        name: 'Alin ang Iba',
        description: 'Piliin ang larawang hindi kabilang.',
      ),
    ),
    '/games/picture-word': (
      en: (
        name: 'Picture Word',
        description: 'Match the picture to the word that names it.',
      ),
      fil: (
        name: 'Larawan at Salita',
        description: 'Itapat ang larawan sa salitang tumutukoy dito.',
      ),
    ),
    '/games/pronunciation': (
      en: (
        name: 'Pronunciation Practice',
        description: 'Listen and pick the correct word.',
      ),
      fil: (
        name: 'Pagsasanay sa Bigkas',
        description: 'Makinig at piliin ang tamang salita.',
      ),
    ),
    '/games/sentence-builder': (
      en: (
        name: 'Sentence Builder',
        description: 'Fill in the missing word.',
      ),
      fil: (
        name: 'Sentence Builder',
        description: 'Punan ang nawawalang salita.',
      ),
    ),
    '/games/spelling-bee': (
      en: (
        name: 'Spelling Bee',
        description: 'Unscramble the letters to spell the word.',
      ),
      fil: (
        name: 'Spelling Bee',
        description: 'Ayusin ang mga letra para mabuo ang salita.',
      ),
    ),
    '/games/tracing': (
      en: (
        name: 'Letter Tracing',
        description: 'Trace the letters with your finger.',
      ),
      fil: (
        name: 'Pagbakat ng Letra',
        description: 'Bakatin ang mga letra gamit ang iyong daliri.',
      ),
    ),
    '/games/word-match': (
      en: (
        name: 'Word Match',
        description: 'Match pictures to words.',
      ),
      fil: (
        name: 'Pagtutugma ng Salita',
        description: 'Itapat ang larawan sa tamang salita.',
      ),
    ),
    '/games/yes-or-no': (
      en: (
        name: 'Yes or No',
        description: 'Answer yes or no about each picture.',
      ),
      fil: (
        name: 'Oo o Hindi',
        description: 'Sagutin ng oo o hindi ang tungkol sa bawat larawan.',
      ),
    ),
    '/gamification-dashboard': (
      en: (
        name: 'Rewards',
        description: 'Your level, badges, and stars.',
      ),
      fil: (
        name: 'Mga Gantimpala',
        description: 'Ang iyong level, mga badge, at bituin.',
      ),
    ),
    '/gaze-control': (
      en: (
        name: 'Gaze Control',
        description: 'Control the app by looking and blinking.',
      ),
      fil: (
        name: 'Kontrol gamit ang Tingin',
        description: 'Kontrolin ang app sa pamamagitan ng tingin at kurap.',
      ),
    ),
    '/gaze-calibrate': (
      en: (
        name: 'Resting Position',
        description: 'Sit the way you usually do and look at the dot.',
      ),
      fil: (
        name: 'Posisyon ng Pahinga',
        description: 'Umupo gaya ng dati at tumingin sa tuldok.',
      ),
    ),
    '/gaze-settings': (
      en: (
        name: 'Gaze Settings',
        description: 'Adjust how gaze control responds.',
      ),
      fil: (
        name: 'Mga Setting ng Gaze',
        description: 'Ayusin kung paano tumutugon ang gaze control.',
      ),
    ),
    '/goals': (
      en: (
        name: 'Goals',
        description: 'Set and track your learning goals.',
      ),
      fil: (
        name: 'Mga Layunin',
        description: 'Magtakda at subaybayan ang iyong mga layunin sa pag-aaral.',
      ),
    ),
    '/guided-practice': (
      en: (
        name: 'Guided Practice',
        description: 'Step-by-step practice with hints along the way.',
      ),
      fil: (
        name: 'Gabay na Pagsasanay',
        description: 'Sunod-sunod na pagsasanay na may mga pahiwatig.',
      ),
    ),
    '/hard-words': (
      en: (
        name: 'Hard Words',
        description: 'The words you get wrong most often.',
      ),
      fil: (
        name: 'Mahihirap na Salita',
        description: 'Ang mga salitang madalas mong mamali.',
      ),
    ),
    '/home': (
      en: (
        name: 'Home',
        description:
            'Home screen. Explore categories, the daily challenge, and quick '
            'games.',
      ),
      fil: (
        name: 'Home',
        description:
            'Pangunahing screen. Tuklasin ang mga kategorya, ang hamon ngayong '
            'araw, at ang mabilisang laro.',
      ),
    ),
    '/home-group-manage': (
      en: (
        name: 'Manage Home Groups',
        description:
            'Create a home group and share its code with your child’s device.',
      ),
      fil: (
        name: 'Pamahalaan ang Home Group',
        description:
            'Gumawa ng home group at ibahagi ang code nito sa device ng iyong '
            'anak.',
      ),
    ),
    '/join-class': (
      en: (
        name: 'Join a Class',
        description: 'Enter the class code your teacher gave you.',
      ),
      fil: (
        name: 'Sumali sa Klase',
        description: 'Ilagay ang class code na ibinigay ng iyong guro.',
      ),
    ),
    '/join-home-group': (
      en: (
        name: 'Join a Home Group',
        description: 'Enter the code from your parent’s device.',
      ),
      fil: (
        name: 'Sumali sa Home Group',
        description: 'Ilagay ang code mula sa device ng iyong magulang.',
      ),
    ),
    '/leaderboard': (
      en: (
        name: 'Leaderboard',
        description: 'See how everyone in your group is doing.',
      ),
      fil: (
        name: 'Leaderboard',
        description: 'Tingnan kung kumusta ang bawat isa sa inyong grupo.',
      ),
    ),
    '/leaderboard-config/:scopeId': (
      en: (
        name: 'Leaderboard Settings',
        description: 'Choose whether members can see the leaderboard.',
      ),
      fil: (
        name: 'Setting ng Leaderboard',
        description: 'Piliin kung makikita ng mga miyembro ang leaderboard.',
      ),
    ),
    '/learning-gain': (
      en: (
        name: 'Learning Gain',
        description:
            'Compare a baseline test with a later one to see the improvement.',
      ),
      fil: (
        name: 'Pag-unlad sa Pagkatuto',
        description:
            'Ihambing ang baseline test sa susunod para makita ang pag-unlad.',
      ),
    ),
    '/learning-path-viewer/:category': (
      en: (
        name: 'Learning Path',
        description: 'Work through this category step by step.',
      ),
      fil: (
        name: 'Landas ng Pagkatuto',
        description: 'Pag-aralan ang kategoryang ito nang sunod-sunod.',
      ),
    ),
    '/learning-paths': (
      en: (
        name: 'Learning Paths',
        description: 'Choose a guided path through the vocabulary.',
      ),
      fil: (
        name: 'Mga Landas ng Pagkatuto',
        description: 'Pumili ng gabay na landas sa bokabularyo.',
      ),
    ),
    '/learning-paths/:pathId': (
      en: (
        name: 'Learning Path',
        description: 'The lessons in this path.',
      ),
      fil: (
        name: 'Landas ng Pagkatuto',
        description: 'Ang mga aralin sa landas na ito.',
      ),
    ),
    '/learning-paths/:pathId/trail': (
      en: (
        name: 'Path Trail',
        description: 'Your journey through this path, lesson by lesson.',
      ),
      fil: (
        name: 'Daan ng Landas',
        description: 'Ang iyong paglalakbay sa landas na ito, aralin bawat aralin.',
      ),
    ),
    '/learning-world': (
      en: (
        name: 'Learning World',
        description: 'Explore the map and unlock new places.',
      ),
      fil: (
        name: 'Mundo ng Pagkatuto',
        description: 'Galugarin ang mapa at buksan ang mga bagong lugar.',
      ),
    ),
    '/live-session': (
      en: (
        name: 'Live Session',
        description: 'A live classroom session with your teacher.',
      ),
      fil: (
        name: 'Live na Sesyon',
        description: 'Live na sesyon sa klase kasama ang iyong guro.',
      ),
    ),
    '/manage-profiles': (
      en: (
        name: 'Manage Profiles',
        description: 'Remove profiles stored on this device.',
      ),
      fil: (
        name: 'Pamahalaan ang mga Profile',
        description: 'Alisin ang mga profile na nakaimbak sa device na ito.',
      ),
    ),
    '/membership-removed': (
      en: (
        name: 'Removed from Group',
        description: 'You are no longer a member of this group.',
      ),
      fil: (
        name: 'Inalis sa Grupo',
        description: 'Hindi ka na miyembro ng grupong ito.',
      ),
    ),
    '/messages': (
      en: (
        name: 'Messages',
        description: 'Read and reply to messages.',
      ),
      fil: (
        name: 'Mga Mensahe',
        description: 'Basahin at sagutin ang mga mensahe.',
      ),
    ),
    '/mood-check-in': (
      en: (
        name: 'Mood Check-in',
        description: 'Tell us how you are feeling today.',
      ),
      fil: (
        name: 'Check-in ng Damdamin',
        description: 'Sabihin kung ano ang nararamdaman mo ngayong araw.',
      ),
    ),
    '/mood-history': (
      en: (
        name: 'Mood History',
        description: 'How you have been feeling over the past days.',
      ),
      fil: (
        name: 'Kasaysayan ng Damdamin',
        description: 'Kung ano ang naramdaman mo sa mga nakaraang araw.',
      ),
    ),
    '/mood-insights': (
      en: (
        name: 'Mood Insights',
        description: 'Patterns in how you have been feeling.',
      ),
      fil: (
        name: 'Pagsusuri ng Damdamin',
        description: 'Mga pattern sa iyong mga nararamdaman.',
      ),
    ),
    '/multiplayer': (
      en: (
        name: 'Play Together',
        description: 'Play a game with someone else.',
      ),
      fil: (
        name: 'Maglaro nang Sabay',
        description: 'Maglaro ng laro kasama ang iba.',
      ),
    ),
    '/multiplayer-quiz': (
      en: (
        name: 'Multiplayer Quiz',
        description:
            'A two-player vocabulary quiz. Take turns answering questions.',
      ),
      fil: (
        name: 'Multiplayer Quiz',
        description:
            'Larong bokabularyo para sa dalawang manlalaro. Maghalinhinan sa '
            'pagsagot ng mga tanong.',
      ),
    ),
    '/notebook': (
      en: (
        name: 'Notebook',
        description: 'Your saved notes.',
      ),
      fil: (
        name: 'Kuwaderno',
        description: 'Ang iyong mga naitalang tala.',
      ),
    ),
    '/notebook/editor': (
      en: (
        name: 'Note Editor',
        description: 'Write or dictate a note.',
      ),
      fil: (
        name: 'Pagsulat ng Tala',
        description: 'Sumulat o magdikta ng tala.',
      ),
    ),
    '/object-scan': (
      en: (
        name: 'Word Hunt',
        description: 'Point the camera at real objects to find words.',
      ),
      fil: (
        name: 'Word Hunt',
        description:
            'Itutok ang camera sa mga totoong bagay para makahanap ng salita.',
      ),
    ),
    '/onboarding-tutorial': (
      en: (
        name: 'Tutorial',
        description: 'A short tour of how the app works.',
      ),
      fil: (
        name: 'Tutorial',
        description: 'Maikling gabay kung paano gamitin ang app.',
      ),
    ),
    '/parent-dashboard': (
      en: (
        name: 'Parent Dashboard',
        description:
            'Detailed progress, wellbeing, and recommendations for your '
            'children.',
      ),
      fil: (
        name: 'Dashboard ng Magulang',
        description:
            'Detalyadong progreso, kalagayan, at mga rekomendasyon para sa '
            'iyong mga anak.',
      ),
    ),
    '/parental-controls': (
      en: (
        name: 'Parental Controls',
        description: 'Limits and safety settings for this device.',
      ),
      fil: (
        name: 'Kontrol ng Magulang',
        description:
            'Mga limitasyon at setting ng kaligtasan para sa device na ito.',
      ),
    ),
    '/peer-collab': (
      en: (
        name: 'Work Together',
        description: 'Solve activities together with a partner.',
      ),
      fil: (
        name: 'Magtulungan',
        description: 'Sagutan ang mga gawain kasama ang iyong kapareha.',
      ),
    ),
    '/post-join-setup': (
      en: (
        name: 'Finish Setup',
        description: 'A few more details before you start.',
      ),
      fil: (
        name: 'Tapusin ang Setup',
        description: 'Ilang detalye pa bago ka magsimula.',
      ),
    ),
    '/profile': (
      en: (
        name: 'Profile Selection',
        description: 'Choose or create a profile.',
      ),
      fil: (
        name: 'Pagpili ng Profile',
        description: 'Pumili o gumawa ng profile.',
      ),
    ),
    '/profile-import-export': (
      en: (
        name: 'Import and Export',
        description: 'Move a profile to or from a file.',
      ),
      fil: (
        name: 'Import at Export',
        description: 'Ilipat ang profile papunta o mula sa isang file.',
      ),
    ),
    '/profile-switcher': (
      en: (
        name: 'Switch Profile',
        description: 'Choose which profile to use.',
      ),
      fil: (
        name: 'Palitan ang Profile',
        description: 'Piliin kung aling profile ang gagamitin.',
      ),
    ),
    '/progress': (
      en: (
        name: 'Progress',
        description: 'View your learning progress and achievements.',
      ),
      fil: (
        name: 'Progreso',
        description: 'Tingnan ang iyong progreso sa pag-aaral at mga tagumpay.',
      ),
    ),
    '/pwd-awareness': (
      en: (
        name: 'PWD Awareness',
        description: 'Learn about disability and inclusion.',
      ),
      fil: (
        name: 'Kamalayan sa PWD',
        description: 'Matuto tungkol sa kapansanan at pagtanggap.',
      ),
    ),
    '/quiz-builder': (
      en: (
        name: 'Quiz Builder',
        description: 'Build a quiz from your own questions.',
      ),
      fil: (
        name: 'Paggawa ng Quiz',
        description: 'Gumawa ng quiz mula sa sarili mong mga tanong.',
      ),
    ),
    '/recommendations': (
      en: (
        name: 'Recommendations',
        description: 'What to practise next.',
      ),
      fil: (
        name: 'Mga Rekomendasyon',
        description: 'Kung ano ang susunod na dapat pagsanayan.',
      ),
    ),
    '/recovery/redeem': (
      en: (
        name: 'Restore Profile',
        description: 'Enter a recovery code to restore a profile.',
      ),
      fil: (
        name: 'Ibalik ang Profile',
        description: 'Ilagay ang recovery code para maibalik ang profile.',
      ),
    ),
    '/recovery/show': (
      en: (
        name: 'Recovery Code',
        description: 'Save this code to restore the profile later.',
      ),
      fil: (
        name: 'Recovery Code',
        description: 'I-save ang code na ito para maibalik ang profile balang-araw.',
      ),
    ),
    '/reports/export': (
      en: (
        name: 'Export Report',
        description: 'Save or share a progress report.',
      ),
      fil: (
        name: 'I-export ang Ulat',
        description: 'I-save o ibahagi ang ulat ng progreso.',
      ),
    ),
    '/research-export': (
      en: (
        name: 'Research Export',
        description: 'Export anonymised study data for research.',
      ),
      fil: (
        name: 'Pag-export ng Datos ng Pananaliksik',
        description: 'I-export ang anonymised na datos para sa pananaliksik.',
      ),
    ),
    '/role-setup/:role': (
      en: (
        name: 'Profile Setup',
        description: 'Set up the new profile.',
      ),
      fil: (
        name: 'Setup ng Profile',
        description: 'Ihanda ang bagong profile.',
      ),
    ),
    '/settings': (
      en: (
        name: 'Settings',
        description: 'Adjust accessibility, audio, and app settings.',
      ),
      fil: (
        name: 'Mga Setting',
        description: 'Baguhin ang accessibility, tunog, at mga setting ng app.',
      ),
    ),
    '/shop': (
      en: (
        name: 'Star Shop',
        description: 'Spend stars on avatars, themes, and borders.',
      ),
      fil: (
        name: 'Tindahan ng Bituin',
        description: 'Gastusin ang mga bituin sa avatar, tema, at border.',
      ),
    ),
    '/showcase': (
      en: (
        name: 'Showcase',
        description: 'Your finished work.',
      ),
      fil: (
        name: 'Aking Portfolio',
        description: 'Ang mga natapos mong gawa.',
      ),
    ),
    '/showcase/detail': (
      en: (
        name: 'Showcase Item',
        description: 'A closer look at this piece of work.',
      ),
      fil: (
        name: 'Detalye ng Showcase',
        description: 'Mas malapitang tingin sa gawang ito.',
      ),
    ),
    '/showcase/share': (
      en: (
        name: 'Share Work',
        description: 'Share this work with someone.',
      ),
      fil: (
        name: 'Ibahagi ang Gawa',
        description: 'Ibahagi ang gawang ito sa iba.',
      ),
    ),
    '/smart-review': (
      en: (
        name: 'Smart Review',
        description: 'Review the words you need to practise.',
      ),
      fil: (
        name: 'Smart Review',
        description: 'Balikan ang mga salitang kailangan mong pagsanayan.',
      ),
    ),
    '/smileyometer': (
      en: (
        name: 'Smileyometer',
        description: 'Tap the face that shows how the activity felt.',
      ),
      fil: (
        name: 'Smileyometer',
        description: 'Piliin ang mukhang tumutugma sa naramdaman mo sa gawain.',
      ),
    ),
    '/sticker-album': (
      en: (
        name: 'Sticker Album',
        description: 'The stickers you have collected.',
      ),
      fil: (
        name: 'Album ng Sticker',
        description: 'Ang mga sticker na naipon mo.',
      ),
    ),
    '/stories': (
      en: (
        name: 'Stories',
        description: 'Read stories and answer questions about them.',
      ),
      fil: (
        name: 'Mga Kwento',
        description: 'Basahin ang mga kwento at sagutin ang mga tanong tungkol dito.',
      ),
    ),
    '/stories/quiz/:storyId': (
      en: (
        name: 'Story Quiz',
        description: 'Answer questions about the story.',
      ),
      fil: (
        name: 'Pagsusulit sa Kwento',
        description: 'Sagutin ang mga tanong tungkol sa kwento.',
      ),
    ),
    '/stories/read/:storyId': (
      en: (
        name: 'Story Reader',
        description: 'Reading a story. Tap to hear the sentences aloud.',
      ),
      fil: (
        name: 'Pagbabasa ng Kwento',
        description:
            'Binabasa ang kwento. Mag-tap para marinig ang bawat pangungusap.',
      ),
    ),
    '/streak-calendar': (
      en: (
        name: 'Streak Calendar',
        description: 'The days you have practised.',
      ),
      fil: (
        name: 'Kalendaryo ng Streak',
        description: 'Ang mga araw na nagsanay ka.',
      ),
    ),
    '/survey-results': (
      en: (
        name: 'Survey Results',
        description: 'Responses from the usability survey.',
      ),
      fil: (
        name: 'Resulta ng Survey',
        description: 'Mga sagot mula sa usability survey.',
      ),
    ),
    '/sus-survey': (
      en: (
        name: 'Usability Survey',
        description: 'Ten questions about using the app.',
      ),
      fil: (
        name: 'Sarbey ng Kakayahang-gamit',
        description: 'Sampung tanong tungkol sa paggamit ng app.',
      ),
    ),
    '/teacher-dashboard': (
      en: (
        name: 'Teacher Dashboard',
        description:
            'Detailed progress, wellbeing, and recommendations for your '
            'students.',
      ),
      fil: (
        name: 'Dashboard ng Guro',
        description:
            'Detalyadong progreso, kalagayan, at mga rekomendasyon para sa '
            'iyong mga estudyante.',
      ),
    ),
    '/time-up-lock': (
      en: (
        name: 'Time’s Up',
        description: 'Screen time is finished for today.',
      ),
      fil: (
        name: 'Tapos na ang Oras',
        description: 'Tapos na ang oras sa screen para ngayong araw.',
      ),
    ),
    '/routine-lock': (
      en: (
        name: 'Routine Time',
        description:
            'It is time for one step of your day. Finish it to carry on.',
      ),
      fil: (
        name: 'Oras ng Routine',
        description:
            'Oras na para sa isang hakbang ng araw mo. Tapusin ito para '
            'makapagpatuloy.',
      ),
    ),
    '/tv-cast': (
      en: (
        name: 'TV Cast',
        description: 'Show progress on a nearby TV or browser.',
      ),
      fil: (
        name: 'TV Cast',
        description: 'Ipakita ang progreso sa TV o browser na malapit.',
      ),
    ),
    '/voice-guided': (
      en: (
        name: 'Voice-Guided Mode',
        description:
            'Set up voice navigation and take a guided tour of the app.',
      ),
      fil: (
        name: 'Mode na Ginagabayan ng Boses',
        description:
            'Ayusin ang voice navigation at subukan ang gabay sa paggamit ng '
            'app.',
      ),
    ),
    '/welcome': (
      en: (
        name: 'Welcome',
        description: 'Welcome to FlashLearn. Choose how to begin.',
      ),
      fil: (
        name: 'Maligayang Pagdating',
        description: 'Maligayang pagdating sa FlashLearn. Piliin kung paano magsisimula.',
      ),
    ),
    '/word-hunt-collection': (
      en: (
        name: 'Word Hunt Collection',
        description: 'The real-world words you have found.',
      ),
      fil: (
        name: 'Koleksyon ng Word Hunt',
        description: 'Ang mga salitang nakita mo sa totoong mundo.',
      ),
    ),
    '/word-of-day': (
      en: (
        name: 'Word of the Day',
        description: 'Today’s word, with its picture and sound.',
      ),
      fil: (
        name: 'Salita ng Araw',
        description: 'Ang salita ngayong araw, kasama ang larawan at tunog nito.',
      ),
    ),
    '/worksheets': (
      en: (
        name: 'Worksheets',
        description: 'Create printable worksheets for practice.',
      ),
      fil: (
        name: 'Mga Worksheet',
        description: 'Gumawa ng napi-print na worksheet para sa pagsasanay.',
      ),
    ),
  };
}

/// Provider for [VoiceNavigationService].
final voiceNavigationProvider = Provider<VoiceNavigationService>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final settings = ref.watch(settingsProvider);
  final service = VoiceNavigationService(tts);
  service.setEnabled(settings.voiceNavigation);
  service.setLocale(settings.locale);
  service.setAudience(ref.watch(educatorAudienceProvider));
  return service;
});
