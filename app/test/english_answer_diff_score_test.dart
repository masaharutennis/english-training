import 'package:english_training/utils/english_answer_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreFromWordDiffRoundedTen', () {
    test('完全一致は 100', () {
      expect(
        EnglishAnswerDiff.scoreFromWordDiffRoundedTen(
          'I am fine.',
          'I am fine',
        ),
        100,
      );
    });

    test('空ユーザーは 0', () {
      expect(
        EnglishAnswerDiff.scoreFromWordDiffRoundedTen('Hello world', ''),
        0,
      );
    });

    test('双方空は 100', () {
      expect(EnglishAnswerDiff.scoreFromWordDiffRoundedTen('', '   '), 100);
    });

    test('10点刻みになる', () {
      final s = EnglishAnswerDiff.scoreFromWordDiffRoundedTen(
        'a b c d',
        'a b x d',
      );
      expect(s % 10, 0);
      expect(s, lessThanOrEqualTo(100));
      expect(s, greaterThanOrEqualTo(0));
    });
  });
}
