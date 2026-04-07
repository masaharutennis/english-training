import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 模範英文とユーザー発話の **単語単位** の差分（相違部は赤）。
///
/// 差分は LCS ベースの **単語トークン列** のみで計算するため、
/// 1 単語の表示は常に **すべて同じ色**（一致なら通常、不一致ならすべて赤）。
///
/// 比較では次を無視します:
/// - 英字の大文字・小文字の違い
/// - アポストロフィの字形差
/// - コンマ・ピリオド・クエスチョンマーク・感嘆符・セミコロン・コロン・ダブルクォート
/// - 全角数字・全角英字 → 半角
///
/// 画面上の文字は元のまま表示します。
class EnglishAnswerDiff {
  EnglishAnswerDiff._();

  static const Color diffColor = Color(0xFFC62828);

  static const String _emptyKeyPlaceholder = '\uE000';

  static final RegExp _apostropheLike = RegExp(
    "[\\'\u2018\u2019\u201A\u201B\u02BC\u02B9\u055A\uFF07`´]",
  );
  static final RegExp _stripForCompare = RegExp(
    r'''[,.?!;:"]''',
  );

  /// 単語同士を比較するときの正規化キー（テストやデバッグ用にも利用可）。
  static String normalizeCompareKey(String raw) {
    final sb = StringBuffer();
    for (final r in raw.runes) {
      if (r >= 0xFF10 && r <= 0xFF19) {
        sb.writeCharCode(r - 0xFF10 + 0x30);
      } else if (r >= 0xFF21 && r <= 0xFF3A) {
        sb.writeCharCode(r - 0xFF21 + 0x41);
      } else if (r >= 0xFF41 && r <= 0xFF5A) {
        sb.writeCharCode(r - 0xFF41 + 0x61);
      } else {
        sb.writeCharCode(r);
      }
    }
    var s = sb.toString();
    s = s.replaceAll(_apostropheLike, "'");
    s = s.replaceAll(RegExp(r'[""„«»＂]'), '');
    s = s.replaceAll(_stripForCompare, '');
    if (s.isEmpty) return _emptyKeyPlaceholder;
    return s.toLowerCase();
  }

  static List<String> _rawWords(String s) {
    final t = s.trim();
    if (t.isEmpty) return [];
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static List<_WordTok> _wordToks(String s) {
    return _rawWords(s)
        .map((w) => _WordTok(w, normalizeCompareKey(w)))
        .toList();
  }

  /// 正規化キー列に対する単語単位の差分（常にトークン境界）。
  static List<_WordDiffOp> _diffKeys(List<String> km, List<String> ku) {
    final n = km.length;
    final m = ku.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        if (km[i] == ku[j]) {
          dp[i][j] = 1 + dp[i + 1][j + 1];
        } else {
          dp[i][j] = math.max(dp[i + 1][j], dp[i][j + 1]);
        }
      }
    }

