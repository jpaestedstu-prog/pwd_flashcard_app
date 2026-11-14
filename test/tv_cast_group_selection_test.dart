import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/home_group.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/cast_group_selection.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/cast_group_provider.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';

/// The TV Cast "Class / group" choice: which of a Teacher's classes (or a
/// Parent's home groups) a cast is for. One or several, or all of them as one
/// combined choice — and a cast for everybody must never quietly become a
/// cast for nobody.
void main() {
  const hearing = CastGroupOption(
    id: 'c-hearing',
    name: 'Hearing Impairment Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.hearing,
  );
  const cognitive = CastGroupOption(
    id: 'c-cognitive',
    name: 'Cognitive / Learning Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.cognitive,
  );
  const multiple = CastGroupOption(
    id: 'c-multiple',
    name: 'Multiple Disabilities Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.multiple,
  );
  const options = [hearing, cognitive, multiple];

  group('CastGroupSelection', () {
    test('"All" covers every group, including ones made later', () {
      const all = CastGroupSelection.all();
      expect(all.resolve(options), options);
      expect(all.includes('a-class-created-next-week'), isTrue);
      expect(all.coversAll(options), isTrue);
    });

    test('tapping a group while "All" is on narrows the cast to it', () {
      final next = const CastGroupSelection.all().toggle(hearing.id, options);
      expect(next.all, isFalse);
      expect(next.resolve(options), [hearing]);
      expect(next.coversAll(options), isFalse);
    });

    test('tapping more groups adds them; tapping again removes one', () {
      var s = const CastGroupSelection.all().toggle(hearing.id, options);
      s = s.toggle(cognitive.id, options);
      expect(s.resolve(options), [hearing, cognitive]);
      s = s.toggle(hearing.id, options);
      expect(s.resolve(options), [cognitive]);
    });

    test('picking every group one by one folds into the single "All" choice',
        () {
      var s = const CastGroupSelection.all().toggle(hearing.id, options);
      s = s.toggle(cognitive.id, options);
      s = s.toggle(multiple.id, options);
      expect(s, const CastGroupSelection.all());
    });

    test('un-picking the last group goes back to "All", never to nobody', () {
      final s = const CastGroupSelection.all()
          .toggle(hearing.id, options)
          .toggle(hearing.id, options);
      expect(s.all, isTrue);
      expect(s.resolve(options), options);
    });

    test('a deleted class is skipped; if nothing picked is left, all is cast',
        () {
      final s = CastGroupSelection.only({hearing.id, 'deleted-class'});
      expect(s.resolve(options), [hearing]);
      expect(
        const CastGroupSelection.only({'deleted-class'}).resolve(options),
        options,
      );
      expect(
        const CastGroupSelection.only({'deleted-class'}).normalized(options),
        const CastGroupSelection.all(),
      );
    });

    test('order follows the picker, not the tapping', () {
      final s = const CastGroupSelection.all()
          .toggle(multiple.id, options)
          .toggle(hearing.id, options);
      expect(s.resolve(options), [hearing, multiple]);
    });

    test('saves and reads back', () {
      final s = CastGroupSelection.only({multiple.id, hearing.id});
      expect(CastGroupSelection.fromJson(s.toJson()), s);
      expect(
        CastGroupSelection.fromJson(const CastGroupSelection.all().toJson()),
        const CastGroupSelection.all(),
      );
    });

    test('anything unreadable reads as "All"', () {
      for (final junk in <Object?>[
        null,
        'all',
        42,
        <String, Object?>{},
        {'all': false},
        {'all': false, 'ids': 'c-hearing'},
        {'all': false, 'ids': <Object?>[]},
        {'all': false, 'ids': <Object?>[null, 3, '']},
      ]) {
        expect(
          CastGroupSelection.fromJson(junk),
          const CastGroupSelection.all(),
          reason: '$junk',
        );
      }
    });
  });

  group('castGroupOptionsFrom', () {
    final t = DateTime(2026, 11, 2);
    test('classes first, then home groups, each A–Z, with their audience', () {
      final options = castGroupOptionsFrom(
        [
          Classroom(
            id: 'c2',
            code: 'BBBBBB',
            name: 'multiple Disabilities Class',
            teacherId: 'kevin',
            accessibility: DisabilityType.multiple,
            createdAt: t,
            updatedAt: t,
          ),
          Classroom(
            id: 'c1',
            code: 'AAAAAA',
            name: 'Hearing Class',
            teacherId: 'kevin',
            accessibility: DisabilityType.hearing,
            createdAt: t,
            updatedAt: t,
          ),
        ],
        [
          HomeGroup(
            id: 'g1',
            code: 'CCCCCC',
            name: 'Family',
            ownerProfileId: 'kevin',
            accessibility: DisabilityType.cognitive,
            createdAt: t,
            updatedAt: t,
          ),
        ],
      );
      expect(options.map((o) => o.id), ['c1', 'c2', 'g1']);
      expect(options.first.accessibility, DisabilityType.hearing);
      expect(options.last.kind, LiveSessionOwnerKind.homeGroup);
    });
  });

  group('castMemberIds', () {
    UserProfile learner(String id, {String? classroomId, String? homeGroupId}) =>
        UserProfile(
          id: id,
          name: id,
          role: UserRole.student,
          classroomId: classroomId,
          homeGroupId: homeGroupId,
          createdAt: DateTime(2026),
        );

    test('a learner belongs through a membership or through their own profile',
        () {
      final ids = castMemberIds(
        groupIds: {'c-hearing'},
        membersByGroup: {
          'c-hearing': ['joined-by-code'],
          'c-cognitive': ['other-class'],
        },
        learners: [
          learner('names-the-class', classroomId: 'c-hearing'),
          learner('other-class', classroomId: 'c-cognitive'),
          learner('child', homeGroupId: 'c-hearing'),
          learner('nobody'),
        ],
      );
      expect(ids, {'joined-by-code', 'names-the-class', 'child'});
    });

    test('learners of groups not picked never leak in', () {
      final ids = castMemberIds(
        groupIds: {'c-cognitive'},
        membersByGroup: {
          'c-hearing': ['deaf-student'],
        },
        learners: [learner('deaf-student', classroomId: 'c-hearing')],
      );
      expect(ids, isEmpty);
    });
  });

  group('castAllGroupsLabel', () {
    test('names the combined choice for what the educator has', () {
      final en = AppLocalizationsEn();
      expect(castAllGroupsLabel(en, options), 'All classes');
      const family = CastGroupOption(
        id: 'g',
        name: 'Family',
        kind: LiveSessionOwnerKind.homeGroup,
      );
      expect(castAllGroupsLabel(en, const [family]), 'All groups');
      expect(
        castAllGroupsLabel(en, const [hearing, family]),
        'All classes and groups',
      );
      expect(castAllGroupsLabel(AppLocalizationsFil(), options), 'Lahat ng klase');
    });
  });
}
