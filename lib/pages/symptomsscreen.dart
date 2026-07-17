import 'package:flutter/material.dart';
import 'package:DigiDoc/functions/api_service.dart';
import 'package:DigiDoc/pages/predictedpage.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  List<Map<String, dynamic>> _allSymptoms = [];
  List<Map<String, dynamic>> _filteredSymptoms = [];
  final List<String> _selectedSymptoms = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
  }

  Future<void> _loadSymptoms() async {
    try {
      final symptoms = await ApiService.fetchSymptoms();
      setState(() {
        _allSymptoms = symptoms;
        _filteredSymptoms = symptoms;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SymptomsScreen] Error loading symptoms from API: $e');
      // Fallback local list of common symptoms in case API fails
      final fallback = [
        {"id": "1", "name": "itching", "display_name": "Itching", "category": "Dermatological"},
        {"id": "2", "name": "skin_rash", "display_name": "Skin Rash", "category": "Dermatological"},
        {"id": "3", "name": "continuous_sneezing", "display_name": "Continuous Sneezing", "category": "Respiratory"},
        {"id": "4", "name": "chills", "display_name": "Chills", "category": "Systemic"},
        {"id": "5", "name": "joint_pain", "display_name": "Joint Pain", "category": "Musculoskeletal"},
        {"id": "6", "name": "vomiting", "display_name": "Vomiting", "category": "Digestive"},
        {"id": "7", "name": "fatigue", "display_name": "Fatigue", "category": "Systemic"},
        {"id": "8", "name": "cough", "display_name": "Cough", "category": "Respiratory"},
        {"id": "9", "name": "high_fever", "display_name": "High Fever", "category": "Systemic"},
        {"id": "10", "name": "breathlessness", "display_name": "Breathlessness", "category": "Respiratory"},
        {"id": "11", "name": "headache", "display_name": "Headache", "category": "Neurological"},
        {"id": "12", "name": "nausea", "display_name": "Nausea", "category": "Digestive"},
        {"id": "13", "name": "loss_of_appetite", "display_name": "Loss of Appetite", "category": "Digestive"},
        {"id": "14", "name": "chest_pain", "display_name": "Chest Pain", "category": "Respiratory"},
      ];
      setState(() {
        _allSymptoms = fallback;
        _filteredSymptoms = fallback;
        _isLoading = false;
      });
    }
  }

  void _filterSymptoms(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _filteredSymptoms = _allSymptoms.where((s) {
        final display = (s['display_name'] as String).toLowerCase();
        final rawName = (s['name'] as String).toLowerCase();
        return display.contains(_searchQuery) || rawName.contains(_searchQuery);
      }).toList();
    });
  }

  void _toggleSymptom(String symptomName) {
    setState(() {
      if (_selectedSymptoms.contains(symptomName)) {
        _selectedSymptoms.remove(symptomName);
      } else {
        if (_selectedSymptoms.length < 10) {
          _selectedSymptoms.add(symptomName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 10 symptoms can be selected.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Map<String, dynamic> _findSymptom(String symptomName) {
    for (final s in _allSymptoms) {
      if (s['name'] == symptomName) {
        return s;
      }
    }
    return {"display_name": symptomName};
  }

  Future<void> _predict() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one symptom.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryTeal),
      ),
    );

    try {
      // Get current location for doctor mapping
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
      } catch (locationErr) {
        debugPrint('[SymptomsScreen] Location fetch failed, using default: $locationErr');
      }

      final double lat = position?.latitude ?? 28.5355;
      final double lon = position?.longitude ?? 77.3910;
      final userLocation = GeoFirePoint(lat, lon);

      // Perform detailed prediction request
      final detailedResponse = await ApiService.predictDiseaseDetailed(_selectedSymptoms);
      final String topDisease = detailedResponse['disease'] as String? ?? 'Unknown Disease';

      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictedPage(
              disease: topDisease,
              userLocation: userLocation,
              predictions: detailedResponse['predictions'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prediction failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group symptoms by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var s in _filteredSymptoms) {
      final cat = s['category'] as String? ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(s);
    }
    final sortedCategories = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: lightTeal,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Symptoms',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : Column(
              children: [
                // Top selection summary (Chips)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Symptoms',
                        style: TextStyle(
                            color: textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _selectedSymptoms.isEmpty
                          ? Text(
                              'No symptoms selected yet. Select from below.',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedSymptoms.map((symptomName) {
                                final matched = _findSymptom(symptomName);
                                return Chip(
                                  backgroundColor: lightTeal,
                                  label: Text(
                                    matched['display_name'] as String,
                                    style: const TextStyle(
                                        color: darkTeal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14, color: darkTeal),
                                  onDeleted: () => _toggleSymptom(symptomName),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterSymptoms,
                      decoration: InputDecoration(
                        hintText: 'Search 130+ symptoms (e.g. fever, headache)...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: primaryTeal),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterSymptoms('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                ),
                // Categorized list of symptoms
                Expanded(
                  child: _filteredSymptoms.isEmpty
                      ? Center(
                          child: Text(
                            'No matching symptoms found.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sortedCategories.length,
                          itemBuilder: (context, catIndex) {
                            final category = sortedCategories[catIndex];
                            final symptoms = grouped[category]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: darkTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0.5,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: symptoms.length,
                                    separatorBuilder: (_, __) => Divider(
                                        height: 1, color: Colors.grey[100]),
                                    itemBuilder: (context, index) {
                                      final s = symptoms[index];
                                      final name = s['name'] as String;
                                      final display = s['display_name'] as String;
                                      final isSelected = _selectedSymptoms.contains(name);

                                      return CheckboxListTile(
                                        activeColor: primaryTeal,
                                        title: Text(
                                          display,
                                          style: TextStyle(
                                              color: textDark,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              fontSize: 14),
                                        ),
                                        value: isSelected,
                                        onChanged: (val) => _toggleSymptom(name),
                                        controlAffinity: ListTileControlAffinity.trailing,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _predict,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Predict Disease (${_selectedSymptoms.length})',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
