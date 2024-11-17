import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler237/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that our app builds without throwing an exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('MyApp structure test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Check if MyApp creates a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);

    // Check if MaterialApp has the correct title
    final MaterialApp materialApp = tester.widget(find.byType(MaterialApp));
    expect(materialApp.title, 'Scheduler');

    // Check if AuthWrapper is present
    expect(find.byType(AuthWrapper), findsOneWidget);
  });

  testWidgets('AuthWrapper is present', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Check if AuthWrapper is present
    expect(find.byType(AuthWrapper), findsOneWidget);
  });

  // Remove or comment out this test if "Made by Druid Cat" text is no longer present
  // testWidgets('"Made by Druid Cat" text is present', (WidgetTester tester) async {
  //   await tester.pumpWidget(MyApp());
  //
  //   // Check for the "Made by Druid Cat" text
  //   expect(find.text('Made by Druid Cat'), findsOneWidget);
  // });
}
