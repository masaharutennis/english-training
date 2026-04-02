import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/blogmae_entry.dart';

/// BlogMAE 用 CSV（`assets/data/*.csv`）を読み込む。
class BlogmaeBasicLoader {
  static const basicAssetPath = 'assets/data/blogmae_basic.csv';
  static const beginnerAssetPath = 'assets/data/blogmae_beginner.csv';
  /// pronunciation1-2（分詞と関係代名詞編）
  static const participleAssetPath = 'assets/data/blogmae_participle.csv';
  static const intermediateAssetPath = 'assets/data/blogmae_intermediate.csv';
  static const advancedAssetPath = 'assets/data/blogmae_advanced.csv';

  static Future<List<BlogmaeEntry>> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(raw.trim());

    if (rows.isEmpty) return [];

    final header = rows.first.map((c) => c.toString().trim()).toList();
    final col = _columnIndex(header);
    if (col('id') == null) {
      throw const FormatException('CSV に id 列がありません');
    }

    final out = <BlogmaeEntry>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }
      out.add(_parseRow(row, col));
    }
    return out;
  }

  static int? Function(String) _columnIndex(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      map[header[i].toLowerCase()] = i;
    }
    int? idx(String key) => map[key.toLowerCase()];
    return idx;
  }

  static String _get(List<dynamic> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].toString().trim();
  }

  static BlogmaeEntry _parseRow(
    List<dynamic> row,
    int? Function(String name) col,
  ) {
    final id = int.tryParse(_get(row, col('id'))) ?? 0;
    final grammar = _get(row, col('grammar'));
    final english = _get(row, col('english'));
    final japanese = _get(row, col('japanese'));
    return BlogmaeEntry(
      id: id,
      grammar: grammar,
      english: english,
      japanese: japanese,
    );
  }
}
