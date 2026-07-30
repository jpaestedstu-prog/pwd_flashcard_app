import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../parent/services/child_unlock_override_service.dart';
import 'accessibility_category_picker.dart';
import 'cloud_aware_text_dialog.dart';
import 'cloud_retry_banner.dart';
import 'cloud_sync_error_view.dart';

/// A class or a home group, flattened so the shared management view never
/// has to know which Firestore collection the row came from.
///
/// [source] carries the concrete model ([Classroom] / [HomeGroup]); the
/// delegate casts it back when it needs to write.
class ManagedGroup {
  final String id;
  final String code;
  final String name;
  final DisabilityType accessibility;
  final Object source;

  const ManagedGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.accessibility,
    required this.source,
  });
}

/// One roster row — a `ClassroomMember` or a `HomeGroupMember`.
class ManagedMember {
  final String profileId;
  final String displayName;
  final DateTime joinedAt;

  const ManagedMember({
    required this.profileId,
    required this.displayName,
    required this.joinedAt,
  });
}

/// Everything that differs between the teacher's classes and the parent's
/// home groups: the copy, the icons, and the provider calls.
///
/// The two screens are otherwise **the same screen** — every feature added
/// here lands on both surfaces at once, which is the point: the roster
/// features used to drift apart whenever one file was edited alone.
abstract class GroupManagementDelegate {
  const GroupManagementDelegate();

  // ─── Copy & identity ──────────────────────────────────
  String get screenTitle;

  /// Lowercase singular, used inside sentences: "New class", "Delete class".
  String get groupNoun;
  String get groupNounPlural;

  /// Lowercase singular for a roster row: "student" / "child".
  String get memberNoun;

  /// Irregular plurals matter here — "children", not "childs".
  String get memberNounPlural;

  IconData get groupIcon;
  IconData get memberIcon;

  /// Placeholder in the create dialog, e.g. "Grade 3 - Math".
  String get createHint;

  /// `kind` query parameter for `/leaderboard-config`.
  String get leaderboardKind;

  /// Backdrop preset — teachers get the calm academic gradient, parents the
  /// warm home one, matching the two educator home screens.
  GradientPreset get gradientPreset;

  Color get accent;

  /// Emoji + copy for the "nothing here yet" state.
  String get emptyEmoji;

  /// Sentence appended to a shared join code.
  String get shareBlurb;

  // ─── Data ─────────────────────────────────────────────
  AsyncValue<List<ManagedGroup>> watchGroups(WidgetRef ref);
  AsyncValue<List<ManagedMember>> watchMembers(WidgetRef ref, String groupId);

  // ─── Mutations ────────────────────────────────────────
  Future<void> refresh(WidgetRef ref);
  Future<void> createGroup(
    WidgetRef ref,
    String name,
    DisabilityType accessibility,
  );
  Future<void> renameGroup(WidgetRef ref, ManagedGroup group, String name);
  Future<void> setAccessibility(
    WidgetRef ref,
    ManagedGroup group,
    DisabilityType accessibility,
  );
  Future<void> regenerateCode(WidgetRef ref, ManagedGroup group);
  Future<void> deleteGroup(WidgetRef ref, ManagedGroup group);
  Future<void> renameMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
    String displayName,
  );
  Future<void> removeMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
  );
  Future<void> removeMembers(
    WidgetRef ref,
    ManagedGroup group,
    List<String> profileIds,
  );
}

/// The one management surface behind both "Manage Classes" (teacher) and
/// "Home Groups" (parent).
///
/// Structure: an overview panel (groups / members / newest join), then one
/// expandable card per group carrying the join code, the accessibility
/// audience, every group action, and the live roster with per-member
/// actions and long-press multi-select.
class GroupManagementView extends ConsumerWidget {
  final GroupManagementDelegate delegate;

