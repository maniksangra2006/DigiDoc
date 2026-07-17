import 'package:digidoc/firebase/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around [AuthService] that can be called from any page
/// without importing `firebase/auth.dart` directly.
class SignInFunctions {
  /// Signs in the user with email and password.
  static Future<UserCredential> emailSignIn(String email, String password) async {
    try {
      return await AuthService.signIn(email, password);
    } catch (e) {
      debugPrint('[SignInFunctions] emailSignIn error: $e');
      rethrow;
    }
  }

  /// Signs up the user with email, password, name, and role.
  static Future<UserCredential> emailSignUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? specialty,
  }) async {
    try {
      return await AuthService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        specialty: specialty,
      );
    } catch (e) {
      debugPrint('[SignInFunctions] emailSignUp error: $e');
      rethrow;
    }
  }

  /// Signs out the current user.
  static Future<void> signOut() async {
    try {
      await AuthService.signOut();
    } catch (e) {
      debugPrint('[SignInFunctions] signOut error: $e');
      rethrow;
    }
  }

  /// Returns the currently signed-in [User], or `null` if not logged in.
  static User? get currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('[SignInFunctions] Failed to get currentUser (Firebase might not be initialized): $e');
      return null;
    }
  }

  /// Returns `true` if a user is currently signed in.
  static bool get isSignedIn => currentUser != null;
}
