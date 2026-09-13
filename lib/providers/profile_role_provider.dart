import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_service.dart';
import '../data/models/enums.dart';
import 'app_providers.dart';

/// The [UserRole] of the profile with [profileId], or null when this device
/// has never heard of them.
///
/// The active profile answers for itself — it is already in memory and it is
/// the only one guaranteed to be current — and anyone else is looked up in the
/// local mirror. Null is a real answer, not an error: a guest Player is never
/// written to Hive, and "unknown role" must therefore degrade to "no
/// supervision applies" rather than to a crash or, worse, to a lock.
///
/// Exists so `lockStateProvider` can tell a Student from a Player without
/// pulling the whole profile into a provider that recomputes every ten
/// seconds.
final profileRoleProvider = Provider.family<UserRole?, String>((
  ref,
  profileId,
) {
  final active = ref.watch(profileProvider);
  if (active != null && active.id == profileId) return active.role;
  try {
    return HiveService.getProfileById(profileId)?.role;
  } catch (_) {
    return null;
  }
});
