import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../models/guides.dart';
import '../services/feedback_link.dart';

/// One guide (`/help/:guideId`): its sections in order, numbered where they
/// are steps, with **Read aloud** for learners who listen rather than read.
///
/// Read aloud uses the app's own voice in the app's language, and is not
/// offered while a screen reader runs: TalkBack reads the page itself, and two
/// voices at once help nobody.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key, required this.guideId});

  final String guideId;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  TtsService? _tts;

  @override
  void dispose() {
    if (TtsService.speaking.value) _tts?.stop();
    super.dispose();
  }

  Future<void> _toggleReading(Guide guide, bool filipino) async {
    final tts = ref.read(ttsServiceProvider);
    _tts = tts;
    if (TtsService.speaking.value) {
      await tts.stop();
      return;
    }
    final text = guide.spokenText(filipino: filipino);
    await (filipino ? tts.speakFilipino(text) : tts.speakEnglish(text));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final filipino = ref.watch(settingsProvider).locale == 'fil';
    final guide = guideById(widget.guideId);
    final hc = HCColor.of(context);

    if (guide == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/help'),
          title: AppBarTitle(t.helpTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t.helpNotFound, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final screenReader = MediaQuery.accessibleNavigationOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/help'),
        title: AppBarTitle(guide.title.of(filipino: filipino)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppSpacing.lg,
              context.pagePadding,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: guide.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(guide.icon, color: guide.color, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      guide.summary.of(filipino: filipino),
                      style: AppTypography.bodyLarge.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (!screenReader) ...[
                AppSpacing.gapMd,
                ValueListenableBuilder<bool>(
                  valueListenable: TtsService.speaking,
                  builder: (context, speaking, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _toggleReading(guide, filipino),
                      icon: Icon(
                        speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                      ),
                      label: Text(
                        speaking ? t.helpStopReading : t.helpReadAloud,
                      ),
                    ),
                  ),
                ),
              ],
              if (guide.id == 'feedback') ...[
                AppSpacing.gapMd,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: () => openFeedbackForm(context, ref),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(t.feedbackOpenForm),
                  ),
                ),
              ],
              for (final section in guide.sections) ...[
                AppSpacing.gapXl,
                Semantics(
                  header: true,
                  child: Text(
                    section.heading.of(filipino: filipino),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                for (var i = 0; i < section.lines.length; i++)
                  _Line(
                    line: section.lines[i],
                    marker: section.numbered ? '${i + 1}' : null,
                    color: guide.color,
                    filipino: filipino,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One line: a number badge (steps) or a dot (lists), then the text with its
/// optional bold label. Read as one sentence by a screen reader.
class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.marker,
    required this.color,
    required this.filipino,
  });

  final GuideLine line;
  final String? marker;
  final Color color;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final label = line.label?.of(filipino: filipino);
    final text = line.text.of(filipino: filipino);
    final style = AppTypography.bodyLarge.copyWith(
      color: hc.textPrimary,
      height: 1.4,
    );
    final step = marker;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step != null)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 12, top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 14, top: 9),
                child: ExcludeSemantics(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (label != null)
                      TextSpan(
                        text: '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    TextSpan(text: text),
                  ],
                ),
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
