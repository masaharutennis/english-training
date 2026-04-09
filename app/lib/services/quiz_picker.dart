import 'dart:math';

import '../models/learning_entry.dart';

/// 直近スコアが低いほど選ばれやすい重み付き無作為抽出（最大 [maxCount] 問）。
class QuizPicker {
  QuizPicker._();

  static List<LearningEntry> pickWeighted(
    List<LearningEntry> items,
    Map<int, int> lastScoreByLearningItemId,
    int maxCount,
  ) {
    if (items.isEmpty) return [];
    if (items.length <= maxCount) {
      final copy = [...items]..shuffle(Random());
      return copy;
    }
    final weights = items
        .map(
          (e) {
            final s = lastScoreByLearningItemId[e.learningItemId] ?? 0;
            return max(1, 101 - s);
          },
        )
        .toList();
    final remaining = List<int>.generate(items.length, (i) => i);
    final rng = Random();
    final picked = <LearningEntry>[];
    for (var k = 0; k < maxCount && remaining.isNotEmpty; k++) {
      var total = 0;
      for (final i in remaining) {
        total += weights[i];
      }
      if (total <= 0) break;
      var r = rng.nextInt(total);
      var chosen = remaining.first;
      for (final i in remaining) {
        r -= weights[i];
        if (r < 0) {
          chosen = i;
          break;
        }
      }
      picked.add(items[chosen]);
      remaining.remove(chosen);
    }
    return picked;
  }
}