  const GroupManagementView({super.key, required this.delegate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final groupsAsync = delegate.watchGroups(ref);

    return AnimatedGradientBackground(
      intensity: 0.25,
      preset: delegate.gradientPreset,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            delegate.screenTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
              tooltip: 'Refresh',
              onPressed: () => delegate.refresh(ref),
            ),
            IconButton(
              icon: Icon(Icons.add_rounded, color: hc.textSecondary),
              tooltip: 'New ${delegate.groupNoun}',
              onPressed: () => _showCreateDialog(context, ref),
            ),
          ],
        ),
        // A plain (non-extended) FAB: an extended label such as "New home
        // group" grows unbounded at a 2.0x font scale and would push past a
        // 360dp-wide screen.
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateDialog(context, ref),
          tooltip: 'New ${delegate.groupNoun}',
          child: const Icon(Icons.add_rounded),
        ),
        body: Column(
          children: [
            if (!FirebaseService.isConfigured)
              CloudRetryBanner(onRetrySucceeded: () => delegate.refresh(ref)),
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => CloudSyncErrorView(
                  error: e,
                  onRetry: () async => delegate.refresh(ref),
                ),
                data: (groups) {
                  if (groups.isEmpty) return _empty(context, ref);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryPanel(delegate: delegate, groups: groups)
                          .animate()
                          .fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),
                      for (final group in groups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _GroupCard(delegate: delegate, group: group),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable so the illustration + copy + CTA can't bottom-overflow a
  /// short viewport at a large accessibility font scale.
  Widget _empty(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: RichEmptyState(
            emoji: delegate.emptyEmoji,
            title: 'No ${delegate.groupNounPlural} yet',
            description:
                'Create a ${delegate.groupNoun}, then share the join code '
                'so your ${delegate.memberNounPlural} can join from their '
                'own devices.',
            actionLabel: 'Create ${delegate.groupNoun}',
            actionIcon: Icons.add_rounded,
            accentColor: delegate.accent,
            onAction: () => _showCreateDialog(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final created = await CloudAwareTextDialog.show(
      context: context,
      title: 'New ${delegate.groupNoun}',
      inputLabel: '${_capitalise(delegate.groupNoun)} name',
      inputHint: delegate.createHint,
      submitLabel: 'Create',
      emptyError: '${_capitalise(delegate.groupNoun)} name is required',
      initialAccessibility: DisabilityType.none,
      onSubmitWithAccessibility: (name, accessibility) =>
          delegate.createGroup(ref, name, accessibility),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_capitalise(delegate.groupNoun)} created.')),
      );
    }
  }
}

// ─── Overview panel ──────────────────────────────────────

/// Groups / members / newest-join summary above the list.
///
/// Reads each group's roster from the same family stream provider the cards
/// use, so it adds no extra Firestore subscriptions.
class _SummaryPanel extends ConsumerWidget {
  final GroupManagementDelegate delegate;
  final List<ManagedGroup> groups;

  const _SummaryPanel({required this.delegate, required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    var members = 0;
    var loading = false;
    DateTime? newestJoin;
    for (final group in groups) {
      final roster = delegate.watchMembers(ref, group.id).valueOrNull;
      if (roster == null) {
        loading = true;
        continue;
      }
      members += roster.length;
      for (final m in roster) {
        if (newestJoin == null || m.joinedAt.isAfter(newestJoin)) {
          newestJoin = m.joinedAt;
        }
      }
    }

    return ProPanel(
      title: 'Overview',
      subtitle:
          '${groups.length} ${groups.length == 1 ? delegate.groupNoun : delegate.groupNounPlural} '
          '· ${loading ? '…' : members} '
          '${members == 1 ? delegate.memberNoun : delegate.memberNounPlural}',
      trailing: Icon(delegate.groupIcon, color: hc.primary),
      child: ProStatGrid(
        tiles: [
          ProStatTile(
            icon: delegate.groupIcon,
            label: delegate.groupNounPlural,
            value: '${groups.length}',
            caption: 'active',
            accent: delegate.accent,
          ),
          ProStatTile(
            icon: delegate.memberIcon,
            label: delegate.memberNounPlural,
            value: loading ? '…' : '$members',
            caption: 'enrolled',
            accent: AppColors.sectionLearning,
          ),
          ProStatTile(
            icon: Icons.schedule_rounded,
            label: 'Newest join',
            value: newestJoin == null ? '—' : _timeAgo(newestJoin),
            caption: newestJoin == null ? 'no joins yet' : 'most recent',
            accent: AppColors.info,
          ),
        ],
      ),
    );
  }
}

// ─── Group card ──────────────────────────────────────────

/// One class / home group: header, join code, accessibility audience, and
/// the collapsible roster. Owns both the expand state and the roster's
/// long-press multi-select.
class _GroupCard extends ConsumerStatefulWidget {
  final GroupManagementDelegate delegate;
  final ManagedGroup group;

  const _GroupCard({required this.delegate, required this.group});

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  bool _expanded = true;
  final Set<String> _selected = {};

  GroupManagementDelegate get _delegate => widget.delegate;
  ManagedGroup get _group => widget.group;

  bool get _selectionMode => _selected.isNotEmpty;

  void _toggle(String profileId) {
    setState(() {
      if (!_selected.add(profileId)) _selected.remove(profileId);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // The card's own accent is the *role theme's* primary, so the icon badge,
    // the roster avatars and the join-code chip all agree — the teacher reads
    // indigo, the parent coral. [GroupManagementDelegate.accent] stays the
    // surface-level identity colour used by the overview panel.
    final accent = hc.primary;
    final membersAsync = _delegate.watchMembers(ref, _group.id);
    final members = membersAsync.valueOrNull;

    return AppCard(
      borderRadius: 20,
      borderColor: accent.withValues(alpha: 0.18),
      // Blend the accent *into* the surface rather than layering a
      // translucent wash on top: [AppCard] drops its own background whenever a
      // gradient is supplied, so a translucent gradient would let the animated
      // backdrop bleed through and grey the card out.
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(accent.withValues(alpha: 0.10), hc.surface),
          hc.surface,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, hc, accent, members?.length),
          const SizedBox(height: 12),
          _codeRow(context, hc),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: hc.border.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            _roster(context, hc, membersAsync),
          ],
        ],
      ),
    );
  }

  // ── Header: icon badge, name, member count, actions ──
  Widget _header(
    BuildContext context,
    HCColor hc,
    Color accent,
    int? memberCount,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_delegate.groupIcon, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                memberCount == null
                    ? 'Loading roster…'
                    : '$memberCount ${memberCount == 1 ? _delegate.memberNoun : _delegate.memberNounPlural}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '${_capitalise(_delegate.groupNoun)} actions',
          icon: Icon(Icons.more_vert_rounded, color: hc.textSecondary),
          onSelected: _handleGroupAction,
          itemBuilder: (_) => [
            _menuItem('rename', Icons.edit_rounded, 'Rename'),
            _menuItem(
              'accessibility',
              Icons.accessibility_new_rounded,
              'Accessibility',
            ),
            _menuItem('regen', Icons.refresh_rounded, 'New join code'),
            _menuItem('leaderboard', Icons.leaderboard_rounded, 'Leaderboard'),
            _menuItem(
              'delete',
              Icons.delete_outline_rounded,
              'Delete ${_delegate.groupNoun}',
              color: AppColors.error,
            ),
          ],
        ),
        IconButton(
          tooltip: _expanded ? 'Hide roster' : 'Show roster',
          icon: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: hc.textSecondary,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }

  // ── Join code + copy / share + accessibility audience ──
  Widget _codeRow(BuildContext context, HCColor hc) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hc.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hc.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            _group.code,
            style: AppTypography.titleSmall.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy code',
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: _copyCode,
        ),
        IconButton(
          tooltip: 'Share code',
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          onPressed: _shareCode,
        ),
        AccessibilityCategoryChip(type: _group.accessibility),
      ],
    );
  }

  // ── Roster ──
  Widget _roster(
    BuildContext context,
    HCColor hc,
    AsyncValue<List<ManagedMember>> membersAsync,
  ) {
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Roster error: $e',
          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_rounded,
                  size: 18,
                  color: hc.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No ${_delegate.memberNounPlural} have joined yet — '
                    'share the code above.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Drop selections for members that no longer exist.
        final liveIds = members.map((m) => m.profileId).toSet();
        _selected.removeWhere((id) => !liveIds.contains(id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectionMode)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${_selected.length} selected',
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: _bulkRemove,
                      icon: const Icon(Icons.delete_rounded, size: 16),
                      label: Text('Remove (${_selected.length})'),
                    ),
                  ],
                ),
              ),
            for (final m in members)
              _MemberRow(
                key: ValueKey(m.profileId),
                member: m,
                accent: hc.primary,
                memberNoun: _delegate.memberNoun,
                groupNoun: _delegate.groupNoun,
                selected: _selected.contains(m.profileId),
                selectionMode: _selectionMode,
                onLongPress: () => _toggle(m.profileId),
                onTapInSelection: () => _toggle(m.profileId),
                onRename: () => _renameMember(m),
                onUnlock: () => _unlockMember(m),
                onRemove: () => _removeOne(m),
              ),
          ],
        );
      },
    );
  }

  // ─── Group actions ──────────────────────────────────────

  Future<void> _handleGroupAction(String action) async {
    switch (action) {
      case 'rename':
        await _renameGroup();
      case 'accessibility':
        await _setAccessibility();
      case 'regen':
        await _regenerateCode();
      case 'leaderboard':
        context.push(
          '/leaderboard-config/${_group.id}'
          '?kind=${_delegate.leaderboardKind}'
          '&name=${Uri.encodeQueryComponent(_group.name)}',
        );
      case 'delete':
        await _deleteGroup();
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _group.code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied ${_group.code}')));
  }

  Future<void> _shareCode() async {
    try {
      await Share.share(
        'Join "${_group.name}" on FlashLearn PWD with code ${_group.code}. '
        '${_delegate.shareBlurb}',
        subject: 'FlashLearn PWD join code',
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    }
  }

  Future<void> _renameGroup() async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: 'Rename ${_delegate.groupNoun}',
      inputLabel: '${_capitalise(_delegate.groupNoun)} name',
      inputHint: '',
      submitLabel: 'Save',
      emptyError: '${_capitalise(_delegate.groupNoun)} name is required',
      initialValue: _group.name,
      onSubmit: (name) => _delegate.renameGroup(ref, _group, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_capitalise(_delegate.groupNoun)} renamed.')),
      );
    }
  }

  Future<void> _setAccessibility() async {
    final picked = await showAccessibilityCategoryDialog(
      context,
      current: _group.accessibility,
    );
    if (picked == null || !mounted) return;
    try {
      await _delegate.setAccessibility(ref, _group, picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accessibility set to ${picked.label}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset join code?'),
        content: Text(
          'A new code will be generated. '
          '${_capitalise(_delegate.memberNounPlural)} who already joined stay '
          'enrolled, but the old code stops working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _delegate.regenerateCode(ref, _group);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('New code generated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not regenerate: $e')));
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_group.name}?'),
        content: Text(
          'All ${_delegate.memberNounPlural} will be unenrolled. Their '
          'profiles and progress stay on their own devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _delegate.deleteGroup(ref, _group);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  // ─── Member actions ─────────────────────────────────────

  Future<void> _renameMember(ManagedMember m) async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: 'Rename in roster',
      inputLabel: 'Display name in this ${_delegate.groupNoun}',
      inputHint: '',
      submitLabel: 'Save',
      emptyError: 'Display name is required',
      initialValue: m.displayName,
      helperText:
          'This will rename the ${_delegate.memberNoun} in your roster and '
          'on their device.',
      onSubmit: (name) =>
          _delegate.renameMember(ref, _group, m.profileId, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_capitalise(_delegate.memberNoun)} renamed.'),
        ),
      );
    }
  }

  /// Show the duration picker and write a `child_unlock_overrides` doc for
  /// [m]. The learner's `lockStateProvider` watches that doc and
  /// short-circuits to "not locked" while the override is in the future, so
  /// the lock screen on their device dismisses within seconds.
  Future<void> _unlockMember(ManagedMember m) async {
    final educator = ref.read(profileProvider);
    if (educator == null) return;
    final picked = await _pickUnlockDuration(context, m.displayName);
    if (picked == null) return;
    try {
      await const ChildUnlockOverrideService().setUnlockFor(
        childProfileId: m.profileId,
        duration: picked,
        setter: educator,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${m.displayName} unlocked for ${_formatUnlockDuration(picked)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not unlock: $e')));
    }
  }

  Future<void> _removeOne(ManagedMember m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.displayName}?'),
        content: Text(
          "They'll be unenrolled from this ${_delegate.groupNoun}. Their "
          'profile and progress are kept on their device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _delegate.removeMember(ref, _group, m.profileId);
      // The roster provider is a Firestore stream — no manual refresh needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  Future<void> _bulkRemove() async {
    final n = _selected.length;
    final noun = n == 1 ? _delegate.memberNoun : _delegate.memberNounPlural;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $n $noun?'),
        content: Text(
          'Their profiles and progress are kept on their devices; they just '
          'lose this ${_delegate.groupNoun} linkage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ids = _selected.toList();
    try {
      await _delegate.removeMembers(ref, _group, ids);
      if (mounted) _clearSelection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }
}

// ─── Member row ──────────────────────────────────────────

/// One roster row. Pure widget — selection state lives on [_GroupCardState].
class _MemberRow extends StatelessWidget {
  final ManagedMember member;
  final Color accent;
  final String memberNoun;
  final String groupNoun;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onLongPress;
  final VoidCallback onTapInSelection;
  final VoidCallback onRename;
  final VoidCallback onUnlock;
  final VoidCallback onRemove;

  const _MemberRow({
    super.key,
    required this.member,
    required this.accent,
    required this.memberNoun,
    required this.groupNoun,
    required this.selected,
    required this.selectionMode,
    required this.onLongPress,
    required this.onTapInSelection,
    required this.onRename,
    required this.onUnlock,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final encodedName = Uri.encodeQueryComponent(member.displayName);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      onLongPress: onLongPress,
      onTap: selectionMode ? onTapInSelection : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Text(
          member.displayName.isNotEmpty
              ? member.displayName[0].toUpperCase()
              : '?',
          style: AppTypography.labelLarge.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        member.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: hc.textPrimary,
        ),
      ),
      subtitle: Text(
        'Joined ${_formatDate(member.joinedAt)} · ${_timeAgo(member.joinedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
      ),
      trailing: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTapInSelection())
          : PopupMenuButton<String>(
              tooltip: '${_capitalise(memberNoun)} actions',
              icon: Icon(Icons.more_horiz_rounded, color: hc.textSecondary),
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    onRename();
                  case 'progress':
                    GoRouter.of(context).push(
                      '/progress-timeline/${member.profileId}'
                      '?name=$encodedName',
                    );
                  case 'notes':
                    GoRouter.of(context).push(
                      '/parent-teacher-notes/${member.profileId}'
                      '?name=$encodedName',
                    );
                  case 'time_limits':
                    GoRouter.of(context).push(
                      '/child-time-limits/${member.profileId}'
                      '?name=$encodedName',
                    );
                  case 'alarms':
                    GoRouter.of(context).push(
                      '/child-alarms/${member.profileId}?name=$encodedName',
                    );
                  case 'unlock':
                    onUnlock();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                _menuItem('rename', Icons.edit_rounded, 'Rename'),
                _menuItem('progress', Icons.timeline_rounded, 'View progress'),
                _menuItem('notes', Icons.sticky_note_2_rounded, 'Notes'),
                _menuItem('time_limits', Icons.timer_rounded, 'Time limits'),
                _menuItem('alarms', Icons.alarm_rounded, 'Alarms'),
                _menuItem('unlock', Icons.lock_open_rounded, 'Unlock screen'),
                _menuItem(
                  'remove',
                  Icons.person_remove_rounded,
                  'Remove from $groupNoun',
                  color: AppColors.error,
                ),
              ],
            ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────

PopupMenuItem<String> _menuItem(
  String value,
  IconData icon,
  String label, {
  Color? color,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        // Flexible + ellipsis: menu labels grow with the Font Size setting
        // and would otherwise overflow the popup's bounded width.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

Future<Duration?> _pickUnlockDuration(BuildContext context, String memberName) {
  return showDialog<Duration>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Unlock $memberName'),
      content: const Text(
        'How long should the lock screen stay off? The screen will lock '
        'again automatically when this window expires.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 15)),
          child: const Text('15 min'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 30)),
          child: const Text('30 min'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 60)),
          child: const Text('1 hour'),
        ),
      ],
    ),
  );
}

String _formatUnlockDuration(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    return h == 1 ? '1 hour' : '$h hours';
  }
  return '${d.inMinutes} minutes';
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
