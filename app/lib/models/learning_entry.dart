/// 1 問。`learningItemId` は DB の `learning_items.id`。
/// `id` は表示用のコース内 `item_number`（元 CSV の id）。
class LearningEntry {
  const LearningEntry({
    required this.learningItemId,
    required this.id,
    required this.grammar,
    required this.english,
    required this.japanese,
  });

  final int learningItemId;
  final int id;
  final String grammar;
  final String english;
  final String japanese;
}
