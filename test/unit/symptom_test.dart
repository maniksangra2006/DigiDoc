// Unit tests for the symptom list integrity.
//
// These tests ensure that the symptom suggestions used in the UI exactly match
// the keys used in the ML symptom map, preventing silent prediction failures.

import 'package:DigiDoc/widgets/listOfSuggestions.dart';
import 'package:flutter_test/flutter_test.dart';

/// The canonical symptom map from homepage.dart — keys must match suggestions.
/// Keep this in sync with _HomePageState._symptomMap.
const Map<String, int> _canonicalSymptomMap = {
  'itching': 0, 'skin_rash': 0, 'nodal_skin_eruptions': 0,
  'continuous_sneezing': 0, 'shivering': 0, 'chills': 0, 'joint_pain': 0,
  'stomach_pain': 0, 'acidity': 0, 'ulcers_on_tongue': 0,
  'muscle_wasting': 0, 'vomiting': 0, 'burning_micturition': 0,
  'spotting_urination': 0, 'fatigue': 0, 'weight_gain': 0, 'anxiety': 0,
  'cold_hands_and_feets': 0, 'mood_swings': 0, 'weight_loss': 0,
  'restlessness': 0, 'lethargy': 0, 'patches_in_throat': 0,
  'irregular_sugar_level': 0, 'cough': 0, 'high_fever': 0,
  'sunken_eyes': 0, 'breathlessness': 0, 'sweating': 0,
  'dehydration': 0, 'indigestion': 0, 'headache': 0, 'yellowish_skin': 0,
  'dark_urine': 0, 'nausea': 0, 'loss_of_appetite': 0,
  'pain_behind_the_eyes': 0, 'back_pain': 0, 'constipation': 0,
  'abdominal_pain': 0, 'diarrhoea': 0, 'mild_fever': 0, 'yellow_urine': 0,
  'yellowing_of_eyes': 0, 'acute_liver_failure': 0, 'fluid_overload': 0,
  'swelling_of_stomach': 0, 'swelled_lymph_nodes': 0, 'malaise': 0,
  'blurred_and_distorted_vision': 0, 'phlegm': 0, 'throat_irritation': 0,
  'redness_of_eyes': 0, 'sinus_pressure': 0, 'runny_nose': 0,
  'congestion': 0, 'chest_pain': 0, 'weakness_in_limbs': 0,
  'fast_heart_rate': 0, 'pain_during_bowel_movements': 0,
  'pain_in_anal_region': 0, 'bloody_stool': 0, 'irritation_in_anus': 0,
  'neck_pain': 0, 'dizziness': 0, 'cramps': 0, 'bruising': 0, 'obesity': 0,
  'swollen_legs': 0, 'swollen_blood_vessels': 0, 'puffy_face_and_eyes': 0,
  'enlarged_thyroid': 0, 'brittle_nails': 0, 'swollen_extremeties': 0,
  'excessive_hunger': 0, 'extra_marital_contacts': 0,
  'drying_and_tingling_lips': 0, 'slurred_speech': 0, 'knee_pain': 0,
  'hip_joint_pain': 0, 'muscle_weakness': 0, 'stiff_neck': 0,
  'swelling_joints': 0, 'movement_stiffness': 0, 'spinning_movements': 0,
  'loss_of_balance': 0, 'unsteadiness': 0, 'weakness_of_one_body_side': 0,
  'loss_of_smell': 0, 'bladder_discomfort': 0, 'foul_smell_of_urine': 0,
  'continuous_feel_of_urine': 0, 'passage_of_gases': 0,
  'internal_itching': 0, 'toxic_look_typhos': 0,
  'depression': 0, 'irritability': 0, 'muscle_pain': 0,
  'altered_sensorium': 0, 'red_spots_over_body': 0, 'belly_pain': 0,
  'abnormal_menstruation': 0, 'dischromic_patches': 0,
  'watering_from_eyes': 0, 'increased_appetite': 0, 'polyuria': 0,
  'family_history': 0, 'mucoid_sputum': 0, 'rusty_sputum': 0,
  'lack_of_concentration': 0, 'visual_disturbances': 0,
  'receiving_blood_transfusion': 0, 'receiving_unsterile_injections': 0,
  'coma': 0, 'stomach_bleeding': 0, 'distention_of_abdomen': 0,
  'history_of_alcohol_consumption': 0,
  'blood_in_sputum': 0, 'prominent_veins_on_calf': 0, 'palpitations': 0,
  'painful_walking': 0, 'pus_filled_pimples': 0, 'blackheads': 0,
  'scurring': 0, 'skin_peeling': 0, 'silver_like_dusting': 0,
  'small_dents_in_nails': 0, 'inflammatory_nails': 0, 'blister': 0,
  'red_sore_around_nose': 0, 'yellow_crust_ooze': 0,
};

