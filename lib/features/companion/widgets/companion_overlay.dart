import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../navigation/app_router.dart' show routerProvider;
import '../../../providers/app_providers.dart';
import '../../ai_tutor/models/tutor_models.dart';
import '../../ai_tutor/widgets/tutor_chat.dart';
import '../../ai_tutor/widgets/tutor_persona.dart';
import '../controllers/companion_controller.dart';
import '../models/companion_presentation.dart';

/// Mounts the floating AI Companion above the whole app. Placed in the
/// `MaterialApp.builder` (below the lock / eviction gates) so the companion
/// floats over every learner screen but never over a lock screen. Touch passes
/// straight through everywhere except the launcher and the open panel.
class CompanionHost extends StatelessWidget {
  final Widget child;
  const CompanionHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned.fill(child: CompanionOverlay()),
      ],
    );
  }
}

/// The launcher + panel. Renders nothing (and blocks no touches) unless the
/// active profile is a learner with the companion enabled on a non-immersive
/// screen — see [companionVisibleProvider].
class CompanionOverlay extends ConsumerStatefulWidget {
  const CompanionOverlay({super.key});

  @override
  ConsumerState<CompanionOverlay> createState() => _CompanionOverlayState();
}

class _CompanionOverlayState extends ConsumerState<CompanionOverlay> {
  /// Custom dragged position of the launcher (playful profiles only); null =
  /// docked at the default bottom-right anchor.
  Offset? _dragPos;

  /// The floating buddy only appears over the core learner surfaces — never the
  /// profile switcher, onboarding, or a full-screen tutor / settings page.
  static const _shellRoots = [
    '/home',
    '/flashcards',
    '/games',
    '/stories',
    '/progress',
  ];

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(companionVisibleProvider)) return const SizedBox.shrink();

    final presentation = ref.watch(companionPresentationProvider);
    final isOpen =
        ref.watch(companionControllerProvider.select((s) => s.isOpen));
    final router = ref.watch(routerProvider);

    // Rebuild on navigation so the companion appears/disappears with the route.
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final loc = router.routeInformationProvider.value.uri.toString();
        if (!_shellRoots.any(loc.startsWith)) return const SizedBox.shrink();
        return Stack(
          children: [
            if (isOpen) _Scrim(onTap: () => _controller.close()),
            if (isOpen)
              _PanelAnchor(presentation: presentation)
            else
              _positionedLauncher(context, presentation),
          ],
        );
      },
    );
  }

  CompanionController get _controller =>
      ref.read(companionControllerProvider.notifier);

  Widget _positionedLauncher(
      BuildContext context, CompanionPresentation presentation) {
    final size = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final launcher = presentation.launcherSize * scale;

    // Default anchor: bottom-right, lifted clear of the ~72px bottom nav bar.
    final defaultPos = Offset(
      size.width - launcher - 12,
      size.height - launcher - safeBottom - 84,
    );
    final pos = _dragPos ?? defaultPos;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: _CompanionLauncher(
        presentation: presentation,
        size: launcher,
        onTap: _controller.open,
        onDrag: presentation.draggable
            ? (delta) => setState(() {
                  final x = (pos.dx + delta.dx)
                      .clamp(4.0, size.width - launcher - 4);
                  final y = (pos.dy + delta.dy)
                      .clamp(safeBottom + 4, size.height - launcher - 4);
                  _dragPos = Offset(x, y);
                })
            : null,
      ),
    );
  }
}

/// A faint tap-to-dismiss scrim behind the open panel. Kept light so the
/// companion still reads as "floating over" the screen, not a full modal.
class _Scrim extends StatelessWidget {
  final VoidCallback onTap;
  const _Scrim({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
      ),
    );
  }
}

/// The floating launcher button. Uses the animated tutor avatar for playful
/// profiles and a *still* face for calm ones (the avatar's idle pulse would
/// otherwise ignore reduced motion).
class _CompanionLauncher extends ConsumerWidget {
  final CompanionPresentation presentation;
  final double size;
  final VoidCallback onTap;
  final void Function(Offset delta)? onDrag;

