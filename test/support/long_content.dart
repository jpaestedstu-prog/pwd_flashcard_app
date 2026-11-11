import 'package:pwdpwdpwd/core/widgets/text_limits.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/classroom_member.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/home_group.dart';
import 'package:pwdpwdpwd/data/models/home_group_member.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/goals/models/goal_model.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/notebook/models/notebook_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/showcase/models/showcase_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The whole app filled with what people may type, at its longest
/// ([TextLimits]): names, class names, notes, routines, words, messages.
///
/// The screen sweeps open every screen on an empty store, so a list that shows
/// something typed was mostly never drawn. Each piece of text here is unique
/// to its kind, so a survey can also say where each one was seen.
const longName = 'Josefina Maria Dela Cruz-Reyes';

const _words = 'Ang mahabang pangungusap na ito ay para sa pagsubok ng mga '
    'screen sa telepono at tablet kapag malaki ang mga letra, at '
    'kailangang makita ito nang buo saanman ito lumabas sa app. ';

/// Real words, as long as [length], ending in a whole word.
String longText(String start, int length) {
  var s = '$start ';
  while (s.length < length) {
    s += _words;
  }
  s = s.substring(0, length);
  // Not a half word at the very end, or a space.
  if (s.endsWith(' ')) s = '${s.substring(0, length - 1)}a';
  return s;
}

/// Every piece of typed text, with where it comes from.
final longClassName = longText('KlaseSampaguita', TextLimits.label);
final longGroupName = longText('PamilyaReyes', TextLimits.label);
final longSection = longText('SeksiyonRizal', TextLimits.personName);
final longNoteTitle = longText('TalaPamagat', TextLimits.title);
final longNoteBody = longText('TalaLaman', 1200);
final longCardEnglish = longText('Butterflyword', TextLimits.label);
final longCardFilipino = longText('Paruparosalita', TextLimits.label);
final longCardSentence = longText('Pangungusapkard', TextLimits.sentence);
final longGoal = longText('LayuninKo', TextLimits.title);
final longMoodNote = longText('DamdaminKo', 200);
final longMessage = longText('MensaheKo', TextLimits.message);
final longRoutineName = longText('RoutineUmaga', TextLimits.label);
final longStepTitle = longText('HakbangUna', TextLimits.label);
final longStepNote = longText('TalaHakbang', TextLimits.sentence);
final longAlarm = longText('AlarmaGising', TextLimits.label);
final longShowcaseTitle = longText('ShowcasePamagat', TextLimits.title);
final longShowcaseNote = longText('ShowcaseTala', TextLimits.paragraph);

/// The first word of each, to find on a screen.
final Map<String, String> longMarkers = {
  'class name': 'KlaseSampaguita',
  'group name': 'PamilyaReyes',
  'section': 'SeksiyonRizal',
  'note title': 'TalaPamagat',
  'note body': 'TalaLaman',
  'card word': 'Butterflyword',
  'card Filipino': 'Paruparosalita',
  'card sentence': 'Pangungusapkard',
  'goal': 'LayuninKo',
  'mood note': 'DamdaminKo',
  'message': 'MensaheKo',
  'routine name': 'RoutineUmaga',
  'step title': 'HakbangUna',
  'step note': 'TalaHakbang',
  'alarm': 'AlarmaGising',
  'showcase title': 'ShowcasePamagat',
  'showcase note': 'ShowcaseTala',
  'a learner\'s name': longName,
};

/// The learners seeded for a teacher's or a parent's lists.
const longLearnerIds = ['long-1', 'long-2', 'long-3', 'long-4'];

/// Their names, each as long as a name may be, and each different: real rows
/// read differently, and a sweep rightly objects to two stops saying the same.
const longLearnerNames = {
  'long-1': longName,
  'long-2': 'Maria Clara Santos-Villanueva',
  'long-3': 'Juan Miguel Bautista-Ramirez',
  'long-4': 'Angelica Rose Mendoza-Aquino',
};

