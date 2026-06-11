import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../services/claude_brain.dart';
import '../services/tutor_brain_settings.dart';

/// Educator-only configuration for the LLM tutor brain ("smart replies").
/// Reached from the AI Tutor app bar; only teacher/parent profiles see the
/// entry point, and the screen itself re-checks the role.
class TutorBrainSettingsScreen extends ConsumerStatefulWidget {
  const TutorBrainSettingsScreen({super.key});

  @override
  ConsumerState<TutorBrainSettingsScreen> createState() =>
      _TutorBrainSettingsScreenState();
}

class _TutorBrainSettingsScreenState
    extends ConsumerState<TutorBrainSettingsScreen> {
  late final TextEditingController _keyController;
  bool _obscureKey = true;

  static const _capChoices = [20, 40, 100];

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: TutorBrainSettings.apiKey);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final role = ref.watch(profileProvider)?.role;
    final isEducator = role == UserRole.teacher || role == UserRole.parent;

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Replies (AI Tutor)')),
      body: SafeArea(
        child: !isEducator
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Text(
                    'Ask your teacher or parent to set this up. 😊',
                    style: AppTypography.titleMedium
                        .copyWith(color: hc.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  Text(
                    'When enabled and online, the learning buddy answers with '
                    'Claude AI, grounded in the student\'s real progress. '
                    'Offline or on any error it falls back to the built-in '
                    'buddy automatically — students never see an error.',
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Enable smart replies'),
                    subtitle: const Text('Requires an Anthropic API key'),
                    value: TutorBrainSettings.isEnabled,
                    onChanged: (v) async {
                      await TutorBrainSettings.setEnabled(v);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Anthropic API key',
                      hintText: 'sk-ant-…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    onSubmitted: (v) => _saveKey(v),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _saveKey(_keyController.text),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save key'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Model', style: AppTypography.titleSmall),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: TutorBrainSettings.model,
                    items: [
                      for (final e in ClaudeBrain.supportedModels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await TutorBrainSettings.setModel(v);
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Daily limit', style: AppTypography.titleSmall),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    segments: [
                      for (final c in _capChoices)
                        ButtonSegment(value: c, label: Text('$c/day')),
                    ],
                    selected: {
                      _capChoices.contains(TutorBrainSettings.dailyCap)
                          ? TutorBrainSettings.dailyCap
                          : TutorBrainSettings.defaultDailyCap,
                    },
                    onSelectionChanged: (sel) async {
                      await TutorBrainSettings.setDailyCap(sel.first);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${TutorBrainSettings.turnsToday} of '
                    '${TutorBrainSettings.dailyCap} smart replies used today.',
                    style: AppTypography.bodySmall
                        .copyWith(color: hc.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Safety: the buddy is pinned to vocabulary, FSL practice '
                      'and encouragement only; quizzes are always built and '
                      'graded by the app, never by the AI. The key is stored '
                      'in this app\'s private storage on this device only — '
                      'use a key you can revoke, and keep the daily limit on.',
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveKey(String value) async {
    await TutorBrainSettings.setApiKey(value);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved on this device.')),
    );
  }
}
