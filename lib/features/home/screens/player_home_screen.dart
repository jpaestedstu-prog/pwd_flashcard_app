import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/avatar_data.dart';
import '../../../providers/app_providers.dart';

/// Minimal home for the Player (guest) role.
///
/// Player profiles never sync to Firestore — everything stays in-memory
/// and Hive — so this screen avoids any list-of-content widgets and any
/// remote provider subscription. Just an avatar, a greeting, one big
/// "Start" call-to-action, and a "Sign up to save your progress" hook
/// that funnels the user into the regular profile-selection flow.
class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar circle
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      AvatarData.getAvatar(profile?.avatarIndex ?? 0).emoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Hi, ${profile?.name ?? "Player"}!',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re in Player mode. Your fun stays on this device.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ▶ Start Learning
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleLarge,
                ),
                onPressed: () => context.push('/games'),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                label: const Text('Start Learning'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/flashcards'),
                icon: const Icon(Icons.style_rounded),
                label: const Text('Browse flashcards'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/smileyometer'),
                icon: const Icon(Icons.emoji_emotions_outlined),
                label: const Text('How was it?'),
              ),

              const Spacer(),

              // Save-progress hook
              Card(
                color: colors.tertiaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Save your stars across devices',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join a class or home group to back up your '
                        'progress and learn with others.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/join-class'),
                              child: const Text('Join class'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  context.push('/join-home-group'),
                              child: const Text('Join group'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/profile-switcher'),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Switch profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