/// Fills the open sweep boxes for [me], a profile of any role: as a teacher's
/// class and a parent's group, and as a learner's own notes, routine, goals,
/// moods and messages.
Future<void> seedLongContent(String me) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day, 8);

  for (final id in longLearnerIds) {
    await HiveService.saveProfile(UserProfile(
      id: id,
      name: longLearnerNames[id]!,
      role: UserRole.student,
      createdAt: day,
      disabilityType: DisabilityType.visual,
      section: longSection,
      classroomId: 'long-class',
      homeGroupId: 'long-group',
      tags: [longText('Tag', TextLimits.tag)],
    ));
  }

  await HiveService.cacheClassroom(Classroom(
    id: 'long-class',
    code: 'ABC123',
    name: longClassName,
    teacherId: me,
    createdAt: day,
    updatedAt: day,
  ));
  await HiveService.cacheHomeGroup(HomeGroup(
    id: 'long-group',
    code: 'XYZ789',
    name: longGroupName,
    ownerProfileId: me,
    createdAt: day,
    updatedAt: day,
  ));
  for (final id in longLearnerIds) {
    await HiveService.addMemberLocal(ClassroomMember(
      classroomId: 'long-class',
      profileId: id,
      displayName: longLearnerNames[id]!,
      joinedAt: day,
    ));
    await HiveService.addHomeGroupMemberLocal(HomeGroupMember(
      homeGroupId: 'long-group',
      profileId: id,
      displayName: longLearnerNames[id]!,
      joinedAt: day,
    ));
  }

  for (var i = 0; i < 3; i++) {
    await HiveService.saveCustomCard(Flashcard(
      id: 'long-card-$i',
      wordEnglish: '$i $longCardEnglish'.substring(0, TextLimits.label),
      wordFilipino: '$i $longCardFilipino'.substring(0, TextLimits.label),
      exampleSentence: '$i $longCardSentence'.substring(0, TextLimits.sentence),
      category: FlashcardCategory.animals,
      isCustom: true,
    ));
  }

  await Hive.box('progress').put('notebook_$me', [
    for (var i = 0; i < 3; i++)
      NoteEntry(
        id: 'long-note-$i',
        title: '$i $longNoteTitle'.substring(0, TextLimits.title),
        content: '$i $longNoteBody',
        category: FlashcardCategory.animals,
        createdAt: day,
        updatedAt: day,
      ).toJson(),
  ]);

  await HiveService.saveGoals(me, [
    LearningGoal(
      id: 'long-goal',
      title: longGoal,
      type: GoalType.wordsLearned,
      targetValue: 100,
      currentValue: 40,
      createdAt: day,
      deadline: day.add(const Duration(days: 7)),
      createdBy: me,
    ),
  ]);

  await HiveService.saveMoodEntries(me, [
    for (var i = 0; i < 3; i++)
      MoodEntry(
        id: 'long-mood-$i',
        profileId: me,
        mood: MoodType.values[i],
        note: '$i $longMoodNote'.substring(0, 200),
        timestamp: day.subtract(Duration(days: i)),
      ),
  ]);

  await HiveService.saveMessages(me, [
    for (var i = 0; i < 3; i++)
      LocalMessage(
        id: 'long-message-$i',
        senderId: longLearnerIds[i],
        senderName: longLearnerNames[longLearnerIds[i]]!,
        recipientId: me,
        content: '$i $longMessage'.substring(0, TextLimits.message),
        type: MessageType.text,
        timestamp: day.subtract(Duration(minutes: i)),
      ),
  ]);

  final routine = Routine(
    id: 'long-routine',
    childProfileId: me,
    setterProfileId: me,
    setterRole: UserRole.teacher,
    name: longRoutineName,
    nameFilipino: longRoutineName,
    steps: [
      for (var i = 0; i < 3; i++)
        RoutineStep(
          id: 'long-step-$i',
          activity: RoutineActivity.values[i],
          title: '$i $longStepTitle'.substring(0, TextLimits.label),
          titleFilipino: '$i $longStepTitle'.substring(0, TextLimits.label),
          emoji: '🌞',
          hour: 8 + i,
          minute: 0,
          durationMinutes: 15,
          note: longStepNote,
          noteFilipino: longStepNote,
        ),
    ],
    createdAt: day,
    updatedAt: day,
  );
  await HiveService.cacheRoutine(routine, cloudSynced: true);
  await HiveService.cacheRoutine(
    Routine(
      id: 'long-routine-child',
      childProfileId: longLearnerIds.first,
      setterProfileId: me,
      setterRole: UserRole.teacher,
      name: longRoutineName,
      nameFilipino: longRoutineName,
      steps: routine.steps,
      createdAt: day,
      updatedAt: day,
    ),
    cloudSynced: true,
  );

  for (final child in [me, longLearnerIds.first]) {
    await HiveService.cacheChildAlarm(ChildAlarm(
      id: 'long-alarm-$child',
      childProfileId: child,
      setterProfileId: me,
      setterRole: UserRole.teacher,
      label: longAlarm,
      hour: 7,
      minute: 30,
      daysOfWeek: const {1, 2, 3, 4, 5},
      createdAt: day,
      updatedAt: day,
    ));
  }

  await Hive.box('progress').put('showcase_$me', [
    ShowcaseItem(
      id: 'long-showcase',
      type: ShowcaseItemType.values.first,
      title: longShowcaseTitle,
      description: longShowcaseNote,
      earnedAt: day,
      isPinned: true,
      customNote: longShowcaseNote,
    ).toJson(),
  ]);
}