  const _CompanionLauncher({
    required this.presentation,
    required this.size,
    required this.onTap,
    this.onDrag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = TutorPersona.of(ref.watch(profileProvider)?.role);
    final avatar = ref.watch(companionControllerProvider.select((s) => s.avatar));
    final hasUnread =
        ref.watch(companionControllerProvider.select((s) => s.hasUnread));
    final isFilipino =
        ref.watch(settingsProvider.select((s) => s.locale == 'fil'));

    final face = presentation.animate
        ? TutorAvatar(persona: persona, state: avatar, size: size)
        : _StillAvatar(emoji: persona.emoji, size: size);

    return Semantics(
      button: true,
      label: isFilipino
          ? 'Buksan ang AI Buddy'
          : 'Open ${persona.title(false)}',
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate:
            onDrag == null ? null : (d) => onDrag!(d.delta),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bannerAiTutorEnd.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: face,
              ),
              if (hasUnread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: size * 0.26,
                    height: size * 0.26,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Non-animated twin of [TutorAvatar] for calm / reduced-motion profiles.
class _StillAvatar extends StatelessWidget {
  final String emoji;
  final double size;
  const _StillAvatar({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bannerAiTutorStart, AppColors.bannerAiTutorEnd],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

/// Positions the chat panel above the launcher, lifting clear of the keyboard.
class _PanelAnchor extends StatelessWidget {
  final CompanionPresentation presentation;
  const _PanelAnchor({required this.presentation});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final keyboard = media.viewInsets.bottom;
    final topInset = media.padding.top;

    final width = math.min(400.0, size.width - 24);
    final bottom = math.max(84.0 + media.padding.bottom, keyboard + 12);
    final maxHeight = size.height - topInset - bottom - 12;
    final height = math.min(560.0, maxHeight);

    return Positioned(
      right: 12,
      bottom: bottom,
      child: SizedBox(
        width: width,
        height: height,
        child: _CompanionPanel(presentation: presentation),
      ),
    );
  }
}

/// Owns the input + scroll controllers and hosts the chat in a nested [Overlay]
/// so the text field has an Overlay ancestor for its selection controls — the
/// companion lives *above* the app's Navigator, so it can't borrow that one.
class _CompanionPanel extends StatefulWidget {
  final CompanionPresentation presentation;
  const _CompanionPanel({required this.presentation});

  @override
  State<_CompanionPanel> createState() => _CompanionPanelState();
}

class _CompanionPanelState extends State<_CompanionPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The nested Overlay is created once; the reactive UI lives in a Consumer
    // inside the entry, so provider changes rebuild the chat without tearing
    // down the Overlay (which would lose focus / the initial entry).
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Consumer(
            builder: (context, ref, _) => _buildChat(context, ref),
          ),
        ),
      ],
    );
  }

