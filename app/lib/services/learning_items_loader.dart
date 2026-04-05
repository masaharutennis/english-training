import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blogmae_entry.dart';
import '../utils/env_config.dart';
import 'quiz_picker.dart';

/// Supabase `lessons` / `learning_items` の取得とクイズ用サンプリング。
class LearningItemsLoader {
  LearningItemsLoader._();

  static const courseBasic = 'basic';
  static const courseBeginner = 'beginner';
  static const courseParticiple = 'participle';
  static const courseIntermediate = 'intermediate';
  static const courseAdvanced = 'advanced';

  /// 1 セッションあたりの出題数。
  static const int quizSize = 10;

  static Future<List<BlogmaeEntry>> loadForCourse(String courseKey) =>
      loadQuizForCourse(courseKey);

  /// コース内の全問を取得（`item_number` 昇順）。
  static Future<List<BlogmaeEntry>> loadAllForCourse(String courseKey) async {
    _ensureSupabase();
    final rows = await Supabase.instance.client
        .from('lessons')
        .select(
          'learning_items(id, grammar, english, japanese, item_number)',
        )
        .eq('course_key', courseKey)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return [];

    final rawItems = list.first['learning_items'];
    if (rawItems == null) return [];

    final items = List<Map<String, dynamic>>.from(rawItems as List);
    items.sort((a, b) {
      final ia = _asInt(a['item_number']);
      final ib = _asInt(b['item_number']);
      return ia.compareTo(ib);
    });

    return items.map(_rowToEntry).toList();
  }

  /// 低スコアほど出やすい重み付きで最大 [quizSize] 問。
  static Future<List<BlogmaeEntry>> loadQuizForCourse(String courseKey) async {
    final all = await loadAllForCourse(courseKey);
    if (all.isEmpty) return [];
    final ids = all.map((e) => e.learningItemId).toSet();
    final last = await _fetchLastScores(ids);
    return QuizPicker.pickWeighted(all, last, quizSize);
  }

  /// 未学習は 0、各問の直近スコアの平均（0〜100）。
  static Future<double> averageScoreForCourse(String courseKey) async {
    final all = await loadAllForCourse(courseKey);
    if (all.isEmpty) return 0;
    final last = await _fetchLastScores(all.map((e) => e.learningItemId).toSet());
    var sum = 0;
    for (final e in all) {
      sum += last[e.learningItemId] ?? 0;
    }
    return sum / all.length;
  }

  static void _ensureSupabase() {
    if (!EnvConfig.hasSupabase) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。'
        'app/.env.example を参照し --dart-define-from-file=.env で起動してください。',
      );
    }
  }

  static BlogmaeEntry _rowToEntry(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final learningItemId = idRaw is int ? idRaw : (idRaw as num).toInt();
    final n = m['item_number'];
    final itemNumber = n is int ? n : (n as num).toInt();
    return BlogmaeEntry(
      learningItemId: learningItemId,
      id: itemNumber,
      grammar: (m['grammar'] ?? '').toString(),
      english: (m['english'] ?? '').toString(),
      japanese: (m['japanese'] ?? '').toString(),
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// 各 `learning_item_id` の最新スコア（`created_at` 降順で先勝ち）。
  static Future<Map<int, int>> _fetchLastScores(Set<int> learningItemIds) async {
    if (learningItemIds.isEmpty) return {};
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};

    final idList = learningItemIds.toList();
    final rows = await Supabase.instance.client
        .from('learning_item_attempts')
        .select('learning_item_id, score, created_at')
        .eq('user_id', user.id)
        .inFilter('learning_item_id', idList)
        .order('created_at', ascending: false);

    final out = <int, int>{};
    for (final r in List<Map<String, dynamic>>.from(rows as List)) {
      final lidRaw = r['learning_item_id'];
      final lid = lidRaw is int ? lidRaw : (lidRaw as num).toInt();
      if (out.containsKey(lid)) continue;
      final sRaw = r['score'];
      out[lid] = sRaw is int ? sRaw : (sRaw as num).toInt();
    }
    return out;
  }
}
