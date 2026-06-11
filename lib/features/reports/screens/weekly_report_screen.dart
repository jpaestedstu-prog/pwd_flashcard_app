import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/app_providers.dart';
import '../services/report_generator.dart';
import '../../../widgets/app_back_button.dart';

/// Screen for generating, previewing and sharing weekly progress reports.
///
/// Parents can select a child, preview the PDF, and share/print it.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  int? _selectedChildIndex;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(parentDashboardProvider);
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(
          onBeforePop: () async {
            if (ref.read(profileProvider.notifier).isViewingAsStudent) {
              await ref.read(profileProvider.notifier).restoreEducatorProfile();
            }
            return true;
          },
        ),
        title: Text(
          'Weekly Reports',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          if (snapshot.children.length > 1)
            TextButton.icon(
              onPressed: _isGenerating ? null : () => _generateFamilyReport(snapshot.children),
              icon: Icon(Icons.family_restroom_rounded, color: hc.primary),
              label: Text(
                'Family Report',
                style: TextStyle(color: hc.primary),
              ),
            ),
        ],
      ),
      body: snapshot.children.isEmpty
          ? _buildEmptyState(hc)
          : _buildContent(snapshot, hc),
    );
  }

  Widget _buildEmptyState(HCColor hc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: hc.textHint),
          const SizedBox(height: 16),
          Text(
            'No student profiles found',
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a student profile to generate reports.',
            style: AppTypography.bodyMedium.copyWith(color: hc.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ParentDashboardSnapshot snapshot, HCColor hc) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ─── Report Description ─────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                hc.primary.withValues(alpha: 0.15),
                hc.secondary.withValues(alpha: 0.1),
                hc.primary.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hc.primary.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: hc.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hc.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: hc.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.description_rounded, color: hc.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Reports',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate professional PDF reports showing weekly stats, '
                      'category mastery, game scores, and personalized insights.',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 24),

        // ─── Section Title ──────────────────────
        Text(
          'Select a child to generate report',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // ─── Child Selection Cards ──────────────
        ...List.generate(snapshot.children.length, (index) {
          final child = snapshot.children[index];
          final isSelected = _selectedChildIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChildReportCard(
              child: child,
              isSelected: isSelected,
              isGenerating: _isGenerating && isSelected,
              hc: hc,
              onTap: () => setState(() => _selectedChildIndex = index),
              onGenerate: () => _generateReport(child),
              onPreview: () => _previewReport(child),
            ),
          ).animate(delay: (100 * index).ms).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
        }),
      ],
    );
  }

  Future<void> _generateReport(ChildSummary child) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await ReportGenerator.generateWeeklyReport(child);
      if (!mounted) return;
      await sharePdfBytes(
        context,
        pdfBytes,
        filename: 'weekly_report_${_safeFileName(child.name)}.pdf',
        subject: 'Weekly Progress Report \u2014 ${child.name}',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Failed to generate report: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewReport(ChildSummary child) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await ReportGenerator.generateWeeklyReport(child);
      if (!mounted) return;

      // Reset loading state before pushing preview route
      setState(() => _isGenerating = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewScreen(
            pdfBytes: pdfBytes,
            title: 'Report Preview \u2014 ${child.name}',
            filename: 'weekly_report_${_safeFileName(child.name)}.pdf',
            shareSubject: 'Weekly Progress Report \u2014 ${child.name}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Failed to preview report: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateFamilyReport(List<ChildSummary> children) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await ReportGenerator.generateFamilyReport(children);
      if (!mounted) return;
      await sharePdfBytes(
        context,
        pdfBytes,
        filename: 'family_progress_report.pdf',
        subject: 'Family Progress Report',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Failed to generate report: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

/// Sanitise a child's name into a safe, lower-case file stem.
///
/// Strips anything that isn't a letter, digit, dash or underscore so the
/// generated filename is valid on every Android storage/file-provider
/// backend (some OEM file managers reject spaces and punctuation).
String _safeFileName(String name) {
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'student' : cleaned;
}

/// Write [bytes] to the cache directory and open the system share sheet via
/// `share_plus`.
///
/// We deliberately use `share_plus` (the same path the CSV export uses)
/// rather than `Printing.sharePdf`: it resolves the foreground Activity
/// itself and supplies the `sharePositionOrigin` anchor that tablets/iPads
/// need for the share popover, so it works consistently across every Android
/// version and OEM. If the file write fails for any reason we fall back to
/// the in-memory `Printing.sharePdf` so the user is never left with a dead
/// button.
Future<void> sharePdfBytes(
  BuildContext context,
  Uint8List bytes, {
  required String filename,
  required String subject,
}) async {
  // Anchor for the iPad/tablet share popover (ignored on phones).
  final box = context.findRenderObject() as RenderBox?;
  final origin = (box != null && box.hasSize)
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: filename)],
      subject: subject,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    // Last-resort fallback \u2014 the printing plugin keeps everything in memory.
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

// \u2500\u2500\u2500 Report Preview Screen \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

/// Full-screen, render-resilient PDF preview.
///
/// `PdfPreview` rasterises pages through the platform renderer. On the odd
/// OEM tablet that rasterisation can fail or come back blank \u2014 so we supply
/// an [PdfPreview.onError] fallback that still lets the user share the
/// report, and we put our own guaranteed Share action in the app bar
/// (driven by [sharePdfBytes]) on top of the built-in toolbar.
class ReportPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;
  final String shareSubject;

  const ReportPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
    required this.filename,
    required this.shareSubject,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => sharePdfBytes(
              context,
              pdfBytes,
              filename: filename,
              subject: shareSubject,
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        // The built-in print action depends on a system print spooler that
        // some tablets/Android Go builds omit; sharing is universal, so we
        // surface sharing (default-on) and hide the print button to avoid a
        // dead control.
        allowPrinting: false,
        pdfFileName: filename,
        onError: (context, error) => _PreviewErrorFallback(
          onShare: () => sharePdfBytes(
            context,
            pdfBytes,
            filename: filename,
            subject: shareSubject,
          ),
        ),
      ),
    );
  }
}

