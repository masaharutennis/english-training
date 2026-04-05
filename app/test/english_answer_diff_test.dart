import 'package:english_training/utils/english_answer_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCompareKey', () {
    test('ignores comma and question mark', () {
      expect(
        EnglishAnswerDiff.normalizeCompareKey('Hello,'),
        EnglishAnswerDiff.normalizeCompareKey('Hello'),
      );
      expect(
        EnglishAnswerDiff.normalizeCompareKey('What?'),
        EnglishAnswerDiff.normalizeCompareKey('What'),
      );
    });

    test('unifies apostrophe variants', () {
      expect(
        EnglishAnswerDiff.normalizeCompareKey('it\u2019s'),
        EnglishAnswerDiff.normalizeCompareKey("it's"),
      );
    });

    test('maps fullwidth digits and letters', () {
      expect(
        EnglishAnswerDiff.normalizeCompareKey('１２３'),
        EnglishAnswerDiff.normalizeCompareKey('123'),
      );
      expect(
        EnglishAnswerDiff.normalizeCompareKey('ＡＢＣ'),
        EnglishAnswerDiff.normalizeCompareKey('ABC'),
      );
    });

    test('case insensitive for ASCII letters', () {
      expect(
        EnglishAnswerDiff.normalizeCompareKey('Hello'),
        EnglishAnswerDiff.normalizeCompareKey('hello'),
      );
      expect(
        EnglishAnswerDiff.normalizeCompareKey('WHAT'),
        EnglishAnswerDiff.normalizeCompareKey('What'),
      );
    });
  });
}
