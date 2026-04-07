import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/env_config.dart';

/// `learning_item_attempts` への記録・リセット。
class LearningProgressService {
  LearningProgressService._();

  static void _ensureSupabase() {
    if (!EnvConfig.hasSupabase) {
      throw StateError('Supabase が未設定です。');
    }
  }

  static Future<void> recordAttempt({
    required int learningItemId,
    required int score,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('learning_item_attempts').insert({
      'user_id': user.id,
      'learning_item_id': learningItemId,
      'score': score.clamp(0, 100),
    });
  }

  /// [course_key] に紐づく全設問について、ログインユーザーの採点履歴を削除する。
  static Future<void> resetScoresForCourseKey(String courseKey) async {
    _ensureSupabase();
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('ログインが必要です。');

    final rows = await client
        .from('lessons')
        .select('learning_items(id)')
        .eq('course_key', courseKey)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return;

    final rawItems = list.first['learning_items'];
    if (rawItems == null) return;

    final items = List<Map<String, dynamic>>.from(rawItems as List);
    final ids = <int>[];
    for (final m in items) {
      final idRaw = m['id'];
      if (idRaw == null) continue;
      ids.add(idRaw is int ? idRaw : (idRaw as num).toInt());
    }
    if (ids.isEmpty) return;

    await client
        .from('learning_item_attempts')
        .delete()
        .eq('user_id', user.id)
        .inFilter('learning_item_id', ids);
  }
}
