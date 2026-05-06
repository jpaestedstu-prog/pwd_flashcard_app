import 'package:flutter/material.dart';

/// A seasonal event with date range, theme colors, and visual config.
class SeasonalEvent {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final DateTimeRange dateRange;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<String> decorationEmojis;
  final String? bannerGradientStart;

  const SeasonalEvent({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.dateRange,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.decorationEmojis,
    this.bannerGradientStart,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(dateRange.start) && now.isBefore(dateRange.end);
  }

  /// Days remaining until the event ends. 0 if not active.
  int get daysRemaining {
    if (!isActive) return 0;
    return dateRange.end.difference(DateTime.now()).inDays;
  }
}

/// All seasonal events for the current calendar year.
///
/// Events are date-bounded — only one is typically active at a time.
/// If none is active, no seasonal decorations are shown.
class SeasonalEvents {
  SeasonalEvents._();

  static int get _year => DateTime.now().year;

  static List<SeasonalEvent> get allEvents => [
    // ─── Valentines / Hearts Week ──────────────────
    SeasonalEvent(
      id: 'valentines',
      name: 'Hearts Week',
      emoji: '💖',
      description: 'Spread love and learn together!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 2, 10),
        end: DateTime(_year, 2, 16),
      ),
      primaryColor: const Color(0xFFE91E63),
      secondaryColor: const Color(0xFFF48FB1),
      accentColor: const Color(0xFFFCE4EC),
      decorationEmojis: ['💖', '💕', '❤️', '🌹', '💝'],
    ),

    // ─── Filipino Language Month (August) ──────────
    SeasonalEvent(
      id: 'buwan_ng_wika',
      name: 'Buwan ng Wika',
      emoji: '🇵🇭',
      description: 'Celebrate Filipino language and culture!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 8),
        end: DateTime(_year, 8, 31),
      ),
      primaryColor: const Color(0xFF1565C0),
      secondaryColor: const Color(0xFFE53935),
      accentColor: const Color(0xFFFFD54F),
      decorationEmojis: ['🇵🇭', '🌺', '🎋', '⭐', '🎵'],
    ),

    // ─── Back to School (June) ─────────────────────
    SeasonalEvent(
      id: 'back_to_school',
      name: 'Back to School',
      emoji: '📚',
      description: 'A new school year begins!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 6),
        end: DateTime(_year, 6, 15),
      ),
      primaryColor: const Color(0xFF43A047),
      secondaryColor: const Color(0xFF66BB6A),
      accentColor: const Color(0xFFC8E6C9),
      decorationEmojis: ['📚', '✏️', '🎒', '📖', '🍎'],
    ),

    // ─── Halloween Fun ─────────────────────────────
    SeasonalEvent(
      id: 'halloween',
      name: 'Spooky Learn',
      emoji: '🎃',
      description: 'Fun and friendly Halloween learning!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 10, 25),
        end: DateTime(_year, 11, 2),
      ),
      primaryColor: const Color(0xFFFF6F00),
      secondaryColor: const Color(0xFF7B1FA2),
      accentColor: const Color(0xFFFFCC80),
      decorationEmojis: ['🎃', '👻', '🦇', '🕸️', '🍬'],
    ),

    // ─── Christmas / Holiday Season ────────────────
    SeasonalEvent(
      id: 'christmas',
      name: 'Holiday Season',
      emoji: '🎄',
      description: 'Happy holidays and joyful learning!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 12, 15),
        end: DateTime(_year + 1, 1, 3),
      ),
      primaryColor: const Color(0xFFC62828),
      secondaryColor: const Color(0xFF2E7D32),
      accentColor: const Color(0xFFFFD54F),
      decorationEmojis: ['🎄', '🎅', '⭐', '🎁', '❄️'],
    ),

    // ─── New Year Celebration ──────────────────────
    SeasonalEvent(
      id: 'new_year',
      name: 'New Year!',
      emoji: '🎉',
      description: 'Welcome the new year of learning!',
      dateRange: DateTimeRange(
        start: DateTime(_year),
        end: DateTime(_year, 1, 7),
      ),
      primaryColor: const Color(0xFF6A1B9A),
      secondaryColor: const Color(0xFFFF6F00),
      accentColor: const Color(0xFFFFD54F),
      decorationEmojis: ['🎉', '🎊', '✨', '🥳', '🎆'],
    ),

    // ─── Earth Day / Nature Week ───────────────────
    SeasonalEvent(
      id: 'earth_day',
      name: 'Nature Week',
      emoji: '🌍',
      description: 'Learn about nature and our planet!',
      dateRange: DateTimeRange(
        start: DateTime(_year, 4, 20),
        end: DateTime(_year, 4, 27),
      ),
      primaryColor: const Color(0xFF2E7D32),
      secondaryColor: const Color(0xFF1565C0),
      accentColor: const Color(0xFFA5D6A7),
      decorationEmojis: ['🌍', '🌱', '🌻', '🦋', '🌈'],
    ),
  ];

  /// The currently active event, or null.
  static SeasonalEvent? get activeEvent {
    try {
      return allEvents.firstWhere((e) => e.isActive);
    } catch (_) {
      return null;
    }
  }
}
