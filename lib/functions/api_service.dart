import 'dart:convert';
import 'package:DigiDoc/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  /// Helper to get authorization headers with Bearer token.
  /// Generates a mock token in Dev Mode or fetches a Firebase ID Token.
  static Future<Map<String, String>> _getHeaders({String? forceRole, String? forceSpecialty}) async {
    String token = '';

    if (AppConfig.useDevMode) {
      final role = forceRole ?? AppConfig.mockRole ?? 'patient';
      final spec = forceSpecialty ?? AppConfig.mockSpecialty ?? 'General';
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AppConfig.mockUid ?? 'mock_uid';
      final email = FirebaseAuth.instance.currentUser?.email ?? AppConfig.mockEmail ?? 'user@example.com';
      token = 'dev-token-$role-$spec-$uid-$email';
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        token = await user.getIdToken() ?? '';
      }
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> syncUser({String? role, String? specialty}) async {
    try {
      final headers = await _getHeaders(forceRole: role, forceSpecialty: specialty);
      
      // Build request query parameters
      var url = '${AppConfig.baseUrl}/api/auth/sync';
      if (role != null) {
        url += '?role=$role';
        if (specialty != null) {
          url += '&specialty=${Uri.encodeComponent(specialty)}';
        }
      } else if (specialty != null) {
        url += '?specialty=${Uri.encodeComponent(specialty)}';
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[ApiService] Sync user success: ${response.body}');
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[ApiService] Sync user failed (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[ApiService] Sync user exception: $e');
      return null;
    }
  }

  /// Updates a doctor's active location coordinates and availability details.
  static Future<bool> updateDoctorProfile({
    required String specialty,
    required double latitude,
    required double longitude,
    required bool isAvailable,
    required String availabilitySchedule,
    String? clinicName,
    String? address,
    String? phone,
    double? rating,
    int? reviewsCount,
    int? consultationFee,
  }) async {
    try {
      final headers = await _getHeaders(forceRole: 'doctor', forceSpecialty: specialty);
      final Map<String, dynamic> payload = {
        'specialty': specialty,
        'latitude': latitude,
        'longitude': longitude,
        'is_available': isAvailable,
        'availability_schedule': availabilitySchedule,
      };
      if (clinicName != null) payload['clinic_name'] = clinicName;
      if (address != null) payload['address'] = address;
      if (phone != null) payload['phone'] = phone;
      if (rating != null) payload['rating'] = rating;
      if (reviewsCount != null) payload['reviews_count'] = reviewsCount;
      if (consultationFee != null) payload['consultation_fee'] = consultationFee;

      final body = json.encode(payload);

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/doctor/profile'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('[ApiService] Doctor profile updated successfully.');
        return true;
      } else {
        debugPrint('[ApiService] Doctor profile update failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ApiService] Doctor profile update exception: $e');
      return false;
    }
  }

  /// Submits symptoms and predicts the disease in a single, secure backend API call.
  static Future<String> predictDisease(Map<String, int> symptoms) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'symptoms': symptoms,
      });

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/predict'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['disease'] as String? ?? 'Unknown Disease';
        }
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] Prediction exception: $e');
      rethrow;
    }
  }

  /// Retrives specialists within a specified radius (in km) from coordinates.
  static Future<List<Map<String, dynamic>>> getNearbyDoctors({
    required double latitude,
    required double longitude,
    required String specialty,
    double radius = 5.0,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConfig.baseUrl}/api/doctors/nearby?'
          'latitude=$latitude&'
          'longitude=$longitude&'
          'specialty=${Uri.encodeComponent(specialty)}&'
          'radius=$radius';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((d) => d as Map<String, dynamic>).toList();
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[ApiService] Fetch nearby doctors exception: $e');
      rethrow;
    }
  }

  /// Fetches the list of all 133 symptoms with display names and categories.
  static Future<List<Map<String, dynamic>>> fetchSymptoms() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/symptoms'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> symptoms = data['symptoms'] ?? [];
        return symptoms.map((s) => s as Map<String, dynamic>).toList();
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] fetchSymptoms exception: $e');
      rethrow;
    }
  }

  /// Predicts the disease using the list of symptoms, returning confidence lists, descriptions, and precautions.
  static Future<Map<String, dynamic>> predictDiseaseDetailed(List<String> symptoms) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'symptoms': symptoms,
      });

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/predict'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] predictDiseaseDetailed exception: $e');
      rethrow;
    }
  }

  /// Creates a new appointment booking on the database.
  static Future<Map<String, dynamic>?> createBooking({
    required String doctorId,
    required String patientName,
    required List<String> symptoms,
    required String date,
    required String time,
    required String clinicAddress,
    String? additionalNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'doctor_id': doctorId,
        'patient_name': patientName,
        'symptoms': symptoms,
        'date': date,
        'time': time,
        'clinic_address': clinicAddress,
        'additional_notes': additionalNotes,
      });

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/bookings'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[ApiService] createBooking failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] createBooking exception: $e');
      return null;
    }
  }

  /// Retrieves the list of appointments for the current user.
  static Future<List<Map<String, dynamic>>> getBookings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/bookings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((d) => d as Map<String, dynamic>).toList();
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] getBookings exception: $e');
      rethrow;
    }
  }

  /// Updates the booking status (e.g. accepts or cancels).
  static Future<Map<String, dynamic>?> updateBookingStatus(int bookingId, String status) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'status': status,
      });

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/bookings/$bookingId/status'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[ApiService] updateBookingStatus failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] updateBookingStatus exception: $e');
      return null;
    }
  }

  /// Fetches available slots for a doctor on a specific date.
  static Future<List<String>> getDoctorSlots(String doctorId, String date) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/doctors/$doctorId/slots?date=$date'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> slots = data['available_slots'] ?? [];
        return slots.map((s) => s.toString()).toList();
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      debugPrint('[ApiService] getDoctorSlots exception: $e');
      rethrow;
    }
  }}
