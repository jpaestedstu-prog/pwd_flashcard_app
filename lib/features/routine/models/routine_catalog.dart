import '../../../data/models/enums.dart';
import 'routine_models.dart';

/// A Filipino Sign Language cue for a routine step.
///
/// A routine activity is a *phrase* ("brushing teeth") and the FSL corpus is a
/// vocabulary of single words, so a step's sign content is a short **sequence**
/// of real signs rather than one invented clip. The UI is honest about that:
/// it labels the row "Signs for this step" and plays them one at a time.
///
/// [category] disambiguates the handful of English words that appear on two
/// seed cards — "Walk" is Transportation, not an action verb, and "Chicken" is
/// both an animal and a food. Without it the lookup silently picks whichever
/// card the seed list happens to yield first (see the seed-duplicate note in
/// the project's docs).
class FslSignCue {
  final String word;

  /// Null means "search every category" — used for the free-text sign word an
  /// educator types on a custom step, where no category is known.
  final FlashcardCategory? category;

  const FslSignCue(this.word, [this.category]);
}

/// Everything human-facing about one built-in [RoutineActivity].
///
/// Pure data, no Flutter: the whole catalog is unit-testable, and the
/// screens read fields instead of switching on the enum in a dozen places.
class RoutineActivityInfo {
  final RoutineActivity activity;

  final String emoji;

  final String label;
  final String labelFilipino;

  /// One-line description an educator reads while picking activities.
  final String blurb;
  final String blurbFilipino;

  /// Default clock time when this activity is added to a routine, as
  /// minutes-of-day. An educator can change it or drop the time entirely.
  final int defaultHour;
  final int defaultMinute;

  /// Default countdown length in minutes. Zero = no timer by default
  /// (school time and play time are open-ended; brushing teeth is not).
  final int defaultDurationMinutes;

  /// The visual, step-by-step instructions — the "visual instructions" the
  /// brief asked for, and the part of this feature that does the most work
  /// for a learner with a cognitive disability. Each entry is one small,
  /// concrete action with its own emoji, so the sequence can be rendered as
  /// pictures with words rather than as a paragraph.
  final List<RoutineInstruction> instructions;

  /// Real FSL clips that carry this activity's meaning, in signing order.
  /// Every word here is verified present in `assets/data/fsl_video_manifest.json`
  /// — a cue that resolves to nothing would give a Deaf learner a button that
  /// does not work, which is worse than no button.
  final List<FslSignCue> signCues;

  /// Short line the app speaks (TTS) when the step opens, for learners who
  /// rely on audio. Kept to one sentence: it is a cue, not a lecture.
  final String audioCue;
  final String audioCueFilipino;

  const RoutineActivityInfo({
    required this.activity,
    required this.emoji,
    required this.label,
    required this.labelFilipino,
    required this.blurb,
    required this.blurbFilipino,
    required this.defaultHour,
    required this.defaultMinute,
    this.defaultDurationMinutes = 0,
    this.instructions = const <RoutineInstruction>[],
    this.signCues = const <FslSignCue>[],
    required this.audioCue,
    required this.audioCueFilipino,
  });

  String labelOf({required bool filipino}) => filipino ? labelFilipino : label;
  String blurbOf({required bool filipino}) => filipino ? blurbFilipino : blurb;
  String audioCueOf({required bool filipino}) =>
      filipino ? audioCueFilipino : audioCue;
}

/// One line of a visual instruction sequence.
class RoutineInstruction {
  final String emoji;
  final String text;
  final String textFilipino;

  const RoutineInstruction(this.emoji, this.text, this.textFilipino);

  String textOf({required bool filipino}) => filipino ? textFilipino : text;
}

/// The built-in routine activities.
///
/// The list is the brief's, in the brief's order, which is also the order an
/// ordinary day runs in — so an educator building a morning routine finds the
/// morning activities first and does not have to hunt.
class RoutineCatalog {
  RoutineCatalog._();

