import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/classroom.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/firestore_stream_helpers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../services/csv_report_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Pre-defined date ranges for the report. Custom ranges are out of
/// scope for the first cut — IEP / classroom reporting almost always
/// uses one of these three windows.
enum _ReportRange {
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  quarter(Duration(days: 90));

  final Duration duration;
  const _ReportRange(this.duration);
}

/// Generates a downloadable CSV snapshot of student progress for one of
/// the teacher's classrooms. Reachable from the Classroom Dashboard's
/// app bar.
class ExportReportScreen extends ConsumerStatefulWidget {
  /// Optional preselected classroom id. When null, the dropdown shows
  /// no selection and the user picks one of their classrooms.
  final String? initialClassroomId;

  const ExportReportScreen({super.key, this.initialClassroomId});

  @override
  ConsumerState<ExportReportScreen> createState() =>
      _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  String? _classroomId;
  _ReportRange _range = _ReportRange.month;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _classroomId = widget.initialClassroomId;
  }

  Future<void> _export(List<Classroom> classrooms) async {
    if (_classroomId == null) {
      AppSnackBar.error(context, message: _t(context).erPickClass);
      return;
    }
    final classroom = classrooms.firstWhere(
      (c) => c.id == _classroomId,
      orElse: () => Classroom(
        id: _classroomId!,
        code: '',
        name: 'classroom',
        teacherId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    setState(() => _busy = true);
    try {
      final file = await CsvReportService.writeReportFile(
        classroomId: classroom.id,
        classroomLabel: classroom.name,
        last: _range.duration,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _t(context).erShareText(
          classroom.name,
          _rangeLabel(_t(context), _range),
        ),
        subject: _t(context).erShareSubject(classroom.name),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('CSV export failed: $e');
      AppSnackBar.error(context, message: _t(context).erFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(_t(context).erTitleShort),
        ),
        body: Center(
          child: Text(_t(context).erSignIn),
        ),
      );
    }

    final classroomsAsync =
        ref.watch(classroomsByTeacherStreamProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_t(context).erTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              const SizedBox(height: 24),
              classroomsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(_t(context).erLoadFailed),
                data: (classrooms) {
                  if (classrooms.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t(context).erNoClasses,
                        style: AppTypography.bodyMedium,
                      ),
                    );
                  }
                  // Auto-select first classroom if none chosen yet.
                  _classroomId ??= classrooms.first.id;
                  return _Form(
                    classrooms: classrooms,
                    selectedClassroomId: _classroomId,
                    onClassroomChanged: (id) =>
                        setState(() => _classroomId = id),
                    range: _range,
                    onRangeChanged: (r) => setState(() => _range = r),
                    busy: _busy,
                    onExport: () => _export(classrooms),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context).erHeading,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t(context).erIntro,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Form extends StatelessWidget {
  final List<Classroom> classrooms;
  final String? selectedClassroomId;
  final ValueChanged<String?> onClassroomChanged;
  final _ReportRange range;
  final ValueChanged<_ReportRange> onRangeChanged;
  final bool busy;
  final VoidCallback onExport;

  const _Form({
    required this.classrooms,
    required this.selectedClassroomId,
    required this.onClassroomChanged,
    required this.range,
    required this.onRangeChanged,
    required this.busy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_t(context).erClassroom, style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedClassroomId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.class_rounded),
          ),
          items: classrooms
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: busy ? null : onClassroomChanged,
        ),
        const SizedBox(height: 24),
        Text(_t(context).erDateRange, style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _ReportRange.values
              .map((r) => ChoiceChip(
                    label: Text(_rangeLabel(_t(context), r)),
                    selected: range == r,
                    onSelected: busy ? null : (_) => onRangeChanged(r),
                  ))
              .toList(),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: busy ? null : onExport,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(busy ? _t(context).erBuilding : _t(context).erExport),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _t(context).erShareNote,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

String _rangeLabel(AppLocalizations t, _ReportRange r) => switch (r) {
  _ReportRange.week => t.erLast7,
  _ReportRange.month => t.erLast30,
  _ReportRange.quarter => t.erLast90,
};
