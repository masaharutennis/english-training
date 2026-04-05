import 'package:english_training/models/blogmae_entry.dart';
import 'package:english_training/services/quiz_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickWeighted returns at most maxCount', () {
    final items = List.generate(
      20,
      (i) => BlogmaeEntry(
        learningItemId: i + 1,
        id: i + 1,
        grammar: 'g',
        english: 'e',
        japanese: 'j',
      ),
    );
    final last = {1: 100, 2: 0};
    final picked = QuizPicker.pickWeighted(items, last, 10);
    expect(picked.length, 10);
    expect(picked.toSet().length, 10);
  });

  test('pickWeighted returns all when fewer items than maxCount', () {
    final items = [
      const BlogmaeEntry(
        learningItemId: 1,
        id: 1,
        grammar: 'g',
        english: 'e',
        japanese: 'j',
      ),
    ];
    final picked = QuizPicker.pickWeighted(items, {}, 10);
    expect(picked.length, 1);
  });
}
