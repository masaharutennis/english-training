import 'package:flutter_test/flutter_test.dart';

import 'package:english_training/main.dart';

void main() {
  testWidgets('Home shows 瞬間英作文 and start button', (WidgetTester tester) async {
    await tester.pumpWidget(const EnglishTrainingApp());
    expect(find.text('瞬間英作文'), findsOneWidget);
    expect(find.text('学習をスタート'), findsOneWidget);
  });
}
