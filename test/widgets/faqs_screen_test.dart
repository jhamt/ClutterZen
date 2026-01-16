import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/screens/app/faqs_screen.dart';

void main() {
  testWidgets('FAQsScreen displays FAQs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FaqsScreen(),
      ),
    );

    // Should show search field
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search FAQs'), findsOneWidget);

    // Should show FAQ items
    expect(find.text('How do I scan a room?'), findsOneWidget);
    expect(find.text('Is my data private and secure?'), findsOneWidget);
  });

  testWidgets('FAQsScreen search functionality', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FaqsScreen(),
      ),
    );

    // Enter search query
    await tester.enterText(find.byType(TextField), 'scan');
    await tester.pump();

    // Should filter FAQs
    expect(find.text('How do I scan a room?'), findsOneWidget);
  });
}

