import 'package:flutter/material.dart';

import '../../../widgets/animated_gradient_background.dart';

/// Which educator is looking at a shared educator surface.
///
/// The data pipeline is identical for both — a teacher owns a roster exactly
/// the way a parent does — so every educator screen is one implementation
/// with the wording, icons and "manage" shortcut selected from here. Adding
/// copy to a single screen is what made the Teacher and Parent surfaces drift
/// apart in the first place; put it on this enum instead.
///
/// Strings that appear on a bilingual screen are methods taking `filipino`
/// rather than getters, so the two locales stay side by side and neither can
/// be forgotten.
enum EducatorAudience {
  parent,
  teacher;

  bool get isParent => this == EducatorAudience.parent;

  String get dashboardTitle =>
      isParent ? 'Parent Dashboard' : 'Teacher Dashboard';

  String get overviewTitle => isParent ? 'Family Overview' : 'Class Overview';

  String get rosterTitle => isParent ? 'Your Children' : 'Your Students';

  String get learnerNoun => isParent ? 'child' : 'student';

  String get learnerNounPlural => isParent ? 'children' : 'students';

  /// Capitalised plural, for stat labels and nav destinations.
  String get learnerNounPluralCap => isParent ? 'Children' : 'Students';

  /// "All Children" / "All Students" — the roster list screen.
  String get allLearnersTitle => 'All $learnerNounPluralCap';

  /// How an educator surface refers to one learner in running prose.
  ///
  /// A parent owns their children, a teacher does not own their students —
  /// "your student" reads as possessive in a way "your child" does not.
  String get learnerPossessive => isParent ? 'your child' : 'this student';

  IconData get rosterIcon =>
      isParent ? Icons.child_care_rounded : Icons.groups_rounded;

  IconData get overviewIcon =>
      isParent ? Icons.family_restroom_rounded : Icons.school_rounded;

  String get manageTooltip => isParent ? 'Manage Home Groups' : 'Manage Classes';

  String get manageRoute =>
      isParent ? '/home-group-manage' : '/classroom-manage';

  String get emptyEmoji => isParent ? '👨‍👩‍👧' : '🏫';

  String get emptyTitle => isParent ? 'No children yet' : 'No students yet';

  String get emptyDescription => isParent
      ? 'Create a home group, then share the code with your child\'s device '
            'to start tracking progress.'
      : 'Create a class, then share the join code with your students to start '
            'tracking progress.';

  String get emptyActionLabel =>
      isParent ? 'Share Home Group Code' : 'Share Class Code';

  /// Notes are written by the *other* educator, so the label flips.
  String get notesTooltip => isParent ? 'Teacher notes' : 'Parent notes';

  /// Teachers get the calm academic backdrop, parents the warm home one —
  /// matching how the two educator home screens already read.
  GradientPreset get gradientPreset =>
      isParent ? GradientPreset.home : GradientPreset.assessment;

  // ── Bilingual copy (Analytics / roster / comparison screens) ──

  String analyticsTitle({required bool filipino}) {
    if (filipino) {
      return isParent ? 'Analytics ng Pamilya' : 'Analytics ng Klase';
    }
    return isParent ? 'Family Analytics' : 'Class Analytics';
  }

  /// Label for the roster-count stat tile.
  String learnersStatLabel({required bool filipino}) {
    if (filipino) return isParent ? 'Mga Anak' : 'Estudyante';
    return learnerNounPluralCap;
  }

  String performanceTitle({required bool filipino}) {
    if (filipino) {
      return isParent
          ? 'Performance ng mga Anak'
          : 'Performance ng mga Estudyante';
    }
    return isParent ? 'Children\'s Performance' : 'Student Performance';
  }

  String compareTooltip({required bool filipino}) {
    if (filipino) return 'Ihambing';
    return isParent ? 'Compare Children' : 'Compare Students';
  }

  String compareTitle({required bool filipino}) => compareTooltip(
        filipino: filipino,
      );

  String selectLearnersTitle({required bool filipino}) {
    if (filipino) return isParent ? 'Pumili ng Anak' : 'Pumili ng Estudyante';
    return isParent ? 'Select Children' : 'Select Students';
  }

  String analyticsEmptyTitle({required bool filipino}) {
    if (filipino) {
      // "pa" carries the "yet" of the English, which is the point: the
      // roster is empty for now, not empty as a fact about this educator.
      return isParent ? 'Wala pang anak' : 'Wala pang estudyante';
    }
    return emptyTitle;
  }

