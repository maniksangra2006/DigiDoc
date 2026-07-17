import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:digidoc/functions/api_service.dart';
import 'package:digidoc/config.dart';

class BookingFormPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const BookingFormPage({super.key, required this.doctor});

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _gender = 'Male';
  DateTime? _selectedDate;
  String? _selectedTime;
  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from auth
    _nameController.text = FirebaseAuth.instance.currentUser?.displayName ?? AppConfig.mockName ?? '';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTeal,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
        _availableSlots.clear();
      });
      _fetchAvailableSlots(picked);
    }
  }

  Future<void> _fetchAvailableSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
    });

    final String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final String docId = widget.doctor['user_id'] ?? '';

    try {
      final slots = await ApiService.getDoctorSlots(docId, dateStr);
      setState(() {
        _availableSlots = slots;
        _isLoadingSlots = false;
      });
    } catch (e) {
      debugPrint('[BookingForm] Error fetching slots: $e');
      setState(() {
        // Fallback standard slots if offline/API fails
        _availableSlots = ["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM", "03:00 PM", "04:00 PM", "05:00 PM"];
        _isLoadingSlots = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available time slot.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    final docId = widget.doctor['user_id'] ?? '';
    final clinic = widget.doctor['clinic_name'] ?? 'City Hospital';
    final address = widget.doctor['address'] ?? 'Sector 10, Greater Noida';

    final result = await ApiService.createBooking(
      doctorId: docId,
      patientName: _nameController.text.trim(),
      symptoms: ["Consultation"], // General placeholder
      date: dateStr,
      time: _selectedTime!,
      clinicAddress: "$clinic, $address",
      additionalNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    setState(() => _isSubmitting = false);

    if (result != null) {
      // Show Booking Confirmation Modal
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Booking Confirmed', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your consultation with Dr. ${widget.doctor['name']} has been scheduled.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Time: $_selectedTime', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Clinic: $clinic', style: const TextStyle(fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // dismiss dialog
                  Navigator.pop(context); // pop booking form
                  Navigator.pop(context); // pop doctor list
                },
                child: const Text('Back to Home', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed. The slot may have been taken.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String docName = widget.doctor['name'] ?? 'Doctor';
    final String docSpec = widget.doctor['specialty'] ?? 'General Medicine';

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
          'Book Appointment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor brief header
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0.5,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: lightTeal,
                    child: Icon(Icons.person_rounded, color: darkTeal),
                  ),
                  title: Text(
                    'Dr. $docName',
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(docSpec, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Patient Information',
                style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Form Cards
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Patient Name',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: primaryTeal),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined, color: primaryTeal),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter patient age';
                          }
                          final val = int.tryParse(value);
                          if (val == null || val <= 0) {
                            return 'Please enter a valid age';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Gender selection
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.people_outline_rounded, color: primaryTeal),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              const Text(
                'Schedule Details',
                style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Selector
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined, color: primaryTeal),
                        title: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                          style: TextStyle(
                            color: _selectedDate == null ? Colors.grey[400] : textDark,
                            fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _selectDate,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryTeal,
                            side: const BorderSide(color: primaryTeal),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Change'),
                        ),
                      ),
                      const Divider(height: 20),

                      // Time Slot Selector
                      const Text(
                        'Preferred Time Slot',
                        style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      
                      _selectedDate == null
                          ? Center(
                              child: Text(
                                'Select a date first to check slot availability.',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            )
                          : _isLoadingSlots
                              ? const Center(child: CircularProgressIndicator(color: primaryTeal))
                              : _availableSlots.isEmpty
                                  ? Center(
                                      child: Text(
                                        'All slots are booked for this date.',
                                        style: TextStyle(color: Colors.red[400], fontSize: 12),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ...["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM", "03:00 PM", "04:00 PM", "05:00 PM"].map((slot) {
                                          final isAvailable = _availableSlots.contains(slot);
                                          final isSelected = _selectedTime == slot;

                                          return ChoiceChip(
                                            label: Text(slot),
                                            selected: isSelected,
                                            selectedColor: primaryTeal,
                                            disabledColor: Colors.grey[100],
                                            labelStyle: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : isAvailable
                                                      ? textDark
                                                      : Colors.grey[400],
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                            onSelected: isAvailable
                                                ? (selected) {
                                                    setState(() {
                                                      _selectedTime = selected ? slot : null;
                                                    });
                                                  }
                                                : null,
                                          );
                                        }),
                                      ],
                                    ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              // Notes
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes (Optional)',
                      hintText: 'Enter symptoms or specific requests...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Confirm Appointment',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
