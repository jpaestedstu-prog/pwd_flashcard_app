import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../models/recommendation_models.dart';
import '../services/recommendation_service.dart';

/// Provider that produces the [RecommendationSnapshot] for the active user.
///
/// It watches [progressProvider] and [learningPathProvider] so the
/// recommendations automatically refresh when the student completes an
/// activity.
final recommendationProvider = Provider<RecommendationSnapshot>((ref) {
  final profile = ref.watch(profileProvider);
  final progress = ref.watch(progressProvider);
  final pathProgress = ref.watch(learningPathProvider);

  if (profile == null) {
    return RecommendationSnapshot(
      recommendations: [],
      wordsNeedingReview: 0,
      categoriesExplored: 0,
      totalCategories: 12,
      overallAccuracy: 0,
      generatedAt: DateTime.now(),
    );
  }

  return RecommendationService.generate(
    profileId: profile.id,
    progress: progress,
    pathProgress: pathProgress,
    interests: profile.interests,
  );
});
