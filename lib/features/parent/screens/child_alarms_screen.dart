import 'package:flutter/material.dart';
import '../../../core/utils/localized_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../data/models/alarm_action.dart';
import '../../../data/models/child_alarm.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_alarm_provider.dart';
import '../services/child_alarm_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../classroom/widgets/cloud_sync_error_view.dart';

/// Per-child alarm list — list, add, edit, delete. Reachable from the
/// per-member popups in classroom and home-group management screens.
class ChildAlarmsScreen extends ConsumerWidget {
  final String childProfileId;
  final String? childDisplayName;

  const ChildAlarmsScreen({
    super.key,
    required this.childProfileId,
    this.childDisplayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(childAlarmListProvider(childProfileId));

    return Scaffold(
      appBar: AppBar(
        title: Text(childDisplayName == null
            ? 'Alarms'
            : 'Alarms — $childDisplayName'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(_t(context).alNew),
        onPressed: () => _openEditor(context, ref, null),
      ),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_t(context).alLoadError(
          cloudSyncErrorMessage(e, _t(context)).title,
        ))),
        data: (alarms) {
          if (alarms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm_off_rounded, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _t(context).alNone,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          // Most recent updatedAt across the list — when this jumps
          // forward after a save it's visible proof the listener
          // round-tripped, giving educators confidence the change
          // really did sync.
          final mostRecent = alarms
              .map((a) => a.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alarms.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Last synced ${_relTime(mostRecent)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              }
              final a = alarms[i - 1];
              return Dismissible(
                key: ValueKey(a.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(_t(context).alDeleteTitle(a.label)),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: Text(_t(context).cancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(_t(context).delete),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  await const ChildAlarmService().delete(a.id);
                },
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      a.enabled
                          ? Icons.alarm_rounded
                          : Icons.alarm_off_rounded,
                      color: a.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    title: Text(a.label.isEmpty ? 'Alarm' : a.label),
                    subtitle: Text(_subtitleFor(context, a)),
                    trailing: Switch(
                      value: a.enabled,
                      onChanged: (v) async {
                        await const ChildAlarmService()
                            .save(a.copyWith(enabled: v));
                      },
                    ),
                    onTap: () => _openEditor(context, ref, a),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _subtitleFor(BuildContext context, ChildAlarm a) {
    final time =
        '${a.hour.toString().padLeft(2, "0")}:${a.minute.toString().padLeft(2, "0")}';
    final days = a.daysOfWeek.isEmpty
        ? _t(context).alEveryDay
        : (a.daysOfWeek.toList()..sort())
            .map((d) => LocalizedDate.weekdayShort(d, _t(context)))
            .join(', ');
    final action = switch (a.action) {
      AlarmAction.notifyOnly => _t(context).alNotifyOnly,
      AlarmAction.lockScreen => _t(context).alLockScreen,
      AlarmAction.endSession => _t(context).alEndSession,
    };
    return '$time · $days · $action';
  }

  /// Compact relative-time formatter for the "Last synced" line.
  /// Inline because nothing else in this screen reaches into the
  /// time domain; matches the formatter on the time-limits screen.
  String _relTime(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    return '${delta.inDays} d ago';
  }

  Future<void> _openEditor(
      BuildContext context, WidgetRef ref, ChildAlarm? existing) async {
    final me = ref.read(profileProvider);
    if (me == null) return;
    final saved = await showDialog<ChildAlarm>(
      context: context,
      builder: (ctx) => _AlarmEditorDialog(
        existing: existing,
        childProfileId: childProfileId,
        setterProfileId: me.id,
        setterRole: me.role,
      ),
    );
    if (saved == null) return;
    try {
      await const ChildAlarmService().save(saved);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context).alSaveError(
          cloudSyncErrorMessage(e, _t(context)).title,
        ))),
      );
    }
  }
}

/// Modal editor for a single alarm. Used in both create and edit modes
/// (passing `existing: null` for create).
class _AlarmEditorDialog extends StatefulWidget {
  final ChildAlarm? existing;
  final String childProfileId;
  final String setterProfileId;
  final UserRole setterRole;

  const _AlarmEditorDialog({
    required this.existing,
    required this.childProfileId,
    required this.setterProfileId,
    required this.setterRole,
  });

  @override
  State<_AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends State<_AlarmEditorDialog> {
  late TextEditingController _label;
  late int _hour;
  late int _minute;
  late Set<int> _days;
  late AlarmAction _action;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _hour = e?.hour ?? TimeOfDay.now().hour;
    _minute = e?.minute ?? 0;
    _days = e == null ? <int>{} : Set<int>.from(e.daysOfWeek);
    _action = e?.action ?? AlarmAction.notifyOnly;
    _enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? _t(context).alNew : _t(context).alEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: _t(context).alLabel,
                hintText: _t(context).alLabelHint,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_t(context).alTime),
              trailing: TextButton(
                onPressed: _pickTime,
                child: Text(
                  '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_t(context).alRepeat),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in const <int, String>{
                  1: 'Mon',
                  2: 'Tue',
                  3: 'Wed',
                  4: 'Thu',
                  5: 'Fri',
                  6: 'Sat',
                  7: 'Sun',
                }.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _days.contains(entry.key),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _days.add(entry.key);
                        } else {
                          _days.remove(entry.key);
                        }
                      });
                    },
                  ),
              ],
            ),
            if (_days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _t(context).alNoDays,
                  style: AppTypography.labelSmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(_t(context).alWhen),
            DropdownButton<AlarmAction>(
              value: _action,
              isExpanded: true,
              onChanged: (v) {
                if (v != null) setState(() => _action = v);
              },
              items: [
                DropdownMenuItem(
                  value: AlarmAction.notifyOnly,
                  child: Text(_t(context).alNotifyOnly),
                ),
                DropdownMenuItem(
                  value: AlarmAction.lockScreen,
                  child: Text(_t(context).alLockPin),
                ),
                DropdownMenuItem(
                  value: AlarmAction.endSession,
                  child: Text(_t(context).alEndHome),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_t(context).alEnabled),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t(context).cancel),
        ),
        FilledButton(
          onPressed: _commit,
          child: Text(_t(context).gmSave),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
  }

  void _commit() {
    final now = DateTime.now();
    final e = widget.existing;
    final result = ChildAlarm(
      id: e?.id ?? '',
      childProfileId: widget.childProfileId,
      setterProfileId: widget.setterProfileId,
      setterRole: widget.setterRole,
      label: _label.text.trim(),
      hour: _hour,
      minute: _minute,
      daysOfWeek: _days,
      action: _action,
      enabled: _enabled,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, result);
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
