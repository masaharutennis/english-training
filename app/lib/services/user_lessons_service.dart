import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_list_row.dart';
import '../utils/env_config.dart';

/// ユーザーレッスンの作成・一覧・問題追加。
class UserLessonsService {
  UserLessonsService._();

  static String _newUserCourseKey() {
    final r = Random.secure();
    String h(int n) => List.generate(
          n,
          (_) => '0123456789abcdef'[r.nextInt(16)],
        ).join();
    return 'user:${h(8)}-${h(4)}-${h(4)}-${h(4)}-${h(12)}';
  }

  static void _ensureSupabase() {
    if (!EnvConfig.hasSupabase) {
      throw StateError('Supabase が未設定です。');
    }
  }

  /// RLS の範囲で見える lessons を返す（公式 → ユーザーの順、日付は新しい順）。
  static Future<List<LessonListRow>> fetchLessonList() async {
    _ensureSupabase();
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await client.from('lessons').select(
          'course_key, title, lesson_kind, visibility, created_by, sort_order, created_at',
        );

    final list = List<Map<String, dynamic>>.from(rows as List);
    final out = list.map((m) => _rowToLesson(m, uid)).toList();
    out.sort(_compareRows);
    return out;
  }

  static LessonListRow _rowToLesson(Map<String, dynamic> m, String uid) {
    final kind = (m['lesson_kind'] ?? 'system').toString();
    final createdBy = m['created_by']?.toString();
    final isOwner = createdBy != null && createdBy == uid;
    final createdAtRaw = m['created_at']?.toString();
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);
    final so = m['sort_order'];
    final sortOrder = so is int ? so : (so as num?)?.toInt() ?? 0;
    return LessonListRow(
      courseKey: (m['course_key'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      lessonKind: kind,
      visibility: m['visibility']?.toString(),
      isOwner: isOwner,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }

  static int _compareRows(LessonListRow a, LessonListRow b) {
    if (a.isSystem != b.isSystem) {
      return a.isSystem ? -1 : 1;
    }
    if (a.isSystem && b.isSystem) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  /// 新規ユーザーレッスン。返り値は `course_key`（デッキ画面と同一キーで読み込み）。
  static Future<String> createUserLesson({
    required String title,
    required String visibility,
  }) async {
    _ensureSupabase();
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('ログインが必要です。');

    final courseKey = _newUserCourseKey();
    await client.from('lessons').insert({
      'course_key': courseKey,
      'title': title.trim().isEmpty ? 'マイレッスン' : title.trim(),
      'sort_order': 0,
      'lesson_kind': 'user',
      'created_by': user.id,
      'visibility': visibility,
    });
    return courseKey;
  }

  static Future<String?> fetchVisibility(String courseKey) async {
    _ensureSupabase();
    final rows = await Supabase.instance.client
        .from('lessons')
        .select('visibility')
        .eq('course_key', courseKey)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return null;
    return list.first['visibility']?.toString();
  }

  static Future<void> updateLessonVisibility({
    required String courseKey,
    required String visibility,
  }) async {
    _ensureSupabase();
    await Supabase.instance.client
        .from('lessons')
        .update({'visibility': visibility})
        .eq('course_key', courseKey)
        .eq('lesson_kind', 'user');
  }

  /// 自作レッスンごと削除（`learning_items` は CASCADE、採点履歴も紐づく問題経由で消える）。
  static Future<void> deleteUserLesson(String courseKey) async {
    _ensureSupabase();
    await Supabase.instance.client
        .from('lessons')
        .delete()
        .eq('course_key', courseKey)
        .eq('lesson_kind', 'user');
  }

  static Future<int> _resolveLessonId(String courseKey) async {
    final rows = await Supabase.instance.client
        .from('lessons')
        .select('id')
        .eq('course_key', courseKey)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw StateError('レッスンが見つかりません。');
    final idRaw = list.first['id'];
    return idRaw is int ? idRaw : (idRaw as num).toInt();
  }

  /// 次の `item_number` で 1 問追加。
  static Future<void> addLearningItem({
    required String courseKey,
    required String grammar,
    required String english,
    required String japanese,
  }) async {
    _ensureSupabase();
    final client = Supabase.instance.client;
    final lessonId = await _resolveLessonId(courseKey);

    final existing = await client
        .from('learning_items')
        .select('item_number')
        .eq('lesson_id', lessonId)
        .order('item_number', ascending: false)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(existing as List);
    final nextNum = list.isEmpty
        ? 1
        : () {
            final n = list.first['item_number'];
            final i = n is int ? n : (n as num).toInt();
            return i + 1;
          }();

    await client.from('learning_items').insert({
      'lesson_id': lessonId,
      'item_number': nextNum,
      'grammar': grammar.trim(),
      'english': english.trim(),
      'japanese': japanese.trim(),
    });
  }

  /// 自作レッスン内の 1 問を更新（RLS: 自分の user レッスンのみ）。
  static Future<void> updateLearningItem({
    required int learningItemId,
    required String grammar,
    required String english,
    required String japanese,
  }) async {
    _ensureSupabase();
    await Supabase.instance.client.from('learning_items').update({
      'grammar': grammar.trim(),
      'english': english.trim(),
      'japanese': japanese.trim(),
    }).eq('id', learningItemId);
  }

  static Future<void> deleteLearningItem(int learningItemId) async {
    _ensureSupabase();
    await Supabase.instance.client.from('learning_items').delete().eq('id', learningItemId);
  }
}
