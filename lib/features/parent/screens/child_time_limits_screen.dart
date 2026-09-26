import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/lock_media.dart';
import '../../../core/services/guardian_address.dart';
import '../../../core/services/lock_announcer.dart';
import '../../../core/services/lock_presentation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../../../providers/lock_announcement_provider.dart';
import '../../../providers/managed_child_profile_provider.dart';
import '../services/child_time_limit_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
///
/// Beyond the limit itself, this is where the educator configures the
/// **hand-off announcement**: the alarm chime, the spoken message, the
/// name the child is told to hand the device to, and (for learners who
/// sign) the FSL clip. What the child actually experiences depends on
/// their accessibility profile, so the screen shows that resolved
/// behaviour rather than making the educator infer it — see
/// [LockPresentation].
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

class _ChildTimeLimitsScreenState extends ConsumerState<ChildTimeLimitsScreen> {
  /// Working copy edited locally; saved on tap of "Save".
  ChildTimeLimit? _draft;

  /// Whether [_draft] differs from what was last loaded from the stream.
  bool _dirty = false;

  /// True while a Firestore write is in flight.
  bool _saving = false;

  /// Set to true once we hydrate the draft from the stream so that
  /// later remote updates don't clobber an in-progress edit.
  bool _hydrated = false;

  /// Created at hydration time (not in [initState]) so their initial text
  /// comes from the loaded document. Assigning before the tree is built
  /// with them means no listener sees a mid-build mutation.
  TextEditingController? _nameController;
  TextEditingController? _fslController;

