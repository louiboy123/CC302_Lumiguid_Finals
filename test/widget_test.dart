import 'package:flutter_test/flutter_test.dart';

import 'package:pwd/main.dart';

void main() {
  testWidgets('Assistance portal launches', (WidgetTester tester) async {
    await tester.pumpWidget(const AssistanceApp());

    expect(find.text('Assistance Portal'), findsOneWidget);
  });
}
