/// 1 問。`id` はコース内の `item_number`（元 CSV の id）。
class BlogmaeEntry {
  const BlogmaeEntry({
    required this.id,
    required this.grammar,
    required this.english,
    required this.japanese,
  });

  final int id;
  final String grammar;
  final String english;
  final String japanese;
}