  static const List<RoutineActivityInfo> all = [
    RoutineActivityInfo(
      activity: RoutineActivity.morningRoutine,
      emoji: '🌅',
      label: 'Morning Routine',
      labelFilipino: 'Gawain sa Umaga',
      blurb: 'Wake up and start the day',
      blurbFilipino: 'Gumising at simulan ang araw',
      defaultHour: 6,
      defaultMinute: 30,
      defaultDurationMinutes: 15,
      instructions: [
        RoutineInstruction('🛏️', 'Wake up and sit on the bed',
            'Gumising at umupo sa kama'),
        RoutineInstruction('🙆', 'Stretch your arms', 'Mag-unat ng mga braso'),
        RoutineInstruction('🪟', 'Open the curtains', 'Buksan ang kurtina'),
        RoutineInstruction('😊', 'Say good morning', 'Sabihin ang magandang umaga'),
      ],
      signCues: [
        FslSignCue('Good Morning', FlashcardCategory.familyAndGreetings),
        FslSignCue('Today', FlashcardCategory.daysAndTime),
      ],
      audioCue: 'Good morning! It is time to wake up.',
      audioCueFilipino: 'Magandang umaga! Oras na para gumising.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.brushingTeeth,
      emoji: '🪥',
      label: 'Brushing Teeth',
      labelFilipino: 'Pagsisipilyo',
      blurb: 'Clean your teeth, morning and night',
      blurbFilipino: 'Linisin ang ngipin, umaga at gabi',
      defaultHour: 6,
      defaultMinute: 45,
      defaultDurationMinutes: 2,
      instructions: [
        RoutineInstruction('🪥', 'Wet the toothbrush', 'Basain ang sipilyo'),
        RoutineInstruction('🧴', 'Put on toothpaste', 'Lagyan ng toothpaste'),
        RoutineInstruction('😁', 'Brush for two minutes',
            'Magsipilyo ng dalawang minuto'),
        RoutineInstruction('💧', 'Rinse with water', 'Magmumog ng tubig'),
      ],
      signCues: [
        FslSignCue('Teeth', FlashcardCategory.bodyParts),
        FslSignCue('Water', FlashcardCategory.foodAndDrinks),
      ],
      audioCue: 'Time to brush your teeth for two minutes.',
      audioCueFilipino: 'Oras na para magsipilyo ng dalawang minuto.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.breakfast,
      emoji: '🍳',
      label: 'Breakfast',
      labelFilipino: 'Almusal',
      blurb: 'The first meal of the day',
      blurbFilipino: 'Ang unang pagkain sa araw',
      defaultHour: 7,
      defaultMinute: 0,
      defaultDurationMinutes: 20,
      instructions: [
        RoutineInstruction('🧼', 'Wash your hands', 'Maghugas ng kamay'),
        RoutineInstruction('🪑', 'Sit at the table', 'Umupo sa mesa'),
        RoutineInstruction('🍽️', 'Eat your breakfast', 'Kainin ang almusal'),
        RoutineInstruction('🥛', 'Drink your milk or water',
            'Inumin ang gatas o tubig'),
      ],
      signCues: [
        FslSignCue('Morning', FlashcardCategory.daysAndTime),
        FslSignCue('Egg', FlashcardCategory.foodAndDrinks),
        FslSignCue('Milk', FlashcardCategory.foodAndDrinks),
      ],
      audioCue: 'Breakfast time. Wash your hands first.',
      audioCueFilipino: 'Oras ng almusal. Maghugas muna ng kamay.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.lunch,
      emoji: '🍚',
      label: 'Lunch',
      labelFilipino: 'Tanghalian',
      blurb: 'The midday meal',
      blurbFilipino: 'Ang pagkain sa tanghali',
      defaultHour: 12,
      defaultMinute: 0,
      defaultDurationMinutes: 30,
      instructions: [
        RoutineInstruction('🧼', 'Wash your hands', 'Maghugas ng kamay'),
        RoutineInstruction('🍚', 'Eat your lunch', 'Kainin ang tanghalian'),
        RoutineInstruction('💧', 'Drink water', 'Uminom ng tubig'),
        RoutineInstruction('🧽', 'Clear your plate', 'Ligpitin ang pinggan'),
      ],
      signCues: [
        FslSignCue('Afternoon', FlashcardCategory.daysAndTime),
        FslSignCue('Rice', FlashcardCategory.foodAndDrinks),
        FslSignCue('Water', FlashcardCategory.foodAndDrinks),
      ],
      audioCue: 'It is lunch time.',
      audioCueFilipino: 'Oras na ng tanghalian.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.breakTime,
      emoji: '☕',
      label: 'Break Time',
      labelFilipino: 'Oras ng Pahinga',
      blurb: 'A short rest between activities',
      blurbFilipino: 'Maikling pahinga sa pagitan ng gawain',
      defaultHour: 10,
      defaultMinute: 0,
      defaultDurationMinutes: 10,
      instructions: [
        RoutineInstruction('🛑', 'Stop what you are doing',
            'Itigil ang ginagawa'),
        RoutineInstruction('🧘', 'Take three slow breaths',
            'Huminga nang malalim ng tatlong beses'),
        RoutineInstruction('💧', 'Have a drink', 'Uminom ng tubig'),
      ],
      signCues: [
        FslSignCue('Clock', FlashcardCategory.daysAndTime),
        FslSignCue('Calm', FlashcardCategory.emotions),
      ],
      audioCue: 'Break time. Let us rest for a little while.',
      audioCueFilipino: 'Oras ng pahinga. Magpahinga muna tayo sandali.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.napTime,
      emoji: '😴',
      label: 'Nap Time',
      labelFilipino: 'Oras ng Idlip',
      blurb: 'A short daytime sleep',
      blurbFilipino: 'Maikling tulog sa araw',
      defaultHour: 13,
      defaultMinute: 0,
      defaultDurationMinutes: 45,
      instructions: [
        RoutineInstruction('🛏️', 'Lie down on the bed or mat',
            'Humiga sa kama o banig'),
        RoutineInstruction('🤫', 'Make the room quiet', 'Patahimikin ang kwarto'),
        RoutineInstruction('😴', 'Close your eyes and rest',
            'Ipikit ang mata at magpahinga'),
      ],
      signCues: [
        FslSignCue('Sleepy', FlashcardCategory.emotions),
        FslSignCue('Calm', FlashcardCategory.emotions),
      ],
      audioCue: 'Nap time. Time to rest quietly.',
      audioCueFilipino: 'Oras ng idlip. Oras na para magpahinga.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.dinner,
      emoji: '🍲',
      label: 'Dinner',
      labelFilipino: 'Hapunan',
      blurb: 'The evening meal',
      blurbFilipino: 'Ang pagkain sa gabi',
      defaultHour: 18,
      defaultMinute: 30,
      defaultDurationMinutes: 30,
      instructions: [
        RoutineInstruction('🧼', 'Wash your hands', 'Maghugas ng kamay'),
        RoutineInstruction('🍲', 'Eat your dinner', 'Kainin ang hapunan'),
        RoutineInstruction('🧽', 'Help clear the table',
            'Tumulong maglinis ng mesa'),
      ],
      signCues: [
        FslSignCue('Evening', FlashcardCategory.daysAndTime),
        FslSignCue('Rice', FlashcardCategory.foodAndDrinks),
        FslSignCue('Soup', FlashcardCategory.foodAndDrinks),
      ],
      audioCue: 'Dinner is ready.',
      audioCueFilipino: 'Handa na ang hapunan.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.bathTime,
      emoji: '🛁',
      label: 'Bath Time',
      labelFilipino: 'Oras ng Paliligo',
      blurb: 'Wash and get clean',
      blurbFilipino: 'Maligo at maglinis',
      defaultHour: 17,
      defaultMinute: 30,
      defaultDurationMinutes: 15,
      instructions: [
        RoutineInstruction('👕', 'Take off your clothes', 'Hubarin ang damit'),
        RoutineInstruction('🚿', 'Wet your body', 'Basain ang katawan'),
        RoutineInstruction('🧼', 'Use soap and rinse',
            'Gumamit ng sabon at banlawan'),
        RoutineInstruction('🧻', 'Dry with a towel', 'Magpunas ng tuwalya'),
      ],
      signCues: [
        FslSignCue('Water', FlashcardCategory.foodAndDrinks),
        FslSignCue('Hands', FlashcardCategory.bodyParts),
      ],
      audioCue: 'Bath time. Let us get clean.',
      audioCueFilipino: 'Oras ng paliligo. Maglinis tayo.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.gettingDressed,
      emoji: '👕',
      label: 'Getting Dressed',
      labelFilipino: 'Pagbibihis',
      blurb: 'Put on clothes for the day',
      blurbFilipino: 'Magsuot ng damit para sa araw',
      defaultHour: 7,
      defaultMinute: 30,
      defaultDurationMinutes: 10,
      instructions: [
        RoutineInstruction('👕', 'Put on your shirt', 'Isuot ang damit'),
        RoutineInstruction('👖', 'Put on your shorts or pants',
            'Isuot ang shorts o pantalon'),
        RoutineInstruction('🧦', 'Put on socks', 'Isuot ang medyas'),
        RoutineInstruction('👟', 'Put on your shoes', 'Isuot ang sapatos'),
      ],
      signCues: [
        FslSignCue('T-shirt', FlashcardCategory.clothing),
        FslSignCue('Shorts', FlashcardCategory.clothing),
        FslSignCue('Shoes', FlashcardCategory.clothing),
      ],
      audioCue: 'Time to get dressed.',
      audioCueFilipino: 'Oras na para magbihis.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.schoolTime,
      emoji: '🏫',
      label: 'School / Class Time',
      labelFilipino: 'Oras ng Klase',
      blurb: 'Go to class and learn',
      blurbFilipino: 'Pumasok sa klase at matuto',
      defaultHour: 8,
      defaultMinute: 0,
      instructions: [
        RoutineInstruction('🎒', 'Pack your bag', 'Ihanda ang bag'),
        RoutineInstruction('🚶', 'Go to your classroom', 'Pumunta sa silid-aralan'),
        RoutineInstruction('👋', 'Greet your teacher', 'Batiin ang guro'),
        RoutineInstruction('👂', 'Listen and join in', 'Makinig at sumali'),
      ],
      signCues: [
        FslSignCue('School', FlashcardCategory.classroom),
        FslSignCue('Teacher', FlashcardCategory.classroom),
        FslSignCue('Backpack', FlashcardCategory.clothing),
      ],
      audioCue: 'It is time for school.',
      audioCueFilipino: 'Oras na para pumasok sa klase.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.homework,
      emoji: '📚',
      label: 'Homework / Study Time',
      labelFilipino: 'Oras ng Takdang-Aralin',
      blurb: 'Study and finish assignments',
      blurbFilipino: 'Mag-aral at tapusin ang takdang-aralin',
      defaultHour: 16,
      defaultMinute: 0,
      defaultDurationMinutes: 30,
      instructions: [
        RoutineInstruction('🧹', 'Clear your desk', 'Linisin ang mesa'),
        RoutineInstruction('📓', 'Open your notebook', 'Buksan ang kwaderno'),
        RoutineInstruction('✏️', 'Do one task at a time',
            'Isa-isahin ang gawain'),
        RoutineInstruction('✅', 'Check your work', 'Suriin ang ginawa'),
      ],
      signCues: [
        FslSignCue('Notebook', FlashcardCategory.classroom),
        FslSignCue('Pencil', FlashcardCategory.classroom),
        FslSignCue('Book', FlashcardCategory.classroom),
      ],
      audioCue: 'Study time. Let us start with one task.',
      audioCueFilipino: 'Oras ng pag-aaral. Magsimula tayo sa isang gawain.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.playTime,
      emoji: '🧸',
      label: 'Play Time',
      labelFilipino: 'Oras ng Laro',
      blurb: 'Free play, alone or with friends',
      blurbFilipino: 'Malayang paglalaro, mag-isa o kasama ang kaibigan',
      defaultHour: 15,
      defaultMinute: 0,
      defaultDurationMinutes: 30,
      instructions: [
        RoutineInstruction('🧸', 'Choose what to play', 'Pumili ng lalaruin'),
        RoutineInstruction('🧑‍🤝‍🧑', 'Play nicely and share',
            'Maglaro nang maayos at magbahagi'),
        RoutineInstruction('📦', 'Put the toys away after',
            'Iligpit ang laruan pagkatapos'),
      ],
      signCues: [
        FslSignCue('Friend', FlashcardCategory.familyAndGreetings),
        FslSignCue('Happy', FlashcardCategory.emotions),
      ],
      audioCue: 'Play time! Choose something fun.',
      audioCueFilipino: 'Oras ng laro! Pumili ng masaya.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.exercise,
      emoji: '🤸',
      label: 'Exercise / Outdoor Time',
      labelFilipino: 'Ehersisyo o Paglabas',
      blurb: 'Move your body and get some air',
      blurbFilipino: 'Igalaw ang katawan at maglabas',
      defaultHour: 16,
      defaultMinute: 30,
      defaultDurationMinutes: 20,
      instructions: [
        RoutineInstruction('👟', 'Put on your shoes', 'Isuot ang sapatos'),
        RoutineInstruction('🙆', 'Warm up and stretch', 'Mag-warm up at mag-unat'),
        RoutineInstruction('🚶', 'Walk, run or play outside',
            'Maglakad, tumakbo o maglaro sa labas'),
        RoutineInstruction('💧', 'Drink water after', 'Uminom ng tubig pagkatapos'),
      ],
      signCues: [
        FslSignCue('Walk', FlashcardCategory.transportation),
        FslSignCue('Feet', FlashcardCategory.bodyParts),
      ],
      audioCue: 'Time to move! Let us stretch first.',
      audioCueFilipino: 'Oras na para gumalaw! Mag-unat muna tayo.',
    ),
    RoutineActivityInfo(
      activity: RoutineActivity.bedtime,
      emoji: '🌙',
      label: 'Bedtime',
      labelFilipino: 'Oras ng Tulog',
      blurb: 'Wind down and sleep',
      blurbFilipino: 'Magpahinga at matulog',
      defaultHour: 20,
      defaultMinute: 0,
      defaultDurationMinutes: 15,
      instructions: [
        RoutineInstruction('🪥', 'Brush your teeth', 'Magsipilyo'),
        RoutineInstruction('👕', 'Change into night clothes',
            'Magpalit ng pantulog'),
        RoutineInstruction('📖', 'Read or listen to a story',
            'Magbasa o makinig ng kwento'),
        RoutineInstruction('🌙', 'Lights off and sleep',
            'Patayin ang ilaw at matulog'),
      ],
      signCues: [
        FslSignCue('Night', FlashcardCategory.weather),
        FslSignCue('Sleepy', FlashcardCategory.emotions),
      ],
      audioCue: 'Bedtime. Let us get ready to sleep.',
      audioCueFilipino: 'Oras ng tulog. Maghanda na tayong matulog.',
    ),
    // "Other customizable activities" from the brief. Everything here is a
    // fallback the educator is expected to override — including the empty
    // sign cue list, which is why `signCuesFor` returns nothing rather than
    // an unrelated clip.
    RoutineActivityInfo(
      activity: RoutineActivity.custom,
      emoji: '⭐',
      label: 'Custom Activity',
      labelFilipino: 'Sariling Gawain',
      blurb: 'Anything else — you name it',
      blurbFilipino: 'Anumang iba pa — kayo ang bahala',
      defaultHour: 9,
      defaultMinute: 0,
      audioCue: 'It is time for the next activity.',
      audioCueFilipino: 'Oras na para sa susunod na gawain.',
    ),
  ];

