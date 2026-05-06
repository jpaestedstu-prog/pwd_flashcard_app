import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/avatar_data.dart';
import '../../../providers/app_providers.dart';

/// Gamified home for the Child role.
///
/// Designed for younger learners than the Student `HomeScreen`: bigger
/// targets, more emoji, fewer words. The deeper learning content is
/// reused from the existing routes (`/games`, `/flashcards`, `/stories`,
/// `/sticker-album`) so we don't fork the content layer — only the entry
/// surface differs.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatar = AvatarData.getAvatar(profile?.avatarIndex ?? 0);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Greeting strip ──────────────────────
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: avatar.color.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${profile?.name ?? "Friend"}!',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'What do you want to do today?',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── 2x2 tile grid ───────────────────────
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _ChildTile(
                      emoji: '🎮',
                      label: 'Play',
                      color: const Color(0xFFFFCC80),
                      onTap: () => context.push('/games'),
                    ),
                    _ChildTile(
                      emoji: '🔤',
                      label: 'Words',
                      color: const Color(0xFF90CAF9),
                      onTap: () => context.push('/flashcards'),
                    ),
                    _ChildTile(
                      emoji: '📖',
                      label: 'Stories',
                      color: const Color(0xFFCE93D8),
                      onTap: () => context.push('/stories'),
                    ),
                    _ChildTile(
                      emoji: '⭐',
                      label: 'Stickers',
                      color: const Color(0xFFA5D6A7),
                      onTap: () => context.push('/sticker-album'),
                    ),
                  ],
                ),
              ),

              // ─── Footer: small parent-only switch profile entry ──
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => context.push('/profile-switcher'),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Switch profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ChildTile({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
