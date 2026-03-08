import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detectify_ai/main.dart';

void main() {
  testWidgets('Detectify app loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DetectifyApp());

    // Verify app title
    expect(find.text('Detectify AI'), findsOneWidget);

    // Verify buttons exist
    expect(find.text('Check Text'), findsOneWidget);
    expect(find.text('Check Image / Screenshot'), findsOneWidget);
  });
}