  /// Everything an educator can add from the picker, in day order. Custom is
  /// excluded — it has its own "＋ Custom activity" affordance, because it
  /// opens a different form (title, emoji and media, all required from
  /// scratch) rather than adding a ready-made step.
  static List<RoutineActivityInfo> get pickable =>
      all.where((i) => !i.activity.isCustom).toList();

  static RoutineActivityInfo infoFor(RoutineActivity activity) =>
      all.firstWhere(
        (i) => i.activity == activity,
        orElse: () => all.last, // custom
      );

  /// The title a learner sees for [step] — the educator's override when they
  /// wrote one, otherwise the catalog label. A custom step with no title
  /// falls back to the generic label rather than rendering blank.
  static String titleFor(RoutineStep step, {required bool filipino}) {
    final override = filipino
        ? (step.titleFilipino.trim().isNotEmpty
            ? step.titleFilipino
            : step.title)
        : (step.title.trim().isNotEmpty ? step.title : step.titleFilipino);
    if (override.trim().isNotEmpty) return override.trim();
    return infoFor(step.activity).labelOf(filipino: filipino);
  }

  /// The emoji for [step] — the override, else the catalog's.
  static String emojiFor(RoutineStep step) {
    final e = step.emoji.trim();
    if (e.isNotEmpty) return e;
    return infoFor(step.activity).emoji;
  }

