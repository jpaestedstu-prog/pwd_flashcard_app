import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../providers/mood_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/mood_context.dart';
import '../models/mood_models.dart';
import '../models/mood_presentation.dart';
import '../widgets/mood_face.dart';

class MoodCheckInScreen extends ConsumerStatefulWidget {
  /// The moment being checked in on. Persisted with the entry so the Mood
  /// Insights dashboard can tell "after a game" apart from "anytime".
  final MoodContext moodContext;

  const MoodCheckInScreen({
    super.key,
    this.moodContext = MoodContext.general,
  });

  @override
  ConsumerState<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends ConsumerState<MoodCheckInScreen> {
  MoodType? _selectedMood;
  final _noteController = TextEditingController();
  bool _saving = false;

  /// The entry being corrected, when the learner chose to change a mood they
  /// already logged today. Null for a fresh check-in.
  MoodEntry? _editing;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    if (_selectedMood == null || _saving) return;
    setState(() => _saving = true);

    final note = _noteController.text.trim();
    final editing = _editing;
    try {
      if (editing != null) {
        await ref.read(moodProvider.notifier).updateMood(
              editing.id,
              _selectedMood!,
              note: note.isNotEmpty ? note : null,
            );
      } else {
        await ref.read(moodProvider.notifier).addMood(
              mood: _selectedMood!,
              note: note.isNotEmpty ? note : null,
              context: widget.moodContext,
            );
      }
    } catch (_) {
      // Leave the learner on the screen with their choice intact rather than
      // popping as though the mood had been saved.
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(
          context,
          message: ref.read(settingsProvider).locale == 'fil'
              ? 'Hindi na-save ang mood. Subukan ulit.'
              : 'Could not save your mood. Please try again.',
        );
      }
      return;
    }

    ref.read(hapticServiceProvider).success();

    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final presentation = ref.read(moodPresentationProvider);
    final moodLabel = _selectedMood!.labelOf(isFilipino: isFilipino);

    if (presentation.speakSelection) {
      // Fire and forget — a learner should never wait on the speaker.
      final spoken = isFilipino
          ? 'Na-save. Ang pakiramdam mo ay $moodLabel.'
          : 'Saved. You are feeling $moodLabel.';
      ref.read(ttsServiceProvider).speak(spoken);
    }

    AppSnackBar.success(
      context,
      message: isFilipino
          ? 'Na-record ang mood! ${_selectedMood!.emoji}'
          : 'Mood recorded! ${_selectedMood!.emoji}',
    );
    context.pop();
  }

  /// Switch into "correct what I logged" mode, pre-selecting the existing
  /// mood and note so the learner edits rather than starts over.
  void _editExisting(MoodEntry entry) {
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _editing = entry;
      _selectedMood = entry.mood;
      _noteController.text = entry.note ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final presentation = ref.watch(moodPresentationProvider);

    // Watched so the "already checked in" card appears the moment an entry
    // lands, including one saved from the post-game prompt.
    ref.watch(moodProvider);
    final todaysMood = ref.read(moodProvider.notifier).todaysMood;
    final showTodayCard = todaysMood != null && _editing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Paano ang Pakiramdam Mo?' : 'How Are You Feeling?'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ─── Today's check-in, if there is one ──────
              if (showTodayCard) ...[
                _TodaysMoodCard(
                  entry: todaysMood,
                  isFilipino: isFilipino,
                  onChange: () => _editExisting(todaysMood),
                ),
                const SizedBox(height: 20),
              ],
              // Prompt text — names the moment, so an "after a game" reading
              // asks about the game rather than about life in general.
              Text(
                showTodayCard
                    ? (isFilipino
                        ? 'Gusto mo bang magdagdag ng bagong check-in?'
                        : 'Want to add another check-in?')
                    : widget.moodContext.promptOf(isFilipino: isFilipino),
                style: AppTypography.bodyLarge.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate(target: presentation.animate ? 1 : 0).fadeIn(duration: 300.ms),
              const SizedBox(height: 28),
              // ─── Mood grid ──────
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: presentation.choices.map((mood) {
                  return MoodFace(
                    mood: mood,
                    isSelected: _selectedMood == mood,
                    isFilipino: isFilipino,
                    onTap: () {
                      ref.read(hapticServiceProvider).lightTap();
                      setState(() => _selectedMood = mood);
                    },
                  );
                }).toList(),
              )
                  .animate(target: presentation.animate ? 1 : 0)
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 28),
              // ─── Note + save ──────
              if (_selectedMood != null) ...[
                if (presentation.showNote) ...[
                  Semantics(
                    label: isFilipino
                        ? 'Opsyonal na tala tungkol sa pakiramdam mo'
                        : 'Optional note about how you feel',
                    child: TextField(
                      controller: _noteController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: isFilipino
                            ? 'Isulat kung bakit ganyan ang pakiramdam mo (opsyonal)...'
                            : 'Write why you feel this way (optional)...',
                        filled: true,
                        fillColor: hc.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: hc.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: hc.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _selectedMood!.darkColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ).animate(target: presentation.animate ? 1 : 0).fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                ],
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Semantics(
                    button: true,
                    label: _editing != null
                        ? (isFilipino ? 'I-update ang mood' : 'Update mood')
                        : (isFilipino ? 'I-save ang mood' : 'Save mood'),
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveMood,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_selectedMood!.emoji,
                              style: const TextStyle(fontSize: 22)),
                      label: Text(
                        _editing != null
                            ? (isFilipino ? 'I-update ang Mood' : 'Update My Mood')
                            : (isFilipino ? 'I-save ang Mood' : 'Save My Mood'),
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        // `darkColor`, not `color`: the label is white, and
                        // white on the pale happy / tired swatches fails
                        // contrast badly on exactly the profiles that can
                        // least afford it.
                        backgroundColor: _selectedMood!.darkColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),
                ).animate(target: presentation.animate ? 1 : 0).fadeIn(duration: 300.ms, delay: 100.ms),
              ],
              const SizedBox(height: 16),
              // View history link
              TextButton.icon(
                onPressed: () => context.push('/mood-history'),
                icon: const Icon(Icons.history_rounded),
                label: Text(isFilipino ? 'Tingnan ang Kasaysayan' : 'View Mood History'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// What the learner already logged today, with a way to correct it.
///
/// Without this the screen greeted a learner who had checked in an hour ago
/// with a blank grid, as though the day had not happened — and a mis-tapped
/// face could only be answered by logging a second, contradicting entry.
class _TodaysMoodCard extends StatelessWidget {
  final MoodEntry entry;
  final bool isFilipino;
  final VoidCallback onChange;

  const _TodaysMoodCard({
    required this.entry,
    required this.isFilipino,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final moodLabel = entry.mood.labelOf(isFilipino: isFilipino);
    final moodContext = MoodContextX.fromKey(entry.activityContext);

    return Semantics(
      label: isFilipino
          ? 'Ngayong araw, ang pakiramdam mo ay $moodLabel'
          : 'Today you felt $moodLabel',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: entry.mood.darkColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(entry.mood.emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFilipino
                        ? 'Ngayong araw: $moodLabel'
                        : 'Today: $moodLabel',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moodContext.labelOf(isFilipino: isFilipino),
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onChange,
              child: Text(isFilipino ? 'Palitan' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }
}
