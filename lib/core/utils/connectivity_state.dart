import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether a `connectivity_plus` reading should be shown to the user as
/// "offline".
///
/// Two traps live here.
///
/// **`every` is vacuously true on an empty list.** `results.every((r) => r ==
/// none)` reports *offline* when the plugin hands back an empty list, which it
/// can do when the platform has not settled on a transport yet. An empty
/// reading means "not known", and the honest thing to tell someone about a
/// state you do not know is nothing.
///
/// **This is transport availability, not reachability.** A device attached to
/// wifi with no route to the internet still reads as online here. That is the
/// right trade for a banner — the app is local-first and genuinely does keep
/// working — but it is why nothing in the sync layer decides anything from
/// this: those paths find out by trying and timing out.
///
/// Gates that merely *choose a fallback* may be stricter and treat an unknown
/// reading as offline (see the AI tutor and companion, which prefer a local
/// answer to a hung request). Only claims made to the user route through here,
/// because being silent costs nothing and being wrong costs trust.
bool isOfflineForDisplay(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.every((r) => r == ConnectivityResult.none);
}
