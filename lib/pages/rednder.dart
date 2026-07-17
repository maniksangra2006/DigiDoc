import 'package:DigiDoc/pages/homepage.dart';
import 'package:DigiDoc/pages/starterpage.dart';
import 'package:DigiDoc/pages/doctorhomepage.dart';
import 'package:DigiDoc/functions/api_service.dart';
import 'package:DigiDoc/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Auth-gate page — the app's real entry point.
///
/// Listens to [FirebaseAuth.authStateChanges] and routes the user to:
/// - [DoctorHome] or [HomePage] if already signed in (session restored)
/// - [StarterPage] if they are not signed in (choose Doctor / Patient)
///
/// This prevents logged-in users from seeing the starter/sign-in screens
/// every time the app restarts.
class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    // If a session has been restored locally, bypass auth state listener and load home directly
    if (AppConfig.mockRole != null) {
      if (AppConfig.mockRole == 'doctor') {
        return DoctorHome(spec: AppConfig.mockSpecialty ?? 'General Medicine');
      }
      return const HomePage();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for Firebase to resolve the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE0F2F1),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
            ),
          );
        }

        final user = snapshot.data;
        if (snapshot.hasData && user != null) {
          // Sync with SQLite/PostgreSQL backend first
          return FutureBuilder<Map<String, dynamic>?>(
            future: ApiService.syncUser(),
            builder: (context, syncSnapshot) {
              if (syncSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFE0F2F1),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                  ),
                );
              }

              final profile = syncSnapshot.data;
              if (profile != null) {
                final syncedRole = profile['role'] as String? ?? 'patient';
                final syncedSpec = profile['specialty'] as String? ?? 'General Medicine';

                // Save restored session variables
                AppConfig.mockRole = syncedRole;
                AppConfig.mockSpecialty = syncedSpec;
                AppConfig.mockEmail = profile['email'] ?? user.email;
                AppConfig.mockName = profile['name'] ?? user.displayName;
                AppConfig.mockUid = profile['id'] ?? user.uid;

                if (syncedRole == 'doctor') {
                  return DoctorHome(spec: syncedSpec);
                }
                return const HomePage();
              }

              // Fallback: If sync fails (e.g. offline/error), try Firestore wrapper gracefully
              return FutureBuilder<DocumentSnapshot?>(
                future: _fetchFirestoreUserDoc(user.uid),
                builder: (context, firestoreSnapshot) {
                  if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Color(0xFFE0F2F1),
                      body: Center(
                        child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                      ),
                    );
                  }

                  String role = 'patient';
                  String specialty = 'General Medicine';

                  final doc = firestoreSnapshot.data;
                  if (doc != null && doc.exists) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data != null) {
                      role = data['role'] as String? ?? 'patient';
                      specialty = data['specialty'] as String? ?? 'General Medicine';
                    }
                  }

                  // Save default/recovered parameters
                  AppConfig.mockRole = role;
                  AppConfig.mockSpecialty = specialty;
                  AppConfig.mockEmail = user.email;
                  AppConfig.mockName = user.displayName;
                  AppConfig.mockUid = user.uid;

                  if (role == 'doctor') {
                    return DoctorHome(spec: specialty);
                  }
                  return const HomePage();
                },
              );
            },
          );
        }

        // Not signed in — show the role picker
        return const StarterPage();
      },
    );
  }

  /// Safe Firestore fetch wrapped to prevent crash on locked rule exceptions
  Future<DocumentSnapshot?> _fetchFirestoreUserDoc(String uid) async {
    try {
      return await FirebaseFirestore.instance.collection('userdata').doc(uid).get();
    } catch (e) {
      debugPrint('[AuthGatePage] Firestore fallback fetch exception: $e');
      return null;
    }
  }
}