    final ops = <_WordDiffOp>[];
    var im = 0;
    var iu = 0;
    while (im < n || iu < m) {
      if (im < n && iu < m && km[im] == ku[iu]) {
        ops.add(const _WordDiffOp.equal(1));
        im++;
        iu++;
      } else if (im == n) {
        ops.add(const _WordDiffOp.insert(1));
        iu++;
      } else if (iu == m) {
        ops.add(const _WordDiffOp.delete(1));
        im++;
      } else if (dp[im + 1][iu] >= dp[im][iu + 1]) {
        ops.add(const _WordDiffOp.delete(1));
        im++;
      } else {
        ops.add(const _WordDiffOp.insert(1));
        iu++;
      }
    }
    return _mergeWordOps(ops);
  }

  static List<_WordDiffOp> _mergeWordOps(List<_WordDiffOp> ops) {
    if (ops.isEmpty) return ops;
    final out = <_WordDiffOp>[ops.first];
    for (var i = 1; i < ops.length; i++) {
      final cur = ops[i];
      final last = out.last;
      if (last.kind == cur.kind) {
        out[out.length - 1] = _WordDiffOp(last.kind, last.count + cur.count);
      } else {
        out.add(cur);
      }
    }
    return out;
  }

  static List<TextSpan> spansForModel(
    String modelEnglish,
    String userEnglish,
    TextStyle baseStyle,
    Color normalColor,
  ) {
    final modelToks = _wordToks(modelEnglish);
    final userToks = _wordToks(userEnglish);
    final km = modelToks.map((t) => t.key).toList();
    final ku = userToks.map((t) => t.key).toList();
    final ops = _diffKeys(km, ku);
    final spans = _spansFromWordOps(
      ops: ops,
      modelToks: modelToks,
      userToks: userToks,
      baseStyle: baseStyle,
      normalColor: normalColor,
      isModelSide: true,
    );
    if (spans.isEmpty) {
      return [
        TextSpan(text: modelEnglish, style: baseStyle.copyWith(color: normalColor)),
      ];
    }
    return spans;
  }

  static List<TextSpan> spansForUser(
    String modelEnglish,
    String userEnglish,
    TextStyle baseStyle,
    Color normalColor,
  ) {
    final userToks = _wordToks(userEnglish);
    if (userToks.isEmpty) {
      return [
        TextSpan(
          text: '（空）',
          style: baseStyle.copyWith(
            color: normalColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    final modelToks = _wordToks(modelEnglish);
    final km = modelToks.map((t) => t.key).toList();
    final ku = userToks.map((t) => t.key).toList();
    final ops = _diffKeys(km, ku);
    final spans = _spansFromWordOps(
      ops: ops,
      modelToks: modelToks,
      userToks: userToks,
      baseStyle: baseStyle,
      normalColor: normalColor,
      isModelSide: false,
    );
    if (spans.isEmpty) {
      return [
        TextSpan(
          text: userEnglish,
          style: baseStyle.copyWith(color: diffColor, fontWeight: FontWeight.w700),
        ),
      ];
    }
    return spans;
  }

  static List<TextSpan> _spansFromWordOps({
    required List<_WordDiffOp> ops,
    required List<_WordTok> modelToks,
    required List<_WordTok> userToks,
    required TextStyle baseStyle,
    required Color normalColor,
    required bool isModelSide,
  }) {
    final spans = <TextSpan>[];
    var im = 0;
    var iu = 0;

    void addSpaceIfNeeded() {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: ' ', style: baseStyle.copyWith(color: normalColor)));
      }
    }

    for (final op in ops) {
      if (op.kind == _WordDiffKind.equal) {
        for (var k = 0; k < op.count; k++) {
          addSpaceIfNeeded();
          final tok = isModelSide ? modelToks[im + k] : userToks[iu + k];
          spans.add(
            TextSpan(
              text: tok.display,
              style: baseStyle.copyWith(color: normalColor),
            ),
          );
        }
        im += op.count;
        iu += op.count;
      } else if (op.kind == _WordDiffKind.delete) {
        if (isModelSide) {
          for (var k = 0; k < op.count; k++) {
            addSpaceIfNeeded();
            spans.add(
              TextSpan(
                text: modelToks[im + k].display,
                style: baseStyle.copyWith(
                  color: diffColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
        }
        im += op.count;
      } else {
        if (!isModelSide) {
          for (var k = 0; k < op.count; k++) {
            addSpaceIfNeeded();
            spans.add(
              TextSpan(
                text: userToks[iu + k].display,
                style: baseStyle.copyWith(
                  color: diffColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
        }
        iu += op.count;
      }
    }

    return spans;
  }

  /// 模範文・ユーザー発話を単語整列し、一致の割合から 0〜100 を **10 点刻み** で返す。
  ///
  /// `2 * matched / (modelWords + userWords) * 100` を四捨五入してから 10 刻み（API モードと同様のレンジ）。
  static int scoreFromWordDiffRoundedTen(String modelEnglish, String userEnglish) {
    final modelToks = _wordToks(modelEnglish);
    final userToks = _wordToks(userEnglish);
    if (modelToks.isEmpty) {
      return userToks.isEmpty ? 100 : 0;
    }
    if (userToks.isEmpty) {
      return 0;
    }
    final km = modelToks.map((t) => t.key).toList();
    final ku = userToks.map((t) => t.key).toList();
    final ops = _diffKeys(km, ku);
    var matched = 0;
    for (final op in ops) {
      if (op.kind == _WordDiffKind.equal) {
        matched += op.count;
      }
    }
    final denom = modelToks.length + userToks.length;
    final raw = denom == 0 ? 100 : ((200 * matched) / denom).round().clamp(0, 100);
    return _roundScoreToTen(raw);
  }

  static int _roundScoreToTen(int score0to100) {
    final r = (score0to100 / 10).round() * 10;
    return r.clamp(0, 100);
  }
}

enum _WordDiffKind { equal, delete, insert }

class _WordDiffOp {
  const _WordDiffOp(this.kind, this.count);

  const _WordDiffOp.equal(int n) : this(_WordDiffKind.equal, n);
  const _WordDiffOp.delete(int n) : this(_WordDiffKind.delete, n);
  const _WordDiffOp.insert(int n) : this(_WordDiffKind.insert, n);

  final _WordDiffKind kind;
  final int count;
}

class _WordTok {
  _WordTok(this.display, this.key);

  final String display;
  final String key;
}
