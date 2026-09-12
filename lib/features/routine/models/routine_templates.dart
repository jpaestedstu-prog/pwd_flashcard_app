import '../../../data/models/enums.dart';
import 'routine_catalog.dart';
import 'routine_models.dart';

/// A ready-made routine an educator can start from.
///
/// Templates exist because the blank-page problem is real: a teacher with
/// eighteen students will not hand-build eighteen routines, and a routine that
/// is never built helps nobody. Each one is a *starting point* — every step it
/// creates is fully editable afterwards.
///
/// [suitedTo] drives the "Suggested for this learner" section: the accessibility
/// categories a template was shaped for. An empty set means "suits anyone".
class RoutineTemplate {
  final String id;
  final String emoji;
  final String name;
  final String nameFilipino;
  final String description;
  final String descriptionFilipino;

  /// ISO weekdays the routine is created with. Empty = every day.
  final Set<int> daysOfWeek;

  /// The activities, in order. Times and durations come from the catalog
  /// defaults, which is what makes a template one tap rather than fourteen.
  final List<RoutineActivity> activities;

  /// Accessibility categories this template was designed around.
  final Set<DisabilityType> suitedTo;

  /// Activities whose step asks "how do you feel after this?" once ticked.
  ///
  /// A few, never all: a question after every step of a twelve-step day is a
  /// survey, and a child learns to tap past surveys. The templates aimed at
  /// cognitive and multiple-disability learners ask none by default — fewer
  /// interruptions is the point of those templates — and an educator can
  /// switch any step on afterwards.
  final Set<RoutineActivity> askMoodAfter;

  const RoutineTemplate({
    required this.id,
    required this.emoji,
    required this.name,
    required this.nameFilipino,
    required this.description,
    required this.descriptionFilipino,
    required this.activities,
    this.daysOfWeek = const <int>{},
    this.suitedTo = const <DisabilityType>{},
    this.askMoodAfter = const <RoutineActivity>{},
  });

  String nameOf({required bool filipino}) => filipino ? nameFilipino : name;

  String descriptionOf({required bool filipino}) =>
      filipino ? descriptionFilipino : description;

  bool suits(DisabilityType type) =>
      suitedTo.isEmpty || suitedTo.contains(type);

  /// Builds the steps for this template.
  ///
  /// [idFor] supplies each step's id — injected rather than reaching for a
  /// uuid so this stays pure and the unit tests get stable ids.
  List<RoutineStep> buildSteps(String Function(int index) idFor) {
    final steps = <RoutineStep>[];
    for (var i = 0; i < activities.length; i++) {
      final info = RoutineCatalog.infoFor(activities[i]);
      steps.add(
        RoutineStep(
          id: idFor(i),
          activity: activities[i],
          hour: info.defaultHour,
          minute: info.defaultMinute,
          durationMinutes: info.defaultDurationMinutes,
          askMood: askMoodAfter.contains(activities[i]),
        ),
      );
    }
    return steps;
  }
}

/// The built-in template set.
class RoutineTemplates {
  RoutineTemplates._();

  /// Monday–Friday.
  static const Set<int> _schoolDays = {1, 2, 3, 4, 5};