void main() {
  group('Symptom list ↔ Symptom map consistency', () {
    test('every suggestion has a matching key in the symptom map', () {
      final mapKeys = _canonicalSymptomMap.keys.toSet();
      final missingFromMap = SuggestionList.suggestions
          .where((s) => !mapKeys.contains(s))
          .toList();

      expect(
        missingFromMap,
        isEmpty,
        reason: 'Suggestions not in symptom map (would be silently ignored): '
            '$missingFromMap',
      );
    });

    test('every symptom map key has a matching suggestion', () {
      final suggestions = SuggestionList.suggestions.toSet();
      final missingFromSuggestions = _canonicalSymptomMap.keys
          .where((k) => !suggestions.contains(k))
          .toList();

      // These keys in the map but not suggestions — patient can never select them
      expect(
        missingFromSuggestions,
        isEmpty,
        reason: 'Symptom map keys not in suggestions (unreachable by patient): '
            '$missingFromSuggestions',
      );
    });

    test('no suggestion has underscores that should be spaces in the display name', () {
      // Verify replaceAll('_',' ') works correctly — no consecutive underscores
      final bad = SuggestionList.suggestions
          .where((s) => s.contains('__'))
          .toList();
      expect(bad, isEmpty, reason: 'Double underscores found: $bad');
    });

    test('symptom map has no zero-value entries that are not in suggestions', () {
      final suggestions = SuggestionList.suggestions.toSet();
      final orphaned = _canonicalSymptomMap.keys
          .where((k) => !suggestions.contains(k))
          .toList();
      expect(
        orphaned,
        isEmpty,
        reason: 'Orphaned symptom map keys (wasted memory): $orphaned',
      );
    });

    test('all map values are 0 (initial state)', () {
      final nonZero = _canonicalSymptomMap.entries
          .where((e) => e.value != 0)
          .map((e) => e.key)
          .toList();
      expect(nonZero, isEmpty,
          reason: 'Initial symptom map values must all be 0');
    });
  });

  group('Known bug regressions', () {
    test('spotting_urination has no space (regression: spotting_ urination)', () {
      expect(
        SuggestionList.suggestions.contains('spotting_urination'),
        isTrue,
      );
      expect(
        SuggestionList.suggestions.any((s) => s.contains('spotting_ ')),
        isFalse,
        reason: 'Bug regression: "spotting_ urination" with extra space found',
      );
    });

    test('foul_smell_of_urine has no space (regression: foul_smell_of urine)', () {
      expect(
        SuggestionList.suggestions.contains('foul_smell_of_urine'),
        isTrue,
      );
      expect(
        SuggestionList.suggestions.any((s) => s.contains('_of ')),
        isFalse,
        reason: 'Bug regression: "foul_smell_of urine" with space found',
      );
    });

    test('toxic_look_typhos has no parentheses (regression: toxic_look_(typhos))', () {
      expect(
        SuggestionList.suggestions.contains('toxic_look_typhos'),
        isTrue,
      );
      expect(
        SuggestionList.suggestions.any((s) => s.contains('(typhos)')),
        isFalse,
        reason: 'Bug regression: parenthesised "toxic_look_(typhos)" found',
      );
    });

    test('dischromic_patches has no space (regression: dischromic _patches)', () {
      expect(
        SuggestionList.suggestions.contains('dischromic_patches'),
        isTrue,
      );
      expect(
        SuggestionList.suggestions.any((s) => s.contains('dischromic ')),
        isFalse,
        reason: 'Bug regression: "dischromic _patches" with space found',
      );
    });

    test('fluid_overload appears exactly once (regression: was duplicated)', () {
      final count = SuggestionList.suggestions
          .where((s) => s == 'fluid_overload')
          .length;
      expect(count, equals(1),
          reason: 'fluid_overload should appear exactly once, found $count times');
    });
  });
}
