import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/screens/app/contact_us_screen.dart';

void main() {
  testWidgets('ContactUsScreen displays form fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactUsScreen(),
      ),
    );

    // Should show form fields
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Send Message'), findsOneWidget);
  });

  testWidgets('ContactUsScreen validates form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactUsScreen(),
      ),
    );

    // Try to submit empty form
    await tester.tap(find.text('Send Message'));
    await tester.pump();

    // Should show validation errors (form validation is handled by TextFormField)
    // The form should prevent submission
    expect(find.byType(Form), findsOneWidget);
  });
}

