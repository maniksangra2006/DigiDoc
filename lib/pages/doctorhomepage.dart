import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:DigiDoc/functions/api_service.dart';
import 'package:DigiDoc/config.dart';
import 'package:DigiDoc/firebase/auth.dart';
import 'package:DigiDoc/pages/starterpage.dart';
import 'package:DigiDoc/pages/bookinglistpage.dart';

class DoctorHome extends StatefulWidget {
  final String spec;
  const DoctorHome({super.key, required this.spec});
  @override
  State<DoctorHome> createState() => _DoctorHome();
}

class _DoctorHome extends State<DoctorHome> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  bool _isLocating = false;
  bool _isLocated = false;
  String? userName = '';
  Position? _currentPosition;
  final TextEditingController _scheduleController = TextEditingController(text: "Mon-Fri 9:00 AM - 5:00 PM");

  @override
  void initState() {
    super.initState();
    userName = FirebaseAuth.instance.currentUser?.displayName ?? AppConfig.mockName ?? 'Doctor';
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StarterPage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-out failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    super.dispose();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')));
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions permanently denied')));
      return false;
    }
    return true;
  }

  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      if (!await _handleLocationPermission()) {
        setState(() => _isLocating = false);
        return;
      }
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final GeoFirePoint location = GeoFirePoint(
          _currentPosition!.latitude, _currentPosition!.longitude);

      final uid = FirebaseAuth.instance.currentUser?.uid ?? AppConfig.mockUid ?? 'mock_doctor_uid';

      // Store in specialty collection for geo queries (safe-wrapped in try-catch)
      try {
        await FirebaseFirestore.instance
            .collection(widget.spec)
            .doc(uid)
            .update({'position': location.data});

        // Also store in doctors collection
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(uid)
            .set({
          'position': location.data,
          'specialty': widget.spec,
          'name': userName,
          'uid': uid,
        }, SetOptions(merge: true));
      } catch (firestoreError) {
        debugPrint('[DoctorHome] Firestore location update failed (using backend fallback): $firestoreError');
      }

      // Update location and availability schedule on PostgreSQL backend
      await ApiService.updateDoctorProfile(
        specialty: widget.spec,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        isAvailable: true,
        availabilitySchedule: _scheduleController.text.trim().isNotEmpty
            ? _scheduleController.text.trim()
            : "Mon-Fri 9:00 AM - 5:00 PM",
      );

      setState(() { _isLocated = true; _isLocating = false; });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully! ✅'),
              backgroundColor: Color(0xFF00BFA5)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLocating = false);
      }
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
              // Hero section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryTeal, darkTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('DigiDoc — Doctor',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                                  fontSize: 13, letterSpacing: 1.1)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                          tooltip: 'Sign out',
                          onPressed: _signOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Welcome,\nDr. ${userName?.split(' ').first ?? ''} 👨‍⚕️',
                        style: const TextStyle(color: Colors.white, fontSize: 30,
                            fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Specialty: ${widget.spec}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Status card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06),
                              blurRadius: 20, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: lightTeal,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: primaryTeal, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Location Status',
                                      style: TextStyle(color: textDark,
                                          fontWeight: FontWeight.w700, fontSize: 16)),
                                  Text(_isLocated ? 'Active & visible to patients'
                                      : 'Not registered yet',
                                      style: TextStyle(
                                          color: _isLocated ? primaryTeal : Colors.grey[400],
                                          fontSize: 12)),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: _isLocated ? Colors.green : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isLocating ? null : _locateMe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLocated ? Colors.green : primaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              icon: _isLocating
                                  ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                  : Icon(_isLocated
                                  ? Icons.check_circle_rounded
                                  : Icons.my_location_rounded),
                              label: Text(
                                  _isLocating ? 'Locating...'
                                      : _isLocated ? 'Location Updated!'
                                      : 'Register My Location',
                                  style: const TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Appointments Card
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookingListPage()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06),
                                blurRadius: 20, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Manage Appointments',
                                      style: TextStyle(color: textDark,
                                          fontWeight: FontWeight.w700, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Accept, decline, or review patient consultations.',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: lightTeal,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.calendar_month_rounded,
                                  color: primaryTeal, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Availability schedule card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06),
                              blurRadius: 20, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: lightTeal,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.access_time_filled_rounded,
                                    color: primaryTeal, size: 22),
                              ),
                              const SizedBox(width: 14),
                              const Text('Availability Hours',
                                  style: TextStyle(color: textDark,
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _scheduleController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Mon-Fri 9:00 AM - 5:00 PM',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey[200]!)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey[200]!)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: primaryTeal, width: 2)),
                              filled: true,
                              fillColor: const Color(0xFFF8FFFE),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05),
                              blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: primaryTeal, size: 18),
                              SizedBox(width: 8),
                              Text('How it works',
                                  style: TextStyle(color: textDark,
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(text: 'Tap "Register My Location" to become visible'),
                          _InfoRow(text: 'Patients within 5km can find you'),
                          _InfoRow(text: 'Update your location whenever you move'),
                          _InfoRow(text: 'Patients see your name & distance'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF00BFA5), size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: TextStyle(color: Colors.grey[600], fontSize: 12))),
        ],
      ),
    );
  }
}