  @override
  void dispose() {
    _nameController?.dispose();
    _fslController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteAsync = ref.watch(
      childTimeLimitProvider(widget.childProfileId),
    );
    final childAsync = ref.watch(
      managedChildProfileProvider(widget.childProfileId),
    );
    // Watched (not read) so the announcer survives for the whole screen —
    // the provider is autoDispose and a bare read in the button callback
    // would build and tear it down in the same microtask.
    final announcer = ref.watch(lockAnnouncerProvider);

    // Hydrate draft once from the first non-null/empty stream emission.
    remoteAsync.whenData((remote) {
      if (!_hydrated) {
        final hydratedDraft = remote ?? _emptyDraft();
        _draft = hydratedDraft;
        _nameController = TextEditingController(
          text: hydratedDraft.guardianPreferredName,
        );
        _fslController = TextEditingController(text: hydratedDraft.fslVideoUrl);
        _hydrated = true;
      }
    });

    final draft = _draft ?? _emptyDraft();
    final childType = childAsync.valueOrNull?.disabilityType;
    final presentation = LockPresentation.forProfile(
      childType ?? DisabilityType.none,
      ref.watch(settingsProvider),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.childDisplayName == null
              ? _t(context).tlTitle
              : _t(context).tlTitleFor(widget.childDisplayName!),
        ),
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
              label: Text(_t(context).tlSave),
            ),
        ],
      ),
      body: remoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_t(context).tlLoadError('$e'))),
        data: (remote) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tiny passive line: when this updates after a save, it's
            // visible proof the child-side listener round-tripped — the
            // educator sees that "yes, it really did sync." Empty docs
            // serialise updatedAt as the epoch sentinel; treat anything
            // before 1990 as "never saved" so we don't render noise.
            if (remote != null && remote.updatedAt.isAfter(DateTime(1990)))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Last saved ${_relTime(remote.updatedAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ),
            _AccessibilityProfileCard(
              type: childType,
              presentation: presentation,
              onApplyDefaults: childType == null
                  ? null
                  : () => _applyDefaults(childType),
            ),
            const Divider(height: 32),
            _SectionHeader(text: _t(context).tlDaily),
            SwitchListTile(
              title: Text(_t(context).tlEnforce),
              subtitle: Text(
                draft.dailyLimitEnabled
                    ? _t(context).tlMinPerDay(draft.dailyLimitMinutes)
                    : _t(context).tlNoLimit,
              ),
              value: draft.dailyLimitEnabled,
              onChanged: (v) => _update(draft.copyWith(dailyLimitEnabled: v)),
            ),
            if (draft.dailyLimitEnabled)
              ListTile(
                title: Slider(
                  min: 5,
                  max: 240,
                  divisions: 47,
                  value: draft.dailyLimitMinutes.clamp(5, 240).toDouble(),
                  label: '${draft.dailyLimitMinutes} min',
                  onChanged: (v) =>
                      _update(draft.copyWith(dailyLimitMinutes: v.round())),
                ),
                subtitle: Text(_t(context).tlMinutesPerDay(draft.dailyLimitMinutes)),
              ),
            const Divider(height: 32),
            _SectionHeader(text: _t(context).tlSchedule),
            SwitchListTile(
              title: Text(_t(context).tlRestrict),
              subtitle: Text(
                draft.scheduleEnabled
                    ? 'Only ${_fmt(draft.allowedStartHour)} – ${_fmt(draft.allowedEndHour)}'
                    : _t(context).tlAnyTime,
              ),
              value: draft.scheduleEnabled,
              onChanged: (v) => _update(draft.copyWith(scheduleEnabled: v)),
            ),
            if (draft.scheduleEnabled) ...[
              ListTile(
                title: Text(_t(context).tlStart),
                trailing: Text(_fmt(draft.allowedStartHour)),
                onTap: () => _pickHour(
                  initial: draft.allowedStartHour,
                  onPicked: (h) => _update(draft.copyWith(allowedStartHour: h)),
                ),
              ),
              ListTile(
                title: Text(_t(context).tlEnd),
                trailing: Text(_fmt(draft.allowedEndHour)),
                onTap: () => _pickHour(
                  initial: draft.allowedEndHour,
                  onPicked: (h) => _update(draft.copyWith(allowedEndHour: h)),
                ),
              ),
              const SizedBox(height: 8),
              _DaysOfWeekChips(
                selected: draft.allowedDays,
                onChanged: (days) => _update(draft.copyWith(allowedDays: days)),
              ),
            ],
            const Divider(height: 32),
            _SectionHeader(text: _t(context).tlWhenUp),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _t(context).tlWhenUpBody,
                style: AppTypography.bodySmall.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ),
            ),
            SwitchListTile(
              title: Text(_t(context).tlWarn),
              subtitle: Text(
                draft.warningEnabled
                    ? _t(context).tlWarnOn(draft.effectiveWarningMinutes)
                    : _t(context).tlWarnOff,
              ),
              value: draft.warningEnabled,
              onChanged: (v) => _update(draft.copyWith(warningEnabled: v)),
            ),
            if (draft.warningEnabled)
              ListTile(
                title: Slider(
                  min: ChildTimeLimit.minWarningMinutes.toDouble(),
                  max: ChildTimeLimit.maxWarningMinutes.toDouble(),
                  divisions:
                      ChildTimeLimit.maxWarningMinutes -
                      ChildTimeLimit.minWarningMinutes,
                  value: draft.effectiveWarningMinutes.toDouble(),
                  label: '${draft.effectiveWarningMinutes} min',
                  onChanged: (v) =>
                      _update(draft.copyWith(warningMinutes: v.round())),
                ),
                subtitle: Text(
                  _t(context).tlNotice(draft.effectiveWarningMinutes),
                ),
              ),
            const SizedBox(height: 4),
            SwitchListTile(
              title: Text(_t(context).tlAlarm),
              subtitle: Text(
                _t(context).tlAlarmBody,
              ),
              value: draft.alarmSoundEnabled,
              onChanged: (v) => _update(draft.copyWith(alarmSoundEnabled: v)),
            ),
            SwitchListTile(
              title: Text(_t(context).tlSpeak),
              subtitle: Text(
                presentation.speakMessage
                    ? _t(context).tlSpeakOn
                    : _t(context).tlSpeakOff,
              ),
              value: draft.voiceMessageEnabled,
              onChanged: (v) => _update(draft.copyWith(voiceMessageEnabled: v)),
            ),
            const SizedBox(height: 8),
            _PreferredNameField(
              controller: _nameController,
              derivedHonorific: _derivedHonorific(),
              onChanged: (v) =>
                  _update(draft.copyWith(guardianPreferredName: v)),
            ),
            const SizedBox(height: 12),
            _MessagePreviewCard(
              message: _previewMessage(draft, presentation),
              onPlay: () => _preview(draft, presentation, announcer),
            ),
            const SizedBox(height: 16),
            _FslUrlField(
              controller: _fslController,
              relevant: presentation.showFslVideo,
              onChanged: (v) => _update(draft.copyWith(fslVideoUrl: v)),
            ),
            const Divider(height: 32),
            if (draft.dailyLimitEnabled || draft.scheduleEnabled)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _t(context).tlLockIntro,
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
      guardianHonorific: _derivedHonorific(),
      updatedAt: DateTime.now(),
    );
  }

  /// "Ma'am" / "Sir" / "Mommy" / "Daddy", from the signed-in educator's
  /// own role and the avatar they picked for themselves.
  String _derivedHonorific() {
    final me = ref.read(profileProvider);
    if (me == null) return '';
    return GuardianAddress.honorificFor(
      role: me.role,
      avatarIndex: me.avatarIndex,
    );
  }

  /// The exact line the child will hear / read, for the preview card.
  String _previewMessage(ChildTimeLimit draft, LockPresentation presentation) {
    final me = ref.read(profileProvider);
    final address = GuardianAddress.resolve(
      preferredName: draft.guardianPreferredName,
      stampedHonorific: _derivedHonorific(),
      role: me?.role,
      avatarIndex: me?.avatarIndex,
    );
    if (presentation.simplifiedWording) {
      return GuardianAddress.timesUpMessageSimple(address: address);
    }
    return GuardianAddress.timesUpMessage(
      address: address,
      setterRole: me?.role ?? UserRole.parent,
    );
  }

  /// Plays the announcement here, on the educator's device, exactly as
  /// the child will get it — including the per-profile channel choices
  /// (one chime for a cognitive profile, no speech for a hearing one).
  void _preview(
    ChildTimeLimit draft,
    LockPresentation presentation,
    LockAnnouncer announcer,
  ) {
    unawaited(
      announcer.announce(
        presentation: presentation,
        message: _previewMessage(draft, presentation),
        alarmEnabled: draft.alarmSoundEnabled,
        voiceEnabled: draft.voiceMessageEnabled,
        speakFilipino: ref.read(settingsProvider).locale == 'fil',
      ),
    );
  }

  /// Fills the limit + schedule with the starting points recommended for
  /// [type]. The educator can still change every value afterwards — this
  /// is a shortcut, not a lock-in.
  void _applyDefaults(DisabilityType type) {
    final draft = _draft ?? _emptyDraft();
    final (start, end) = LockPolicyDefaults.scheduleFor(type);
    _update(
      draft.copyWith(
        dailyLimitEnabled: true,
        dailyLimitMinutes: LockPolicyDefaults.dailyMinutesFor(type),
        scheduleEnabled: true,
        allowedStartHour: start,
        allowedEndHour: end,
        alarmSoundEnabled: true,
        voiceMessageEnabled: true,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(context).tlApplied(
            type.profileTypeLabelOf(AppLocalizations.of(context)),
          ),
        ),
      ),
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
      //
      // The honorific is stamped at the same moment and for the same
      // reason: the child's device usually cannot read this educator's
      // profile, so "Ma'am" / "Daddy" has to travel with the document.
      await const ChildTimeLimitService().save(
        draft.copyWith(
          setterProfileId: me.id,
          setterRole: me.role,
          guardianHonorific: GuardianAddress.honorificFor(
            role: me.role,
            avatarIndex: me.avatarIndex,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t(context).tlSaved)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t(context).tlSaveError('$e'))));
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

