import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/data/models/seasonal_events.dart';

/// Provides the currently active seasonal event (or null).
///
/// This is a simple provider that checks the calendar date.
/// Widgets can watch it to conditionally render seasonal decorations.
final seasonalEventProvider = Provider<SeasonalEvent?>((ref) {
  return SeasonalEvents.activeEvent;
});