  /// The educator's note for [step] in the reader's language, falling back to
  /// the other language rather than showing nothing: a note written only in
  /// English is still worth more to a Filipino reader than a blank line.
  static String noteFor(RoutineStep step, {required bool filipino}) {
    final primary = filipino ? step.noteFilipino : step.note;
    if (primary.trim().isNotEmpty) return primary.trim();
    final secondary = filipino ? step.note : step.noteFilipino;
    return secondary.trim();
  }

  /// The sign sequence for [step]: the educator's single-word override when
  /// they set one, otherwise the catalog's verified cues.
  ///
  /// The override carries no category, so it is looked up across all of them —
  /// the right trade for a word an adult typed by hand.
  static List<FslSignCue> signCuesFor(RoutineStep step) {
    final override = step.signWord.trim();
    if (override.isNotEmpty) {
      return [FslSignCue(override)];
    }
    return infoFor(step.activity).signCues;
  }

  /// Instructions for [step]. A custom activity has none of its own, so the
  /// step's note carries the whole instruction — the step screen renders that
  /// case as a single instruction line rather than an empty section.
  static List<RoutineInstruction> instructionsFor(RoutineStep step) =>
      infoFor(step.activity).instructions;

  /// The spoken cue for [step]: the educator's note when they wrote one (it is
  /// more specific than any default), otherwise the catalog line.
  ///
  /// Audio is the primary channel for a learner with a visual disability, so
  /// this is never allowed to come back empty.
  static String audioCueFor(RoutineStep step, {required bool filipino}) {
    final note = noteFor(step, filipino: filipino);
    if (note.isNotEmpty) return note;
    return infoFor(step.activity).audioCueOf(filipino: filipino);
  }
}