class _PreviewErrorFallback extends StatelessWidget {
  final VoidCallback onShare;

  const _PreviewErrorFallback({required this.onShare});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 72, color: hc.textHint),
            const SizedBox(height: 16),
            Text(
              'On-screen preview isn\'t available on this device.',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'The report was generated successfully \u2014 tap below to open, '
              'save, or send it as a PDF.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: hc.textHint),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Child Report Card Widget ──────────────────────────

class _ChildReportCard extends StatelessWidget {
  final ChildSummary child;
  final bool isSelected;
  final bool isGenerating;
  final HCColor hc;
  final VoidCallback onTap;
  final VoidCallback onGenerate;
  final VoidCallback onPreview;

  const _ChildReportCard({
    required this.child,
    required this.isSelected,
    required this.isGenerating,
    required this.hc,
    required this.onTap,
    required this.onGenerate,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? hc.primary.withValues(alpha: 0.08)
              : hc.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? hc.primary : hc.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? hc.primary : Colors.black)
                  .withValues(alpha: isSelected ? 0.1 : 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar with accuracy indicator
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: child.averageAccuracy,
                          strokeWidth: 2.5,
                          backgroundColor: hc.border.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                            isSelected ? hc.primary : hc.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hc.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(child.avatarEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _ReportStatChip(
                            icon: Icons.star_rounded,
                            text: '${child.totalStars}',
                            color: AppColors.warning,
                          ),
                          _ReportStatChip(
                            icon: Icons.auto_stories_rounded,
                            text: '${child.wordsLearned}',
                            color: AppColors.primary,
                          ),
                          _ReportStatChip(
                            icon: Icons.local_fire_department_rounded,
                            text: '${child.streakDays}d',
                            color: AppColors.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? hc.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? hc.primary : hc.textHint,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),

            // Action buttons (visible when selected)
            if (isSelected) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isGenerating ? null : onPreview,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.preview_rounded, size: 18),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isGenerating ? null : onGenerate,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share PDF'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportStatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ReportStatChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
