import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../logic/hands_free_pause.dart';

/// "Hands-free control is paused", across the top of every screen while the
/// learner has paused it (see [handsFreePaused]).
///
/// The pause is invisible otherwise: a learner who said "stop listening", or
/// a helper standing next to them, must be able to *see* why nothing moves
/// — a Deaf learner especially, who never hears the spoken "Paused". It also
/// says how to go on, and a tap on it resumes (for the helper, or a learner
/// who can touch). A screen reader announces it as it appears.
class HandsFreePausedBanner extends StatelessWidget {
  const HandsFreePausedBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: handsFreePaused,
      child: child,
      builder: (context, paused, child) => Stack(
        children: [
          child!,
          if (paused)
            const Positioned(top: 0, left: 0, right: 0, child: _PausedCard()),
        ],
      ),
    );
  }
}

class _PausedCard extends StatelessWidget {
  const _PausedCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = t?.hfPausedTitle ?? 'Hands-free control is paused';
    final body =
        t?.hfPausedBody ??
        'To go on: say “resume”, blink, press your switch, or tap here.';
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Semantics(
            container: true,
            liveRegion: true,
            button: true,
            label: '$title. $body',
            onTap: resumeHandsFree,
            child: ExcludeSemantics(
              child: Card(
                elevation: 6,
                color: scheme.inverseSurface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: resumeHandsFree,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pause_circle_filled_rounded,
                          color: scheme.onInverseSurface,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: scheme.onInverseSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: TextStyle(
                                  color: scheme.onInverseSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
