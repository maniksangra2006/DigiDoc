// Unit tests for the Flutter ↔ Backend data contract.
//
// These tests verify that the JSON structure Flutter sends to the Flask
// backend is correct, and that the backend's expected response format
// is handled properly.

import 'dart:convert';
import 'package:DigiDoc/widgets/listOfSuggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── POST payload contract tests ─────────────────────────────────
  group('Flutter → Backend POST payload', () {
    test('symptom map can be serialised to valid JSON', () {
      // Build a sample symptom map as homepage.dart would
      final Map<String, int> symptomMap = {
        for (final s in SuggestionList.suggestions) s: 0,
      };
      symptomMap['itching'] = 1;
      symptomMap['skin_rash'] = 1;
      symptomMap['headache'] = 1;

      // Should not throw
      final json = jsonEncode(symptomMap);
      expect(json, isA<String>());
      expect(json.isNotEmpty, isTrue);
    });

    test('serialised payload is a flat JSON object (not nested)', () {
      final Map<String, int> symptomMap = {
        for (final s in SuggestionList.suggestions) s: 0,
      };

      final decoded = jsonDecode(jsonEncode(symptomMap));
      expect(decoded, isA<Map>());

      // All values should be int (0 or 1), not nested objects
      for (final entry in (decoded as Map).entries) {
        expect(entry.key, isA<String>());
        expect(entry.value, isA<int>());
      }
    });

    test('all symptoms start at 0 and selected ones become 1', () {
      final Map<String, int> symptomMap = {
        for (final s in SuggestionList.suggestions) s: 0,
      };

      // Simulate selecting symptoms
      final selectedSymptoms = ['itching', 'skin_rash', 'fever'];
      for (final s in selectedSymptoms) {
        if (symptomMap.containsKey(s)) {
          symptomMap[s] = 1;
        }
      }

      expect(symptomMap['itching'], equals(1));
      expect(symptomMap['skin_rash'], equals(1));
      // fever is not in the map — should not cause errors
      expect(symptomMap.containsKey('fever'), isFalse);

      // All other values should still be 0
      final nonZeroUnselected = symptomMap.entries
          .where((e) => e.value == 1 && !selectedSymptoms.contains(e.key))
          .toList();
      expect(nonZeroUnselected, isEmpty);
    });

    test('payload keys match the SuggestionList exactly', () {
      final Map<String, int> symptomMap = {
        for (final s in SuggestionList.suggestions) s: 0,
      };

      final mapKeys = symptomMap.keys.toSet();
      final suggestionSet = SuggestionList.suggestions.toSet();

      expect(mapKeys, equals(suggestionSet));
    });

    test('payload has at least 80 symptom keys (completeness check)', () {
      expect(SuggestionList.suggestions.length, greaterThanOrEqualTo(80));
    });
  });

  // ─── GET response contract tests ──────────────────────────────────
  group('Backend → Flutter GET response', () {
    test('can parse JSON disease response {"success": true, "disease": "..."}', () {
      const mockResponse = '{"success": true, "disease": "Malaria"}';
      final decoded = jsonDecode(mockResponse) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['disease'], isA<String>());
      expect(decoded['disease'], equals('Malaria'));
    });

    test('can handle plain-text disease response (fallback)', () {
      const mockResponse = 'Malaria';
      // The homepage tries JSON first, then falls back to plain text
      String disease = mockResponse;
      try {
        final decoded = jsonDecode(mockResponse);
        if (decoded is Map && decoded.containsKey('disease')) {
          disease = decoded['disease'] as String;
        }
      } catch (_) {
        // plain text — already set above
      }
      expect(disease.trim(), equals('Malaria'));
    });

    test('disease name is trimmed before use', () {
      const raw = '  Dengue  ';
      expect(raw.trim(), equals('Dengue'));
    });

    test('error response {"success": false, "error": "..."} is handled', () {
      const mockError = '{"success": false, "error": "No prediction yet"}';
      final decoded = jsonDecode(mockError) as Map<String, dynamic>;
      expect(decoded['success'], isFalse);
      expect(decoded.containsKey('error'), isTrue);
    });
  });

  // ─── Reset / clear logic tests ────────────────────────────────────
  group('Symptom map reset', () {
    test('updateAll resets all values to 0', () {
      final Map<String, int> symptomMap = {
        for (final s in SuggestionList.suggestions) s: 0,
      };
      // Set some values
      symptomMap['itching'] = 1;
      symptomMap['cough'] = 1;
      symptomMap['headache'] = 1;

      // Reset — same as _resetSymptoms() in homepage.dart
      symptomMap.updateAll((key, value) => 0);

      final nonZero = symptomMap.values.where((v) => v != 0).toList();
      expect(nonZero, isEmpty);
    });
  });
}