/// Shows the learner's accessibility category, what the lock will do for
/// them, and a one-tap way to accept the recommended limits.
///
/// This is the screen's answer to "are time limits defined for every
/// accessibility profile?" — the educator sees the resolved behaviour for
/// *this* learner instead of a generic description.
class _AccessibilityProfileCard extends StatelessWidget {
  final DisabilityType? type;
  final LockPresentation presentation;
  final VoidCallback? onApplyDefaults;

  const _AccessibilityProfileCard({
    required this.type,
    required this.presentation,
    required this.onApplyDefaults,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (type == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.help_outline_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(context).tlNotCached,
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility_new_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type!.profileTypeLabelOf(AppLocalizations.of(context)),
                    style: AppTypography.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _t(context).tlAtLock,
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final line in presentation.educatorSummaryOf(
                  AppLocalizations.of(context),
                ))
                  Chip(
                    label: Text(line, style: AppTypography.labelSmall),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              LockPolicyDefaults.rationaleFor(
                type!,
                AppLocalizations.of(context),
              ),
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onApplyDefaults,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(
                  _t(context).tlUseRecommended(
                    LockPolicyDefaults.dailyMinutesFor(type!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Free-text override for how the child is addressed.
class _PreferredNameField extends StatelessWidget {
  final TextEditingController? controller;
  final String derivedHonorific;
  final ValueChanged<String> onChanged;

  const _PreferredNameField({
    required this.controller,
    required this.derivedHonorific,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: _t(context).tlCallYou,
        hintText: _t(context).tlCallHint,
        border: const OutlineInputBorder(),
        helperMaxLines: 3,
        helperText: derivedHonorific.isEmpty
            ? _t(context).tlBlankDefault
            : _t(context).tlBlankAvatar(derivedHonorific),
      ),
    );
  }
}

/// Shows the exact sentence the child will hear, with a play button so
/// the educator can check it before saving.
class _MessagePreviewCard extends StatelessWidget {
  final String message;
  final VoidCallback onPlay;

  const _MessagePreviewCard({required this.message, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(context).tlWillHear,
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '“$message”',
              style: AppTypography.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(_t(context).dtPreview),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-child FSL clip URL. Always editable — a learner's accessibility
/// category can change, and a parent may want the clip available for a
/// multiple-disability profile too — but labelled so the educator knows
/// when it is actually used.
class _FslUrlField extends StatelessWidget {
  final TextEditingController? controller;
  final bool relevant;
  final ValueChanged<String> onChanged;

  const _FslUrlField({
    required this.controller,
    required this.relevant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasDefault = LockMediaDefaults.timesUpFslVideoUrls.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: _t(context).tlFslUrl,
            hintText: 'https://…',
            border: const OutlineInputBorder(),
            helperMaxLines: 4,
            helperText: hasDefault
                ? _t(context).tlFslBlank
                : _t(context).tlFslSet,
          ),
        ),
        if (!relevant)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _t(context).tlFslUnused,
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
          ),
        if (relevant &&
            !hasDefault &&
            (controller?.text.trim().isEmpty ?? true))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _t(context).tlNoClip,
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).warningText,
              ),
            ),
          ),
      ],
    );
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
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DaysOfWeekChips extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _DaysOfWeekChips({required this.selected, required this.onChanged});

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
                ? _t(context).tlEveryDay
                : _t(context).tlSelectedDays,
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
