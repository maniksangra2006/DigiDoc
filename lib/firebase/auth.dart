import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:DigiDoc/config.dart';

/// Centralised Firebase email/password authentication service.
class AuthService {
  /// Signs the user in with email and password.
  static Future<UserCredential> signIn(String email, String password) async {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs up a new user with email, password, name, and role.
  /// Also stores the profile details in Firestore.
  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? specialty,
  }) async {
    final UserCredential userCred =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCred.user;
    if (user != null) {
      // Update display name in Firebase Auth
      await user.updateDisplayName(name);

      try {
        // Save user details in general userdata collection
        final userMap = {
          'email': email,
          'name': name,
          'role': role,
          'uid': user.uid,
          'created_at': FieldValue.serverTimestamp(),
        };
        if (specialty != null) {
          userMap['specialty'] = specialty;
        }

        await FirebaseFirestore.instance
            .collection('userdata')
            .doc(user.uid)
            .set(userMap, SetOptions(merge: true));

        // If doctor, also store in role-specific collections
        if (role == 'doctor' && specialty != null) {
          final docMap = {
            'email': email,
            'name': name,
            'specialty': specialty,
            'role': 'doctor',
            'uid': user.uid,
          };

          await FirebaseFirestore.instance
              .collection('doctors')
              .doc(user.uid)
              .set(docMap, SetOptions(merge: true));

          await FirebaseFirestore.instance
              .collection(specialty)
              .doc(user.uid)
              .set(docMap, SetOptions(merge: true));
        }
      } catch (firestoreError) {
        debugPrint('[AuthService] Firestore backup profile write failed (using backend SQL database instead): $firestoreError');
      }
    }

    return userCred;
  }

  /// Persists local session details to SharedPreferences.
  static Future<void> saveLocalSession({
    required String uid,
    required String email,
    required String name,
    required String role,
    String? specialty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_uid', uid);
    await prefs.setString('session_email', email);
    await prefs.setString('session_name', name);
    await prefs.setString('session_role', role);
    if (specialty != null) {
      await prefs.setString('session_specialty', specialty);
    } else {
      await prefs.remove('session_specialty');
    }

    // Assign to in-memory AppConfig too
    AppConfig.mockUid = uid;
    AppConfig.mockEmail = email;
    AppConfig.mockName = name;
    AppConfig.mockRole = role;
    AppConfig.mockSpecialty = specialty;
  }

  /// Restores session details from SharedPreferences on application startup.
  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('session_uid');
    final email = prefs.getString('session_email');
    final name = prefs.getString('session_name');
    final role = prefs.getString('session_role');
    final specialty = prefs.getString('session_specialty');

    if (uid != null && email != null && name != null && role != null) {
      AppConfig.mockUid = uid;
      AppConfig.mockEmail = email;
      AppConfig.mockName = name;
      AppConfig.mockRole = role;
      AppConfig.mockSpecialty = specialty;
      return true;
    }
    return false;
  }

  /// Clears any stored session credentials.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_uid');
    await prefs.remove('session_email');
    await prefs.remove('session_name');
    await prefs.remove('session_role');
    await prefs.remove('session_specialty');

    AppConfig.mockUid = null;
    AppConfig.mockEmail = null;
    AppConfig.mockName = null;
    AppConfig.mockRole = null;
    AppConfig.mockSpecialty = null;
  }

  /// Signs the current user out.
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await clearSession();
  }
}