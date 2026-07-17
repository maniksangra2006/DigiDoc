import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:DigiDoc/pages/doctorlistpage.dart';

class PredictedPage extends StatefulWidget {
  final String disease;
  final GeoFirePoint userLocation;
  final List<dynamic>? predictions;

  const PredictedPage({
    super.key,
    required this.disease,
    required this.userLocation,
    this.predictions,
  });

  @override
  State<PredictedPage> createState() => _PredictedPageState();
}

class _PredictedPageState extends State<PredictedPage> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  final Map<int, bool> _expandedState = {};

  @override
  Widget build(BuildContext context) {
    // Generate default/fallback predictions list if backend did not provide it
    final List<dynamic> preds = widget.predictions ?? [
      {
        "disease": widget.disease,
        "confidence": 0.85,
        "description": "Click Find Doctors below to match with nearby clinics.",
        "precautions": ["Rest well", "Drink warm fluids"],
        "doctor_specialty": "General Physician"
      }
    ];

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
          'Predicted Diseases',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Possible Diagnoses',
              style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on your symptoms, we found these matches:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Predicted cards list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: preds.length,
              itemBuilder: (context, index) {
                final item = preds[index];
                final String name = item['disease'] ?? 'Unknown';
                final double confidence = (item['confidence'] as num?)?.toDouble() ?? 0.0;
                final String desc = item['description'] ?? 'No description available.';
                final List<dynamic> precautions = item['precautions'] ?? [];
                final String specialty = item['doctor_specialty'] ?? 'General Physician';
                final isExpanded = _expandedState[index] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.science_outlined, color: primaryTeal),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                              color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: confidence,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(confidence * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _expandedState[index] = !isExpanded;
                            });
                          },
                        ),
                      ),
                      
                      // Read More Expandable Section
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description
                              Text(
                                desc,
                                style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              
                              // Precautions
                              const Text(
                                'Recommended Precautions:',
                                style: TextStyle(
                                    color: textDark, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...precautions.map((pre) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded,
                                            color: primaryTeal, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            pre.toString(),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 16),

                              // Specialty Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: lightTeal,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Specialty: $specialty',
                                  style: const TextStyle(
                                      color: darkTeal, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Find Doctors for this disease
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                  label: Text('Find $specialty Doctors'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryTeal,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DoctorListPage(
                                          specialty: specialty,
                                          userLocation: widget.userLocation,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Medical Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.red[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Disclaimer: This is not a professional diagnosis. Please consult a doctor for a clinical evaluation.',
                      style: TextStyle(color: Colors.red[900], fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkTeal,
                      side: const BorderSide(color: darkTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Search Again', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final topSpecialty = preds[0]['doctor_specialty'] ?? 'General Physician';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorListPage(
                            specialty: topSpecialty,
                            userLocation: widget.userLocation,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Find Doctors Near Me', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}