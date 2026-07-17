import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:DigiDoc/pages/doctorhomepage.dart';
import 'package:DigiDoc/pages/starterpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:DigiDoc/functions/api_service.dart';
import 'package:DigiDoc/config.dart';
import 'package:DigiDoc/firebase/auth.dart';

class DoctorSignIn extends StatefulWidget {
  const DoctorSignIn({super.key});
  @override
  State<DoctorSignIn> createState() => _DoctorSignInState();
}

class _DoctorSignInState extends State<DoctorSignIn> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _specController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _specialty = '';

  final List<String> _specialties = [
    'Pneumonia', 'Gastroenteritis', 'Migraine', 'Tuberculosis',
    'Varicose veins', 'Hepatitis D', 'AIDS', 'Malaria', 'Hepatitis E',
    'Arthritis', 'Hepatitis A', 'Paralysis (brain hemorrhage)',
    'Dimorphic hemmorhoids(piles)', 'Psoriasis', 'GERD', 'Heart attack',
    'Allergy', 'Common Cold', 'Hypothyroidism', 'Impetigo',
    'Fungal infection', 'Urinary tract infection',
    '(vertigo) Paroymsal Positional Vertigo', 'Chicken pox', 'Drug Reaction',
    'Hypoglycemia', 'Diabetes', 'Alcoholic hepatitis',
    'Chronic cholestasis', 'Acne', 'Hepatitis C', 'Osteoarthristis',
    'Peptic ulcer diseae', 'Cervical spondylosis', 'Jaundice',
    'Bronchial Asthma', 'Hepatitis B', 'Hypertension', 'Dengue',
    'Typhoid', 'Hyperthyroidism',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _specController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (_isSignUp && _specialty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your medical specialty to register.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCred;
      String finalSpecialty = _specialty;

      if (_isSignUp) {
        // Sign Up Flow
        userCred = await AuthService.signUp(
          email: email,
          password: password,
          name: name,
          role: 'doctor',
          specialty: finalSpecialty,
        );
      } else {
        // Sign In Flow - fetch specialty from firestore after sign in
        userCred = await AuthService.signIn(email, password);
        
        final user = userCred.user;
        if (user != null) {
          final docSnap = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(user.uid)
              .get();
          
          if (docSnap.exists) {
            finalSpecialty = docSnap.get('specialty') as String? ?? 'General Medicine';
          } else {
            // Check general userdata collection
            final userSnap = await FirebaseFirestore.instance
                .collection('userdata')
                .doc(user.uid)
                .get();
            if (userSnap.exists) {
              finalSpecialty = userSnap.get('specialty') as String? ?? 'General Medicine';
            } else {
              finalSpecialty = 'General Medicine';
            }
          }
        }
      }

      final user = userCred.user;
      if (user != null) {
        await AuthService.saveLocalSession(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? user.email?.split('@').first ?? '',
          role: 'doctor',
          specialty: finalSpecialty,
        );
        // Sync doctor user and specialty metadata with FastAPI backend
        await ApiService.syncUser(role: 'doctor', specialty: finalSpecialty);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => DoctorHome(spec: finalSpecialty)),
            (_) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('[DoctorSignIn] Auth failed: $e');

      // Fallback in Dev Mode to local mock session if Firebase isn't configured/connected
      if (AppConfig.useDevMode) {
        final generatedName = name.isNotEmpty ? name : email.split('@').first;
        final finalSpecialty = _specialty.isNotEmpty ? _specialty : 'General Medicine';
        final mockUid = 'mock_doctor_${generatedName.hashCode.abs()}';

        await AuthService.saveLocalSession(
          uid: mockUid,
          email: email,
          name: generatedName,
          role: 'doctor',
          specialty: finalSpecialty,
        );

        try {
          await ApiService.syncUser(role: 'doctor', specialty: finalSpecialty);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => DoctorHome(spec: finalSpecialty)),
              (_) => false,
            );
          }
          return;
        } catch (syncErr) {
          debugPrint('[DoctorSignIn] Sync failed in dev mode fallback: $syncErr');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isSignUp ? 'Registration failed: $e' : 'Login failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightTeal,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: darkTeal),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const StarterPage()),
                    ),
                  ),
                ),
              ),

              // Hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 35),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryTeal, darkTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('DigiDoc',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 20),
                    Text(_isSignUp ? 'Doctor\nRegistration' : 'Doctor\nPortal Login',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 12),
                    Text(_isSignUp 
                        ? 'Register with your medical specialty to publish your clinic location to patients.'
                        : 'Sign in to manage your clinic availability and location settings.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            height: 1.4)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign in card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Toggle Segmented Control
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isSignUp = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: !_isSignUp ? primaryTeal : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: !_isSignUp ? textDark : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isSignUp = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _isSignUp ? primaryTeal : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: _isSignUp ? textDark : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Full Name (Only visible on Sign Up)
                        if (_isSignUp) ...[
                          const Text('Doctor Name',
                              style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Dr. Jane Smith',
                              prefixIcon: const Icon(Icons.person_outline, color: primaryTeal),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: lightTeal.withOpacity(0.3),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Specialty Selector (Only visible on Sign Up)
                          const Text('Medical Specialty',
                              style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TypeAheadField<String>(
                            controller: _specController,
                            suggestionsCallback: (pattern) => _specialties
                                .where((s) => s.toLowerCase().contains(pattern.toLowerCase()))
                                .toList(),
                            builder: (context, controller, focusNode) => TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Select specialty',
                                prefixIcon: const Icon(Icons.medical_services_outlined, color: primaryTeal),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: lightTeal.withOpacity(0.3),
                              ),
                              validator: (val) {
                                if (_specialty.isEmpty) {
                                  return 'Please select a valid specialty';
                                }
                                return null;
                              },
                            ),
                            itemBuilder: (context, s) => ListTile(
                              leading: const Icon(Icons.local_hospital_outlined, color: primaryTeal, size: 20),
                              title: Text(s, style: const TextStyle(fontSize: 14)),
                            ),
                            onSelected: (s) {
                              setState(() => _specialty = s);
                              _specController.text = s;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Email
                        const Text('Email Address',
                            style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'doctor@example.com',
                            prefixIcon: const Icon(Icons.email_outlined, color: primaryTeal),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: lightTeal.withOpacity(0.3),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
                        const Text('Password',
                            style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: primaryTeal),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: lightTeal.withOpacity(0.3),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (val.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password (Only visible on Sign Up)
                        if (_isSignUp) ...[
                          const Text('Confirm Password',
                              style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, color: primaryTeal),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: lightTeal.withOpacity(0.3),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (val != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        const SizedBox(height: 12),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _isSignUp ? 'Create Doctor Account' : 'Sign In',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text('Powered by ML · Built with Flutter',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}