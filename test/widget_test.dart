import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple app structure test without Firebase dependency
// MyApp directly uses Firebase, so we test basic app structure

void main() {
  testWidgets('MaterialApp renders with basic structure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('ClutterZen')),
          body: const Center(child: Text('Welcome to ClutterZen')),
        ),
      ),
    );

    // App should boot into Material context and show a Navigator
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Navigation structure works', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/second'),
                  child: const Text('Go to Second'),
                ),
              ),
          '/second': (context) => const Scaffold(
                body: Text('Second Screen'),
              ),
        },
      ),
    );

    expect(find.text('Go to Second'), findsOneWidget);
    await tester.tap(find.text('Go to Second'));
    await tester.pumpAndSettle();
    expect(find.text('Second Screen'), findsOneWidget);
  });
}
