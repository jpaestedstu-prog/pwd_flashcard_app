import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';

/// Renders the cast URL as a QR code, with a copy-to-clipboard chip and
/// the plain text URL for hand-typing on TV remotes that can't scan.
///
/// The URL ends in a per-cast session code. That code is also shown on its own
/// line in large, letter-spaced type: the teacher usually reads it aloud while
/// someone else thumbs it in on a TV remote, and picking `K7M2Q` out of the end
/// of a URL string at arm's length is exactly the moment people mistype.
class TvCastQrCard extends StatelessWidget {
  final String url;

  /// The session code embedded in [url]. Null only for a cast started before
  /// codes existed, in which case the callout is simply omitted.
  final String? code;

  const TvCastQrCard({super.key, required this.url, this.code});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: url,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF111827),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Open this on your TV',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'In the TV\'s own web browser, scan the code or type this URL '
            '(don\'t mirror or cast your tablet — that keeps the sound on '
            'the tablet):',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                AppSnackBar.success(context, message: 'URL copied');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      url,
                      style: AppTypography.titleMedium.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (code != null && code!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CodeCallout(code: code!),
          ],
        ],
      ),
    );
  }
}

/// The session code on its own, big and spaced out, with a one-line
/// explanation of what it's for. Screen readers get the letters spelled out —
/// "K7M2Q" read as a word is useless to someone dictating it.
class _CodeCallout extends StatelessWidget {
  final String code;
  const _CodeCallout({required this.code});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Column(
      children: [
        Text(
          'Cast code',
          style: AppTypography.labelMedium.copyWith(
            color: hc.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: 'Cast code ${code.split('').join(' ')}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              code,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Only TVs opening this exact link can see the cast. '
          'The code changes every time you start casting.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
