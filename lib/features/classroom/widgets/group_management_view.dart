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
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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

  /// Whether learners here may sit the pre-test / post-test again.
  final bool allowRetakes;
  final Object source;

  const ManagedGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.accessibility,
    this.allowRetakes = true,
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
  /// `'teacher'` or `'parent'` — picks the whole sentence each string needs,
  /// in either language. The English nouns below stay for data, never for a
  /// sentence a person reads (see the `gm*` ARB keys).
  String get audience;

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
  Future<void> setAllowRetakes(
    WidgetRef ref,
    ManagedGroup group,
    bool allowed,
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
            _tr(context).gmScreenTitle(delegate.audience),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
              tooltip: _tr(context).gmRefresh,
              onPressed: () => delegate.refresh(ref),
            ),
            IconButton(
              icon: Icon(Icons.add_rounded, color: hc.textSecondary),
              tooltip: _tr(context).gmNewGroup(delegate.audience),
              onPressed: () => _showCreateDialog(context, ref),
            ),
          ],
        ),
        // A plain (non-extended) FAB: an extended label such as "New home
        // group" grows unbounded at a 2.0x font scale and would push past a
        // 360dp-wide screen.
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateDialog(context, ref),
          tooltip: _tr(context).gmNewGroup(delegate.audience),
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
            title: _tr(context).gmEmptyTitle(delegate.audience),
            description: _tr(context).gmEmptyBody(delegate.audience),
            actionLabel: _tr(context).gmCreateGroup(delegate.audience),
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
      title: _tr(context).gmNewGroup(delegate.audience),
      inputLabel: _tr(context).gmGroupName(delegate.audience),
      inputHint: _tr(context).gmCreateHint(delegate.audience),
      submitLabel: _tr(context).gmCreate,
      emptyError: _tr(context).gmNameRequired(delegate.audience),
      initialAccessibility: DisabilityType.none,
      onSubmitWithAccessibility: (name, accessibility) =>
          delegate.createGroup(ref, name, accessibility),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context).gmCreated(delegate.audience))),
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
      title: _tr(context).gmOverview,
      subtitle:
          '${_tr(context).gmGroupCount(delegate.audience, groups.length)} '
          '· ${loading ? '…' : _tr(context).gmMemberCount(delegate.audience, members)}',
      trailing: Icon(delegate.groupIcon, color: hc.primary),
      child: ProStatGrid(
        tiles: [
          ProStatTile(
            icon: delegate.groupIcon,
            label: _tr(context).gmGroupsLabel(delegate.audience),
            value: '${groups.length}',
            caption: _tr(context).gmActive,
            accent: delegate.accent,
          ),
          ProStatTile(
            icon: delegate.memberIcon,
            label: _tr(context).gmMembersLabel(delegate.audience),
            value: loading ? '…' : '$members',
            caption: _tr(context).gmEnrolled,
            accent: AppColors.sectionLearning,
          ),
          ProStatTile(
            icon: Icons.schedule_rounded,
            label: _tr(context).gmNewestJoin,
            value: newestJoin == null ? '—' : _timeAgo(_tr(context), newestJoin),
            caption: newestJoin == null
                ? _tr(context).gmNoJoins
                : _tr(context).gmMostRecent,
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
                    ? _tr(context).gmLoadingRoster
                    : _tr(
                        context,
                      ).gmMemberCount(_delegate.audience, memberCount),
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
          tooltip: _tr(context).gmGroupActions(_delegate.audience),
          icon: Icon(Icons.more_vert_rounded, color: hc.textSecondary),
          onSelected: _handleGroupAction,
          itemBuilder: (_) => [
            _menuItem('rename', Icons.edit_rounded, _tr(context).gmRename),
            _menuItem(
              'accessibility',
              Icons.accessibility_new_rounded,
              _tr(context).gmAccessibility,
            ),
            _menuItem(
              'regen',
              Icons.refresh_rounded,
              _tr(context).gmNewJoinCode,
            ),
            _menuItem(
              'leaderboard',
              Icons.leaderboard_rounded,
              _tr(context).gmLeaderboard,
            ),
            _menuItem(
              'retakes',
              _group.allowRetakes
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              _group.allowRetakes
                  ? _tr(context).gmLockRetakes
                  : _tr(context).gmAllowRetakes,
            ),
            _menuItem(
              'delete',
              Icons.delete_outline_rounded,
              _tr(context).gmDeleteGroup(_delegate.audience),
              color: AppColors.error,
            ),
          ],
        ),
        IconButton(
          tooltip: _expanded
              ? _tr(context).gmHideRoster
              : _tr(context).gmShowRoster,
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
          tooltip: _tr(context).gmCopyCode,
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: _copyCode,
        ),
        IconButton(
          tooltip: _tr(context).gmShareCode,
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
          _tr(context).gmRosterError(_reason(context, e)),
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
                    _tr(context).gmNoMembers(_delegate.audience),
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
                      _tr(context).gmSelected(_selected.length),
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: Text(_tr(context).hubCancel),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: _bulkRemove,
                      icon: const Icon(Icons.delete_rounded, size: 16),
                      label: Text(_tr(context).gmRemoveCount(_selected.length)),
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
                audience: _delegate.audience,
                // The group's audience, forwarded so the Routine editor can
                // suggest templates and preview the learner's own view without
                // a second lookup.
                accessibility: _group.accessibility,
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
      case 'retakes':
        await _toggleRetakes();
      case 'delete':
        await _deleteGroup();
    }
  }

  /// Flip whether learners may sit the pre-test / post-test again.
  ///
  /// Confirmed both ways: locking takes something away from every learner in
  /// the group at once, and unlocking quietly re-opens an instrument the
  /// educator may have closed on purpose.
  Future<void> _toggleRetakes() async {
    final locking = _group.allowRetakes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          locking ? _tr(context).gmLockTitle : _tr(context).gmAllowTitle,
        ),
        content: Text(
          locking
              ? _tr(context).gmLockBody(_group.name)
              : _tr(context).gmAllowBody(_group.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(context).hubCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(locking ? _tr(context).gmLock : _tr(context).gmAllow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _delegate.setAllowRetakes(ref, _group, !locking);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locking
                ? _tr(context).gmRetakesLocked
                : _tr(context).gmRetakesAllowed,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotSave(_reason(context, e)))));
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _group.code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_tr(context).gmCopied(_group.code))));
  }

  Future<void> _shareCode() async {
    try {
      await Share.share(
        _tr(context).gmShareText(
          _group.name,
          _group.code,
          _tr(context).gmShareBlurb(_delegate.audience),
        ),
        subject: _tr(context).gmShareSubject,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotShare(_reason(context, e)))));
    }
  }

  Future<void> _renameGroup() async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: _tr(context).gmRenameGroup(_delegate.audience),
      inputLabel: _tr(context).gmGroupName(_delegate.audience),
      inputHint: '',
      submitLabel: _tr(context).gmSave,
      emptyError: _tr(context).gmNameRequired(_delegate.audience),
      initialValue: _group.name,
      onSubmit: (name) => _delegate.renameGroup(ref, _group, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context).gmRenamed(_delegate.audience))),
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
        SnackBar(
          content: Text(
            _tr(
              context,
            ).gmAccessibilitySet(picked.labelOf(AppLocalizations.of(context))),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotUpdate(_reason(context, e)))));
    }
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr(context).gmResetTitle),
        content: Text(_tr(context).gmResetBody(_delegate.audience)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(context).hubCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(context).gmReset),
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
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmNewCodeGenerated)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_tr(context).gmCouldNotRegenerate(_reason(context, e)))),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr(context).gmDeleteTitle(_group.name)),
        content: Text(_tr(context).gmDeleteBody(_delegate.audience)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(context).hubCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(context).hubDelete),
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
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotDelete(_reason(context, e)))));
    }
  }

  // ─── Member actions ─────────────────────────────────────

  Future<void> _renameMember(ManagedMember m) async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: _tr(context).gmRenameInRoster,
      inputLabel: _tr(context).gmDisplayNameIn(_delegate.audience),
      inputHint: '',
      submitLabel: _tr(context).gmSave,
      emptyError: _tr(context).gmDisplayNameRequired,
      initialValue: m.displayName,
      helperText: _tr(context).gmRenameMemberNote(_delegate.audience),
      onSubmit: (name) =>
          _delegate.renameMember(ref, _group, m.profileId, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(context).gmMemberRenamed(_delegate.audience)),
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
            _tr(context).gmUnlockedFor(
              m.displayName,
              _formatUnlockDuration(_tr(context), picked),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotUnlock(_reason(context, e)))));
    }
  }

  Future<void> _removeOne(ManagedMember m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr(context).gmRemoveTitle(m.displayName)),
        content: Text(_tr(context).gmRemoveBody(_delegate.audience)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(context).hubCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(context).gmRemove),
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
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotRemove(_reason(context, e)))));
    }
  }

  Future<void> _bulkRemove() async {
    final n = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr(context).gmRemoveManyTitle(_delegate.audience, n)),
        content: Text(_tr(context).gmRemoveManyBody(_delegate.audience)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(context).hubCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(context).gmRemove),
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
      ).showSnackBar(SnackBar(content: Text(_tr(context).gmCouldNotRemove(_reason(context, e)))));
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

  /// `'teacher'` or `'parent'` — see [GroupManagementDelegate.audience].
  final String audience;

  /// Accessibility audience of the group this member is in. Passed through to
  /// the Routine editor, which shapes its template suggestions and its
  /// learner preview around it.
  final DisabilityType accessibility;

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
    required this.audience,
    required this.accessibility,
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
        _tr(context).gmJoined(
          _formatDate(member.joinedAt),
          _timeAgo(_tr(context), member.joinedAt),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
      ),
      trailing: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTapInSelection())
          : PopupMenuButton<String>(
              tooltip: _tr(context).gmMemberActions(audience),
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
                  case 'routine':
                    GoRouter.of(context).push(
                      '/routine-manage/${member.profileId}'
                      '?name=$encodedName'
                      '&noun=${Uri.encodeQueryComponent(memberNoun)}'
                      '&access=${accessibility.index}',
                    );
                  case 'unlock':
                    onUnlock();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                _menuItem('rename', Icons.edit_rounded, _tr(context).gmRename),
                _menuItem(
                  'progress',
                  Icons.timeline_rounded,
                  _tr(context).gmViewProgress,
                ),
                _menuItem(
                  'notes',
                  Icons.sticky_note_2_rounded,
                  _tr(context).gmNotes,
                ),
                _menuItem(
                  'time_limits',
                  Icons.timer_rounded,
                  _tr(context).gmTimeLimits,
                ),
                _menuItem('alarms', Icons.alarm_rounded, _tr(context).gmAlarms),
                // Daily routine — the visual schedule this learner follows.
                // Sits beside Alarms because the two are the same kind of
                // thing to an educator: what happens, and when.
                _menuItem(
                  'routine',
                  Icons.event_note_rounded,
                  _tr(context).gmRoutine,
                ),
                _menuItem(
                  'unlock',
                  Icons.lock_open_rounded,
                  _tr(context).gmUnlockScreen,
                ),
                _menuItem(
                  'remove',
                  Icons.person_remove_rounded,
                  _tr(context).gmRemoveFrom(audience),
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
      title: Text(_tr(context).gmUnlockTitle(memberName)),
      content: Text(_tr(context).gmUnlockBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(_tr(context).hubCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 15)),
          child: Text(_tr(context).gm15min),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 30)),
          child: Text(_tr(context).gm30min),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 60)),
          child: Text(_tr(context).gm1hour),
        ),
      ],
    ),
  );
}

String _formatUnlockDuration(AppLocalizations t, Duration d) {
  if (d.inHours >= 1) return t.gmHours(d.inHours);
  return t.gmMinutes(d.inMinutes);
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _timeAgo(AppLocalizations t, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return t.gmJustNow;
  if (diff.inMinutes < 60) return t.gmMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return t.gmHoursAgo(diff.inHours);
  if (diff.inDays < 7) return t.gmDaysAgo(diff.inDays);
  return t.gmWeeksAgo((diff.inDays / 7).floor());
}

/// This file's strings: English when no delegate is present, which is how
/// widget tests build these screens.
AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// A short, translated reason for [e] — never the raw exception text, which
/// is English and meant for developers.
String _reason(BuildContext context, Object e) =>
    cloudSyncErrorMessage(e, AppLocalizations.of(context)).title;
