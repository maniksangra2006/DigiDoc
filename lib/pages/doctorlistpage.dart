import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:digidoc/functions/api_service.dart';
import 'package:digidoc/pages/bookingformpage.dart';

class DoctorListPage extends StatefulWidget {
  final String specialty;
  final GeoFirePoint userLocation;

  const DoctorListPage({
    super.key,
    required this.specialty,
    required this.userLocation,
  });

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  int _currentTab = 0; // 0 for List, 1 for Map

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  void _fetchDoctors() {
    setState(() {
      _doctorsFuture = ApiService.getNearbyDoctors(
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
        specialty: widget.specialty,
        radius: 15.0, // Expanded radius to catch more specialists
      );
    });
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightTeal,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nearby ${widget.specialty}s',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchDoctors,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryTeal));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load doctors: ${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.specialty}s found within 15 km.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Try checking again later.', style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            );
          }

          if (_currentTab == 1) {
            // MOCK MAP VIEW
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: primaryTeal.withOpacity(0.3), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Grid map layout representation
                          Opacity(
                            opacity: 0.15,
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                              ),
                              itemBuilder: (_, __) => Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!, width: 0.5),
                                ),
                              ),
                            ),
                          ),
                          
                          // Patient location center pin
                          const Positioned(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location_rounded, color: Colors.blue, size: 24),
                                Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
                          // Doctor pins relative coordinates
                          ...list.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final doc = entry.value;
                            final double latDiff = (doc['latitude'] as double) - widget.userLocation.latitude;
                            final double lonDiff = (doc['longitude'] as double) - widget.userLocation.longitude;
                            
                            // Scale factor to map differences to screen offset
                            final double topOffset = 150.0 + (latDiff * 5000.0).clamp(-150.0, 150.0);
                            final double leftOffset = 150.0 + (lonDiff * 5000.0).clamp(-150.0, 150.0);

                            return Positioned(
                              top: topOffset,
                              left: leftOffset,
                              child: Tooltip(
                                message: doc['name'] ?? 'Doctor',
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Dr. ${doc['name']} located here')),
                                    );
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.red, size: 28),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        color: Colors.white70,
                                        child: Text(
                                          'Dr. ${doc['name']?.toString().split(' ').last}',
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Displaying ${list.length} nearby doctors in your vicinity.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          }

          // LIST VIEW (Primary tab)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final doc = list[index];
              final String name = doc['name'] ?? 'Doctor';
              final String spec = doc['specialty'] ?? widget.specialty;
              final double distance = doc['distance'] ?? 0.0;
              final String clinic = doc['clinic_name'] ?? 'City Hospital';
              final String address = doc['address'] ?? 'Sector 10, Greater Noida';
              final String phone = doc['phone'] ?? '+91 9876543210';
              final double rating = (doc['rating'] as num?)?.toDouble() ?? 4.5;
              final int reviews = doc['reviews_count'] ?? 120;
              final String schedule = doc['availability_schedule'] ?? 'Mon-Sat 9AM-6PM';
              final int fee = doc['consultation_fee'] ?? 500;
              final String? picUrl = doc['profile_pic'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: lightTeal,
                            backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
                            child: picUrl == null
                                ? const Icon(Icons.person_rounded, color: darkTeal, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. $name',
                                  style: const TextStyle(
                                      color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: lightTeal,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        spec,
                                        style: const TextStyle(
                                            color: darkTeal, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.star_rounded, color: Colors.amber[600], size: 16),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$rating ($reviews)',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, color: Colors.grey[400], size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${distance.toStringAsFixed(1)} km away',
                                      style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      
                      // Clinic details
                      Row(
                        children: [
                          Icon(Icons.local_hospital_rounded, color: Colors.grey[400], size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$clinic — $address',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: Colors.grey[400], size: 15),
                          const SizedBox(width: 8),
                          Text(
                            schedule,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.grey[400], size: 15),
                          const SizedBox(width: 8),
                          Text(
                            'Fee: ₹$fee',
                            style: const TextStyle(
                                color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.call_rounded, size: 16),
                              label: const Text('Call Now', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: darkTeal,
                                side: const BorderSide(color: darkTeal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _makeCall(phone),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.map_rounded, size: 16),
                              label: const Text('View Map', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: darkTeal,
                                side: const BorderSide(color: darkTeal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final lat = doc['latitude'] as double;
                                final lon = doc['longitude'] as double;
                                MapsLauncher.launchCoordinates(lat, lon, name);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryTeal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingFormPage(doctor: doc),
                                  ),
                                );
                              },
                              child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        selectedItemColor: primaryTeal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_rounded),
            label: 'List View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Map View',
          ),
        ],
      ),
    );
  }
}
