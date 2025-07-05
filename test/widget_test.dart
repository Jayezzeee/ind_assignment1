// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ind_assignment1/main.dart';

void main() {
  testWidgets('Memory Diary app basic flow', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryDiaryApp(
          isDarkMode: false,
          onThemeChanged: (_) {},
        ),
      ),
    );

    // Since the app now uses FirebaseAuth and Firestore, and the login/profile flow is required,
    // we can only check for the presence of the login/profile/diary widgets in a basic smoke test.
    // The old PIN/lock screen is no longer present.

    // Check for login or profile or diary screen
    expect(find.text('Memory Diary'), findsOneWidget);
    // Optionally, check for profile or diary navigation bar items
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
  });
}
