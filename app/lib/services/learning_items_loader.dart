import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blogmae_entry.dart';
import '../utils/env_config.dart';

/// Supabase `lessons`（コース5件のうち1件）に紐づく `learning_items` を取得する。
class LearningItemsLoader {
  LearningItemsLoader._();

  static const courseBasic = 'basic';
  static const courseBeginner = 'beginner';
  static const courseParticiple = 'participle';
  static const courseIntermediate = 'intermediate';
  static const courseAdvanced = 'advanced';

  static Future<List<BlogmaeEntry>> loadForCourse(String courseKey) async {
    if (!EnvConfig.hasSupabase) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。'
        'app/.env.example を参照し --dart-define-from-file=.env で起動してください。',
      );
    }

    final rows = await Supabase.instance.client
        .from('lessons')
        .select('learning_items(grammar, english, japanese, item_number)')
        .eq('course_key', courseKey)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return [];

    final rawItems = list.first['learning_items'];
    if (rawItems == null) return [];

    final items = List<Map<String, dynamic>>.from(rawItems as List);
    items.sort((a, b) {
      final sa = a['item_number'];
      final sb = b['item_number'];
      final ia = sa is int ? sa : (sa as num).toInt();
      final ib = sb is int ? sb : (sb as num).toInt();
      return ia.compareTo(ib);
    });

    final out = <BlogmaeEntry>[];
    for (final m in items) {
      final n = m['item_number'];
      final id = n is int ? n : (n as num).toInt();
      out.add(
        BlogmaeEntry(
          id: id,
          grammar: (m['grammar'] ?? '').toString(),
          english: (m['english'] ?? '').toString(),
          japanese: (m['japanese'] ?? '').toString(),
        ),
      );
    }
    return out;
  }
}