  static const List<RoutineTemplate> all = [
    RoutineTemplate(
      id: 'full_day',
      emoji: '🗓️',
      name: 'Full Day',
      nameFilipino: 'Buong Araw',
      description: 'Morning to bedtime — the whole day in one routine.',
      descriptionFilipino:
          'Mula umaga hanggang oras ng tulog — buong araw sa isang routine.',
      activities: [
        RoutineActivity.morningRoutine,
        RoutineActivity.brushingTeeth,
        RoutineActivity.breakfast,
        RoutineActivity.gettingDressed,
        RoutineActivity.schoolTime,
        // 9:00 — the "Please do your check-in now" notification and pop-up.
        RoutineActivity.moodCheckIn,
        RoutineActivity.lunch,
        RoutineActivity.napTime,
        RoutineActivity.playTime,
        RoutineActivity.homework,
        RoutineActivity.bathTime,
        RoutineActivity.dinner,
        RoutineActivity.bedtime,
      ],
      askMoodAfter: {
        RoutineActivity.morningRoutine,
        RoutineActivity.brushingTeeth,
        RoutineActivity.schoolTime,
      },
    ),
    RoutineTemplate(
      id: 'morning',
      emoji: '🌅',
      name: 'Morning Routine',
      nameFilipino: 'Rutina sa Umaga',
      description: 'Wake up, wash, eat and get ready.',
      descriptionFilipino: 'Gumising, maghilamos, kumain at maghanda.',
      activities: [
        RoutineActivity.morningRoutine,
        RoutineActivity.brushingTeeth,
        RoutineActivity.breakfast,
        RoutineActivity.gettingDressed,
      ],
      // "How did you feel when you woke up?" / "…after brushing your teeth?"
      askMoodAfter: {
        RoutineActivity.morningRoutine,
        RoutineActivity.brushingTeeth,
      },
    ),
    RoutineTemplate(
      id: 'school_day',
      emoji: '🏫',
      name: 'School Day',
      nameFilipino: 'Araw ng Pasok',
      description: 'Class, break, lunch and homework. Weekdays only.',
      descriptionFilipino:
          'Klase, pahinga, tanghalian at takdang-aralin. Mga araw ng pasok lamang.',
      daysOfWeek: _schoolDays,
      activities: [
        RoutineActivity.schoolTime,
        RoutineActivity.breakTime,
        RoutineActivity.lunch,
        RoutineActivity.homework,
      ],
      askMoodAfter: {RoutineActivity.schoolTime},
    ),
    RoutineTemplate(
      id: 'evening',
      emoji: '🌙',
      name: 'Evening Wind-Down',
      nameFilipino: 'Paghahanda sa Gabi',
      description: 'Bath, dinner and a calm run to bedtime.',
      descriptionFilipino:
          'Paliligo, hapunan at mahinahong paghahanda sa pagtulog.',
      activities: [
        RoutineActivity.bathTime,
        RoutineActivity.dinner,
        RoutineActivity.brushingTeeth,
        RoutineActivity.bedtime,
      ],
      askMoodAfter: {RoutineActivity.bedtime},
    ),
    RoutineTemplate(
      id: 'self_care',
      emoji: '🧼',
      name: 'Self-Care Basics',
      nameFilipino: 'Pangunahing Pag-aalaga sa Sarili',
      description:
          'Four self-care steps with pictures — a short, repeatable day for a '
          'learner building independence.',
      descriptionFilipino:
          'Apat na hakbang sa pag-aalaga sa sarili na may larawan — maikli at '
          'paulit-ulit para sa natututong maging malaya.',
      activities: [
        RoutineActivity.brushingTeeth,
        RoutineActivity.gettingDressed,
        RoutineActivity.bathTime,
        RoutineActivity.bedtime,
      ],
      suitedTo: {
        DisabilityType.cognitive,
        DisabilityType.multiple,
        DisabilityType.motor,
      },
    ),
    RoutineTemplate(
      id: 'calm_day',
      emoji: '🧘',
      name: 'Calm Day',
      nameFilipino: 'Mahinahong Araw',
      description:
          'A short day with rests built in — three anchors and two breaks, for '
          'a learner who needs fewer transitions.',
      descriptionFilipino:
          'Maikling araw na may pahinga — tatlong gawain at dalawang pahinga, '
          'para sa natututong nangangailangan ng kaunting paglipat.',
      activities: [
        RoutineActivity.breakfast,
        RoutineActivity.breakTime,
        RoutineActivity.lunch,
        RoutineActivity.napTime,
        RoutineActivity.dinner,
      ],
      suitedTo: {DisabilityType.cognitive, DisabilityType.multiple},
    ),
    RoutineTemplate(
      id: 'active_day',
      emoji: '🤸',
      name: 'Active Day',
      nameFilipino: 'Aktibong Araw',
      description: 'Play, outdoor time and exercise around the meals.',
      descriptionFilipino:
          'Laro, paglabas at ehersisyo sa pagitan ng mga pagkain.',
      activities: [
        RoutineActivity.breakfast,
        RoutineActivity.exercise,
        RoutineActivity.lunch,
        RoutineActivity.playTime,
        RoutineActivity.dinner,
      ],
    ),
  ];

  static RoutineTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Templates shaped for [type] first, then the general-purpose ones.
  ///
  /// Both groups are always returned — a suggestion is not a restriction, and
  /// an educator who wants the Full Day template for a learner with a
  /// cognitive disability knows their learner better than this list does.
  static List<RoutineTemplate> suggestedFor(DisabilityType type) {
    final tailored = all.where((t) => t.suitedTo.contains(type)).toList();
    final general = all.where((t) => t.suitedTo.isEmpty).toList();
    return [...tailored, ...general];
  }
}