  String analyticsEmptyBody({required bool filipino}) {
    if (filipino) {
      return isParent
          ? 'Ibahagi ang code ng home group para sumali ang inyong anak. '
                'Lalabas dito ang analytics kapag aktibo na sila.'
          : 'Magbahagi ng class code para sumali ang mga estudyante. '
                'Lalabas dito ang analytics kapag aktibo na sila.';
    }
    return isParent
        ? 'Share your home group code so your children can join. Analytics '
              'will appear here once they\'re active.'
        : 'Share your class code so students can join. Analytics will appear '
              'here once they\'re active.';
  }

  String shareCodeLabel({required bool filipino}) {
    if (filipino) {
      return isParent
          ? 'Ibahagi ang Home Group Code'
          : 'Ibahagi ang Class Code';
    }
    return emptyActionLabel;
  }

  /// Screen title of the educator dashboard.
  String dashboardTitleOf({required bool filipino}) {
    if (filipino) return isParent ? 'Dashboard ng Magulang' : 'Dashboard ng Guro';
    return dashboardTitle;
  }

  /// Heading of the roster overview panel.
  String overviewTitleOf({required bool filipino}) {
    if (filipino) {
      return isParent ? 'Pangkalahatan ng Pamilya' : 'Pangkalahatan ng Klase';
    }
    return overviewTitle;
  }

  /// Heading above the learner cards.
  String rosterTitleOf({required bool filipino}) {
    if (filipino) {
      return isParent ? 'Ang Iyong mga Anak' : 'Ang Iyong mga Estudyante';
    }
    return rosterTitle;
  }

  /// Capitalised plural, for stat labels and nav destinations.
  String learnerNounPluralCapOf({required bool filipino}) {
    if (filipino) return isParent ? 'Mga Anak' : 'Mga Estudyante';
    return learnerNounPluralCap;
  }

  /// Empty-roster explanation.
  String emptyDescriptionOf({required bool filipino}) {
    if (filipino) {
      return isParent
          ? 'Gumawa ng home group, pagkatapos ibahagi ang code sa device ng '
                'iyong anak para masubaybayan ang progreso.'
          : 'Gumawa ng klase, pagkatapos ibahagi ang join code sa iyong mga '
                'estudyante para masubaybayan ang progreso.';
    }
    return emptyDescription;
  }

  /// Tooltip on the "manage groups / classes" shortcut.
  String manageTooltipOf({required bool filipino}) {
    if (filipino) {
      return isParent
          ? 'Pamahalaan ang mga Home Group'
          : 'Pamahalaan ang mga Klase';
    }
    return manageTooltip;
  }

  /// Notes are written by the *other* educator, so the label flips.
  String notesTooltipOf({required bool filipino}) {
    if (filipino) return isParent ? 'Tala ng Guro' : 'Tala ng Magulang';
    return notesTooltip;
  }

  /// How an educator surface refers to one learner in running prose.
  String learnerPossessiveOf({required bool filipino}) {
    // No leading article: these land after "ng" and "ang" in the sentences
    // that use them, and "ng ang estudyante" is not Filipino.
    if (filipino) return isParent ? 'iyong anak' : 'estudyanteng ito';
    return learnerPossessive;
  }

  /// "All Children" / "All Students", localised.
  String allLearnersTitleOf({required bool filipino}) {
    if (filipino) return isParent ? 'Lahat ng Anak' : 'Lahat ng Estudyante';
    return allLearnersTitle;
  }

  /// Plural learner noun for running prose, localised.
  ///
  /// Filipino carries its own pluraliser, so this returns "mga anak" rather
  /// than leaving callers to bolt "mga" on and get it wrong in one place.
  String learnerNounPluralOf({required bool filipino}) {
    if (filipino) return isParent ? 'mga anak' : 'mga estudyante';
    return learnerNounPlural;
  }

  /// Singular learner noun, localised.
  String learnerNounOf({required bool filipino}) {
    if (filipino) return isParent ? 'anak' : 'estudyante';
    return learnerNoun;
  }

  String needHelpTitle({required bool filipino}) {
    if (filipino) return 'Nangangailangan ng Tulong';
    return isParent ? 'Children Needing Help' : 'Students Needing Help';
  }
}