  Widget _buildChat(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final presentation = widget.presentation;
    final state = ref.watch(companionControllerProvider);
    final controller = ref.read(companionControllerProvider.notifier);
    final profile = ref.watch(profileProvider);
    final isFilipino =
        ref.watch(settingsProvider.select((s) => s.locale == 'fil'));
    final persona = TutorPersona.of(profile?.role);

    // Auto-scroll to the newest message / typing indicator.
    ref.listen(companionControllerProvider.select((s) => s.messages.length),
        (_, _) => _scrollToBottom());
    ref.listen(companionControllerProvider.select((s) => s.isTyping),
        (_, _) => _scrollToBottom());

    // Screen-reader live region: only when the profile wants announcing AND we
    // are *not* also auto-speaking via our own TTS (avoids double audio).
    final lastTutor = state.messages.isNotEmpty &&
            state.messages.last.role == TutorMessageRole.tutor
        ? state.messages.last.content
        : '';
    final announce =
        presentation.announce && !presentation.speakReplies ? lastTutor : '';

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: hc.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hc.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (announce.isNotEmpty)
              Semantics(
                liveRegion: true,
                label: announce,
                child: const SizedBox.shrink(),
              ),
            _Header(
              persona: persona,
              isTyping: state.isTyping,
              avatar: state.avatar,
              isFilipino: isFilipino,
              onExpand: () {
                controller.close();
                ref.read(routerProvider).push('/ai-tutor');
              },
              onClose: controller.close,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length && state.isTyping) {
                    return TutorTypingIndicator(persona: persona);
                  }
                  final msg = state.messages[index];
                  return TutorMessageBubble(
                    message: msg,
                    persona: persona,
                    isFilipino: isFilipino,
                    answered: state.answeredIds.contains(msg.id),
                    onQuizAnswer: (a) => controller.answerQuiz(msg, a),
                    onInterestPick: (n) => controller.pickInterest(msg, n),
                    onActionTap: () => _handleAction(context, ref, msg),
                    // Hide the read-aloud affordance for audio-off profiles
                    // (e.g. hearing) — captions already carry everything.
                    onSpeak: presentation.speakReplies
                        ? () => controller.speakMessage(msg.content)
                        : null,
                  );
                },
              ),
            ),
            _QuickChips(isFilipino: isFilipino, onTap: controller.sendQuick),
            if (state.isListening)
              _ListeningBar(
                partial: state.partialTranscript,
                isFilipino: isFilipino,
              ),
            _InputRow(
              controller: _textController,
              presentation: presentation,
              isListening: state.isListening,
              isFilipino: isFilipino,
              onSend: () {
                controller.sendText(_textController.text);
                _textController.clear();
              },
              onMic: controller.toggleVoiceInput,
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, TutorMessage msg) {
    final action = msg.action;
    if (action == null) return;
    final controller = ref.read(companionControllerProvider.notifier);
    if (action.type == TutorActionType.startLesson) {
      controller.startLesson(action.planWordIds ?? const []);
    } else if (action.targetRoute != null) {
      controller.close();
      ref.read(routerProvider).push(action.targetRoute!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _Header extends StatelessWidget {
  final TutorPersona persona;
  final bool isTyping;
  final TutorAvatarState avatar;
  final bool isFilipino;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const _Header({
    required this.persona,
    required this.isTyping,
    required this.avatar,
    required this.isFilipino,
    required this.onExpand,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(bottom: BorderSide(color: hc.border)),
      ),
      child: Row(
        children: [
          TutorAvatar(
            persona: persona,
            state: isTyping ? TutorAvatarState.thinking : avatar,
            size: 30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              persona.title(isFilipino),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: isFilipino ? 'Buong screen' : 'Full screen',
            icon: Icon(Icons.open_in_full_rounded, color: hc.textSecondary),
            onPressed: onExpand,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: isFilipino ? 'Isara' : 'Close',
            icon: Icon(Icons.close_rounded, color: hc.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final bool isFilipino;
  final ValueChanged<String> onTap;
  const _QuickChips({required this.isFilipino, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      child: Row(
        children: [
          TutorQuickChip(
              label: isFilipino ? 'Aralin' : 'Lesson',
              emoji: '🎯',
              onTap: () => onTap('lesson')),
          const SizedBox(width: 6),
          TutorQuickChip(label: 'Quiz', emoji: '❓', onTap: () => onTap('quiz')),
          const SizedBox(width: 6),
          TutorQuickChip(
              label: isFilipino ? 'Pag-unlad' : 'Progress',
              emoji: '📊',
              onTap: () => onTap('progress')),
          const SizedBox(width: 6),
          TutorQuickChip(
              label: isFilipino ? 'Pahiwatig' : 'Hint',
              emoji: '💡',
              onTap: () => onTap('hint')),
          const SizedBox(width: 6),
          TutorQuickChip(
              label: isFilipino ? 'Paborito' : 'Favorites',
              emoji: '💖',
              onTap: () => onTap('favorites')),
        ],
      ),
    );
  }
}

class _ListeningBar extends StatelessWidget {
  final String partial;
  final bool isFilipino;
  const _ListeningBar({required this.partial, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              partial.isEmpty
                  ? (isFilipino ? 'Nakikinig…' : 'Listening…')
                  : partial,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: hc.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final CompanionPresentation presentation;
  final bool isListening;
  final bool isFilipino;
  final VoidCallback onSend;
  final VoidCallback onMic;

  const _InputRow({
    required this.controller,
    required this.presentation,
    required this.isListening,
    required this.isFilipino,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(top: BorderSide(color: hc.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: isFilipino ? 'I-type ang tanong' : 'Type your question',
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: isFilipino ? 'Magtanong…' : 'Ask me anything…',
                  filled: true,
                  fillColor: hc.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: hc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: hc.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
          if (presentation.voiceInput) ...[
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: isListening
                  ? (isFilipino ? 'Itigil ang mic' : 'Stop microphone')
                  : (isFilipino ? 'Magsalita' : 'Speak'),
              child: IconButton.filledTonal(
                onPressed: onMic,
                icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: isListening
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.secondary.withValues(alpha: 0.16),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: isFilipino ? 'Ipadala' : 'Send',
            child: IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
