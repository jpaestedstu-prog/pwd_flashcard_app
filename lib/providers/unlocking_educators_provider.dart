import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_service.dart';
import '../data/models/models.dart';

/// List of parent/teacher profiles whose PIN can dismiss the
/// "Time's Up" lock for one child.
///
/// Joins through cached classroom memberships and home-group
/// memberships. Returns the union, deduped by profile id. If no
/// educator profile is cached on this device, returns empty — the
/// lock-screen UI shows a "No educators linked" fallback in that case.
///
/// Hive-only: relies on educator profiles already being cached on
/// this device (which is true once the child has joined a classroom
/// or home group via code, since both flows fetch and cache the owner
/// profile). A Firestore-backed variant can be added later if a fully
/// fresh device needs to unlock without ever syncing.
final unlockingEducatorsProvider =
    FutureProvider.family<List<UserProfile>, String>(
  (ref, childProfileId) async {
    return HiveService.getEducatorsLinkedToChild(childProfileId);
  },
);
