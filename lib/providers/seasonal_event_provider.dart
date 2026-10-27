import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/data/models/seasonal_events.dart';

/// Provides the currently active seasonal event (or null).
///
/// This is a simple provider that checks the calendar date.
/// Widgets can watch it to conditionally render seasonal decorations.
final seasonalEventProvider = Provider<SeasonalEvent?>((ref) {
  return SeasonalEvents.activeEvent;
});

/// Whether the learner closed the seasonal banner this session.
///
/// Held here rather than in the banner so Home can tell the D-pad whether
/// the banner's close button is on the page: a gaze or controller learner
/// reaches it as Home's top row, and only while it shows.
final seasonalBannerDismissedProvider = StateProvider<bool>((ref) => false);

/// The seasonal banner is on Home right now.
final seasonalBannerShownProvider = Provider<bool>(
  (ref) =>
      ref.watch(seasonalEventProvider) != null &&
      !ref.watch(seasonalBannerDismissedProvider),
);
