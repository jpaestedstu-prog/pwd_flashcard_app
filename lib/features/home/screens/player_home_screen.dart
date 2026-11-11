import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/controllers/companion_controller.dart';
import '../../../core/widgets/capped_width.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../core/widgets/hub_scaffold.dart';
import '../../../widgets/accessibility_quick_sheet.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/profile_avatar.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../../providers/tile_grid_active_provider.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../companion/widgets/companion_clearance.dart';

/// Minimal home for the Player (guest) role.
///
/// Player profiles never sync to Firestore — everything stays in-memory
/// and Hive — so this screen avoids any list-of-content widgets and any
/// remote provider subscription. Just an avatar, a greeting, one big
/// "Start" call-to-action, and a "Sign up to save your progress" hook
/// that funnels the user into the regular profile-selection flow.
class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final colors = theme.colorScheme;

    // Hands-free reach: each action button registers with the guest shell's
    // gaze D-pad / voice commands (see the guest branch in BottomNavShell) and
    // shows a focus ring. Pure pass-through when gaze is off. The buttons sit
    // in a stretched Column, so each tile keeps full width via SizedBox — the
    // loose focus-ring Stack would otherwise shrink it to intrinsic width.
    final gazeOn = ref.watch(
      tileGridActiveProvider,
    );
    final gazeGrid = GazeTileGridBuilder(active: gazeOn);
    Widget gazeButton(String label, VoidCallback onTap, Widget button) =>
        gazeGrid.section(
          columns: 1,
          expand: false,
          entries: [
            (
              tile: SizedBox(width: double.infinity, child: button),
              cell: GazeTileCell(label: label, onActivate: onTap),
            ),
          ],
        ).first;

    // The AI Buddy's floating button rests in the bottom-right corner, over
    // this page. Where the column would run under it, the column narrows to
    // clear it, or (a phone held upright) the page stops just above it, so
    // no button can be under it at any scroll position: at the largest text
    // on a phone, "How was it?" sat under it (9 Nov). See [roomBesideBuddy].
    final buddyShown = ref.watch(companionVisibleProvider);
    final buddyLook = ref.watch(companionPresentationProvider);
    // [inner] is inside the page's SafeArea, where its insets are spent.
    CompanionRoom roomFor(BuildContext inner, double width) {
      final column = math.min(
        width - 2 * inner.pagePadding,
        kMaxButtonWidth,
      );
      if (!buddyShown) return CompanionRoom(column: column, bottom: 0);
      final view = View.of(inner);
      return roomBesideBuddy(
        width: width,
        column: column,
        button: CompanionFab.size(inner, buddyLook),
        margin: CompanionFab.margin(inner),
        rightInset: view.padding.right / view.devicePixelRatio,
        bottomInset: MediaQuery.paddingOf(inner).bottom,
      );
    }

    return GazeHomeRegistrar(
      active: gazeGrid.active,
      rows: gazeGrid.rows,
      child: HubScaffold(
      intensity: 0.18,
      showParticles: false,
      child: Stack(
        children: [
          // Centered when the content fits the viewport, scrolls when it
          // doesn't (small phones, landscape, split-screen, large fonts).
          // OverflowSafeBody only adds its scroll wrapper at large text
          // scales, so at normal scales a short window used to bottom-overflow
          // this stretched Column — the min-height ConstrainedBox keeps the
          // centered look on tall screens while always allowing scroll.
          LayoutBuilder(
            builder: (context, outer) {
              final room = roomFor(context, outer.maxWidth);
              return Padding(
                padding: EdgeInsets.only(bottom: room.bottom),
                child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                    // No room for the AI Buddy at the end any more: the page
                    // stops above it, or the column clears it (see roomFor).
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      AppSpacing.xl,
                      context.pagePadding,
                      AppSpacing.xl,
                    ),
                    child: // A comfortable column on a tablet held sideways or a computer:
                    // the buttons ran 1,400 px across the window.
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: room.column,
                        ),
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar circle (honors equipped premium avatar)
                        Center(
                          child: ProfileAvatar(
                            profile: profile,
                            // Does not grow with the text on a phone: at the
                            // largest Font Size it pushed Start Learning under
                            // the fold and the AI Buddy (9 Nov).
                            radius: context.screenWidth < 350
                                ? 44
                                : context.isPhone
                                ? 58
                                : context.scaleIcon(58),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          t.childGreeting(profile?.name ?? t.playerFallbackName),
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          t.playerModeNote,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        // ▶ Start Learning
                        gazeButton(
                          t.playerStartLearning,
                          () => context.go('/games'),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: theme.textTheme.titleLarge,
                            ),
                            onPressed: () => context.go('/games'),
                            icon: Icon(Icons.play_circle_fill_rounded,
                                size: context.scaleIcon(32)),
                            label: Text(t.playerStartLearning),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        gazeButton(
                          t.playerBrowseFlashcards,
                          () => context.go('/flashcards'),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/flashcards'),
                            icon: const Icon(Icons.style_rounded),
                            label: Text(t.playerBrowseFlashcards),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        gazeButton(
                          t.homeHowWasIt,
                          () => context.push('/smileyometer'),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/smileyometer'),
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            label: Text(t.homeHowWasIt),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl),

                        // Save-progress hook
                        AppCard(
                          color: colors.tertiaryContainer.withValues(alpha: 0.4),
                          borderColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_outlined),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      t.playerSaveStars,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                t.playerSaveBody,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Builder(builder: (context) {
                                // Side by side where each label fits its half on
                                // one line; one above the other where it does
                                // not, as Gaze and the D-pad then move too. Half
                                // a phone at the largest Font Size put one word
                                // on each line: "Sumali / sa / klase" (4 Nov).
                                final style =
                                    Theme.of(context).textTheme.labelLarge;
                                // The column the buttons are in: the window
                                // less its gutters, never past the cap.
                                final column = math.min(
                                  MediaQuery.sizeOf(context).width -
                                      2 * context.pagePadding,
                                  kMaxButtonWidth,
                                );
                                final half = (column -
                                            2 * AppSpacing.md -
                                            AppSpacing.sm) /
                                        2 -
                                    48;
                                final stacked = [t.playerJoinClass, t.playerJoinGroup]
                                    .any((label) => !FitText.measurer(
                                          context,
                                          label,
                                          style: style,
                                          maxLines: 1,
                                        )(half));
                                // One gaze row for the pair side by side, one each
                                // when stacked.
                                final pair = gazeGrid.section(
                                  columns: stacked ? 1 : 2,
                                  expand: false,
                                  entries: [
                                    (
                                      tile: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              context.push('/join-class'),
                                          child: Text(
                                            t.playerJoinClass,
                                            style: fittedStyle(
                                              context,
                                              t.playerJoinClass,
                                              Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                              // Half a phone row at 2.0x leaves
                                              // these five-letter words too little
                                              // space, so the default eight-char
                                              // trigger never fired: "clas / s".
                                              longWord: 5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      cell: GazeTileCell(
                                        label: t.playerJoinClass,
                                        onActivate: () =>
                                            context.push('/join-class'),
                                      ),
                                    ),
                                    (
                                      tile: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              context.push('/join-home-group'),
                                          child: Text(
                                            t.playerJoinGroup,
                                            style: fittedStyle(
                                              context,
                                              t.playerJoinGroup,
                                              Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                              // Half a phone row at 2.0x leaves
                                              // these five-letter words too little
                                              // space, so the default eight-char
                                              // trigger never fired: "clas / s".
                                              longWord: 5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      cell: GazeTileCell(
                                        label: t.playerJoinGroup,
                                        onActivate: () =>
                                            context.push('/join-home-group'),
                                      ),
                                    ),
                                  ],
                                );
                                if (stacked) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      pair[0],
                                      const SizedBox(height: AppSpacing.sm),
                                      pair[1],
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: pair[0]),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: pair[1]),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        gazeButton(
                          t.childSwitchProfile,
                          () => context.push('/profile-switcher'),
                          TextButton.icon(
                            onPressed: () => context.push('/profile-switcher'),
                            icon: const Icon(Icons.person_outline_rounded),
                            label: Text(t.childSwitchProfile),
                          ),
                        ),
                      ],
                    ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
              );
            },
          ),
          // Floating accessibility shortcut — the Guest Player home has no
          // Settings gear, so this gives the player self-service over text
          // size, contrast, read-aloud, and reduced motion. Registered as its
          // own gaze row so the D-pad reaches it — and it lands as the FIRST
          // row (matching its topmost visual position): this Positioned is
          // built eagerly while the scroll body's sections register later,
          // inside the LayoutBuilder's layout-time builder. Not wrapped via
          // [gazeButton], whose infinite-width SizedBox can't sit in a
          // Positioned.
          Positioned(
            top: 4,
            right: 4,
            child: gazeGrid.section(
              columns: 1,
              expand: false,
              entries: [
                (
                  tile: const AccessibilityQuickButton(),
                  cell: GazeTileCell(
                    label: t.accessibility,
                    onActivate: () => showAccessibilityQuickSheet(context),
                  ),
                ),
              ],
            ).first,
          ),
        ],
      ),
      ),
    );
  }
}
