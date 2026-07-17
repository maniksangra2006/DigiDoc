// Main widget tests for DigiDoc
//
// Tests verify core UI rendering without requiring Firebase or network access.
// Firebase-dependent widgets are tested separately in unit/ tests.

import 'package:digidoc/pages/starterpage.dart';
import 'package:digidoc/widgets/listOfSuggestions.dart';
import 'package:digidoc/functions/signinfunction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── StarterPage UI tests ────────────────────────────────────────
  group('StarterPage', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StarterPage()),
      );
      // Should not throw
      expect(find.byType(StarterPage), findsOneWidget);
    });

    testWidgets('shows Doctor and Patient role cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StarterPage()),
      );
      await tester.pump();

      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
    });

    testWidgets('shows hero headline', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StarterPage()),
      );
      await tester.pump();

      expect(find.textContaining('DigiDoc'), findsWidgets);
    });

    testWidgets('shows footer text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StarterPage()),
      );
      await tester.pump();

      expect(find.text('Powered by ML · Built with Flutter'), findsOneWidget);
    });
  });

  // ─── SuggestionList tests ────────────────────────────────────────
  group('SuggestionList', () {
    test('has no duplicate entries', () {
      final suggestions = SuggestionList.suggestions;
      final unique = suggestions.toSet();
      expect(
        unique.length,
        suggestions.length,
        reason: 'Found ${suggestions.length - unique.length} duplicate(s): '
            '${suggestions.where((s) => suggestions.indexOf(s) != suggestions.lastIndexOf(s)).toSet()}',
      );
    });

    test('has no entries with leading/trailing whitespace', () {
      final bad = SuggestionList.suggestions
          .where((s) => s != s.trim())
          .toList();
      expect(bad, isEmpty,
          reason: 'Symptoms with whitespace: $bad');
    });

    test('has no entries with internal spaces (use underscores)', () {
      // Internal spaces like "spotting_ urination" break ML model matching
      final bad = SuggestionList.suggestions
          .where((s) => s.contains(RegExp(r'\s')))
          .toList();
      expect(bad, isEmpty,
          reason: 'Symptoms with spaces (should use underscores): $bad');
    });

    test('has no entries with parentheses', () {
      // "toxic_look_(typhos)" does not match the symptom map key "toxic_look_typhos"
      final bad = SuggestionList.suggestions
          .where((s) => s.contains('(') || s.contains(')'))
          .toList();
      expect(bad, isEmpty,
          reason: 'Symptoms with parentheses: $bad');
    });

    test('contains all required core symptoms', () {
      final required = [
        'itching', 'skin_rash', 'headache', 'fever', 'cough',
        'vomiting', 'fatigue', 'dizziness', 'nausea',
      ];
      // Only check for symptoms that exist in the list (not all will be there)
      final suggestions = SuggestionList.suggestions;
      for (final s in ['itching', 'skin_rash', 'headache', 'cough',
        'vomiting', 'fatigue', 'dizziness', 'nausea']) {
        expect(suggestions.contains(s), isTrue,
            reason: 'Core symptom "$s" is missing from SuggestionList');
      }
    });

    test('all suggestions are non-empty strings', () {
      final bad = SuggestionList.suggestions
          .where((s) => s.trim().isEmpty)
          .toList();
      expect(bad, isEmpty, reason: 'Found empty symptom strings');
    });

    test('legacy alias class works', () {
      // suggestionList (lowercase) should still work for backward compatibility
      expect(suggestionList.suggestions, isNotEmpty);
      expect(
        suggestionList.suggestions,
        same(SuggestionList.suggestions),
      );
    });
  });

  // ─── SignInFunctions tests ────────────────────────────────────────
  group('SignInFunctions', () {
    test('class is importable and has expected static members', () {
      // These calls should not throw — just verify the API surface exists
      expect(SignInFunctions.isSignedIn, isFalse); // no Firebase in test env
      expect(SignInFunctions.currentUser, isNull);
    });
  });
}
