import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../core/widgets/hub_scaffold.dart';
import '../../../widgets/accessibility_quick_sheet.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/profile_avatar.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';

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
    final colors = theme.colorScheme;

    // Hands-free reach: each action button registers with the guest shell's
    // gaze D-pad / voice commands (see the guest branch in BottomNavShell) and
    // shows a focus ring. Pure pass-through when gaze is off. The buttons sit
    // in a stretched Column, so each tile keeps full width via SizedBox — the
    // loose focus-ring Stack would otherwise shrink it to intrinsic width.
    final gazeOn = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled && s.navHomeTiles),
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
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pagePadding,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar circle (honors equipped premium avatar)
                    Center(
                      child: ProfileAvatar(
                        profile: profile,
                        radius: context.scaleIcon(58),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Hi, ${profile?.name ?? "Player"}!',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'You\'re in Player mode. Your fun stays on this device.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // ▶ Start Learning
                    gazeButton(
                      'Start Learning',
                      () => context.go('/games'),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: theme.textTheme.titleLarge,
                        ),
                        onPressed: () => context.go('/games'),
                        icon: Icon(Icons.play_circle_fill_rounded,
                            size: context.scaleIcon(32)),
                        label: const Text('Start Learning'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    gazeButton(
                      'Browse flashcards',
                      () => context.go('/flashcards'),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/flashcards'),
                        icon: const Icon(Icons.style_rounded),
                        label: const Text('Browse flashcards'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    gazeButton(
                      'How was it?',
                      () => context.push('/smileyometer'),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/smileyometer'),
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        label: const Text('How was it?'),
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
                                  'Save your stars across devices',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Join a class or home group to back up your '
                            'progress and learn with others.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Builder(builder: (context) {
                            // One 2-column gaze row for the side-by-side pair.
                            final pair = gazeGrid.section(
                              columns: 2,
                              expand: false,
                              entries: [
                                (
                                  tile: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          context.push('/join-class'),
                                      child: const Text('Join class'),
                                    ),
                                  ),
                                  cell: GazeTileCell(
                                    label: 'Join class',
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
                                      child: const Text('Join group'),
                                    ),
                                  ),
                                  cell: GazeTileCell(
                                    label: 'Join group',
                                    onActivate: () =>
                                        context.push('/join-home-group'),
                                  ),
                                ),
                              ],
                            );
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
                      'Switch profile',
                      () => context.push('/profile-switcher'),
                      TextButton.icon(
                        onPressed: () => context.push('/profile-switcher'),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Switch profile'),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
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
                    label: 'Accessibility',
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
