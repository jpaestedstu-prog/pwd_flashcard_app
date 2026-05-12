import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../services/child_time_limit_service.dart';

/// Per-child editor for [ChildTimeLimit].
///
/// Reachable from the educator's classroom or home-group rosters via
/// the per-member popup menu. Writes go through [ChildTimeLimitService]
/// which stamps `owner_uid` and merges into Firestore — security rules
/// require the writer to own the educator profile referenced as
/// `setter_profile_id` on the document.
///
/// The screen is "live" — it watches [childTimeLimitProvider] so a
/// concurrent edit from another educator device shows up here too.
class ChildTimeLimitsScreen extends ConsumerStatefulWidget {
  /// Child profile id whose limit is being edited.
  final String childProfileId;

  /// Optional display name for the AppBar title.
  final String? childDisplayName;

  const ChildTimeLimitsScreen({
    super.key,
    required this.childProfileId,
    this.childDisplayName,
  });

  @override
  ConsumerState<ChildTimeLimitsScreen> createState() =>
      _ChildTimeLimitsScreenState();
}

class _ChildTimeLimitsScreenState
    extends ConsumerState<ChildTimeLimitsScreen> {
  /// Working copy edited locally; saved on tap of "Save".
  ChildTimeLimit? _draft;

  /// Whether [_draft] differs from what was last loaded from the stream.
  bool _dirty = false;

  /// True while a Firestore write is in flight.
  bool _saving = false;

  /// Set to true once we hydrate the draft from the stream so that
  /// later remote updates don't clobber an in-progress edit.
  bool _hydrated = false;

  @override
  Widget build(BuildContext context) {
    final remoteAsync = ref.watch(childTimeLimitProvider(widget.childProfileId));

    // Hydrate draft once from the first non-null/empty stream emission.
    remoteAsync.whenData((remote) {
      if (!_hydrated) {
        _draft = remote ?? _emptyDraft();
        _hydrated = true;
      }
    });

    final draft = _draft ?? _emptyDraft();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.childDisplayName == null
            ? 'Time limits'
            : 'Time limits — ${widget.childDisplayName}'),
        actions: [
          if (_dirty)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
        ],
      ),
      body: remoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (remote) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tiny passive line: when this updates after a save, it's
            // visible proof the child-side listener round-tripped — the
            // educator sees that "yes, it really did sync." Empty docs
            // serialise updatedAt as the epoch sentinel; treat anything
            // before 1990 as "never saved" so we don't render noise.
            if (remote != null &&
                remote.updatedAt.isAfter(DateTime(1990)))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Last saved ${_relTime(remote.updatedAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                ),
              ),
            const _SectionHeader(text: 'Daily time limit'),
            SwitchListTile(
              title: const Text('Enforce a daily limit'),
              subtitle: Text(
                draft.dailyLimitEnabled
                    ? '${draft.dailyLimitMinutes} min per day'
                    : 'No limit',
              ),
              value: draft.dailyLimitEnabled,
              onChanged: (v) => _update(
                draft.copyWith(dailyLimitEnabled: v),
              ),
            ),
            if (draft.dailyLimitEnabled)
              ListTile(
                title: Slider(
                  min: 5,
                  max: 240,
                  divisions: 47,
                  value: draft.dailyLimitMinutes
                      .clamp(5, 240)
                      .toDouble(),
                  label: '${draft.dailyLimitMinutes} min',
                  onChanged: (v) => _update(
                    draft.copyWith(dailyLimitMinutes: v.round()),
                  ),
                ),
                subtitle:
                    Text('${draft.dailyLimitMinutes} minutes per day'),
              ),
            const Divider(height: 32),
            const _SectionHeader(text: 'Allowed schedule'),
            SwitchListTile(
              title: const Text('Restrict by time of day'),
              subtitle: Text(
                draft.scheduleEnabled
                    ? 'Only ${_fmt(draft.allowedStartHour)} – ${_fmt(draft.allowedEndHour)}'
                    : 'Any time',
              ),
              value: draft.scheduleEnabled,
              onChanged: (v) => _update(
                draft.copyWith(scheduleEnabled: v),
              ),
            ),
            if (draft.scheduleEnabled) ...[
              ListTile(
                title: const Text('Allowed start'),
                trailing: Text(_fmt(draft.allowedStartHour)),
                onTap: () => _pickHour(
                  initial: draft.allowedStartHour,
                  onPicked: (h) =>
                      _update(draft.copyWith(allowedStartHour: h)),
                ),
              ),
              ListTile(
                title: const Text('Allowed end'),
                trailing: Text(_fmt(draft.allowedEndHour)),
                onTap: () => _pickHour(
                  initial: draft.allowedEndHour,
                  onPicked: (h) =>
                      _update(draft.copyWith(allowedEndHour: h)),
                ),
              ),
              const SizedBox(height: 8),
              _DaysOfWeekChips(
                selected: draft.allowedDays,
                onChanged: (days) =>
                    _update(draft.copyWith(allowedDays: days)),
              ),
            ],
            const Divider(height: 32),
            if (draft.dailyLimitEnabled || draft.scheduleEnabled)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'When a limit is reached, the child sees a "Time’s up" '
                    'lock screen that requires your PIN to dismiss. They keep '
                    'all progress.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ChildTimeLimit _emptyDraft() {
    final me = ref.read(profileProvider);
    return ChildTimeLimit(
      childProfileId: widget.childProfileId,
      setterProfileId: me?.id ?? '',
      setterRole: me?.role ?? UserRole.parent,
      updatedAt: DateTime.now(),
    );
  }

  void _update(ChildTimeLimit next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final me = ref.read(profileProvider);
    if (me == null) return;
    setState(() => _saving = true);
    try {
      // Stamp the setter on save so a parent re-saving a teacher's
      // limit takes ownership for future edits (matches how we expect
      // the security rule's `ownsProfile(setter_profile_id)` to behave
      // for collaborative classrooms).
      await const ChildTimeLimitService().save(
        draft.copyWith(setterProfileId: me.id, setterRole: me.role),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Future<void> _pickHour({
    required int initial,
    required void Function(int) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial, minute: 0),
    );
    if (picked == null) return;
    onPicked(picked.hour);
  }

  String _fmt(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  /// Compact relative-time formatter for the "Last saved" line. Stays
  /// inline because it's the only place we need it; nothing else in
  /// the screen reaches into the time domain.
  String _relTime(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    return '${delta.inDays} d ago';
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DaysOfWeekChips extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _DaysOfWeekChips({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected.isEmpty
                ? 'Schedule applies every day'
                : 'Schedule applies only on selected days',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in labels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: selected.contains(entry.key),
                  onSelected: (v) {
                    final next = Set<int>.from(selected);
                    if (v) {
                      next.add(entry.key);
                    } else {
                      next.remove(entry.key);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
