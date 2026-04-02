/// ブログ前ベーシック CSV（id, grammar, english, japanese）の1行。
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
