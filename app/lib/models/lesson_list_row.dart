/// 教材一覧用の 1 行（公式 / ユーザーオリジナル）。
class LessonListRow {
  const LessonListRow({
    required this.courseKey,
    required this.title,
    required this.lessonKind,
    this.visibility,
    required this.isOwner,
    required this.sortOrder,
    required this.createdAt,
  });

  final String courseKey;
  final String title;
  /// `system` | `user`
  final String lessonKind;
  /// user のみ `public` / `private`
  final String? visibility;
  final bool isOwner;
  final int sortOrder;
  final DateTime createdAt;

  bool get isSystem => lessonKind == 'system';
}
