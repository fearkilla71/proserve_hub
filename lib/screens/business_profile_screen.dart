import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/skeleton_loader.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yearsInBusinessController = TextEditingController();
  final _employeeCountController = TextEditingController();
  final _businessHoursController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _awardsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _offerWarranty = false;

  final Map<String, bool> _certifications = {
    'Licensed': false,
    'Insured': false,
    'Bonded': false,
    'Background Checked': false,
    'Drug Tested': false,
  };

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  Future<void> _loadBusinessProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final businessProfile =
            data['businessProfile'] as Map<String, dynamic>?;

        setState(() {
          _yearsInBusinessController.text =
              businessProfile?['yearsInBusiness']?.toString() ?? '';
          _employeeCountController.text =
              businessProfile?['employeeCount']?.toString() ?? '';
          _businessHoursController.text =
              businessProfile?['businessHours']?.toString() ?? '';
          _warrantyController.text =
              businessProfile?['warranty']?.toString() ?? '';
          _awardsController.text = businessProfile?['awards']?.toString() ?? '';
          _offerWarranty = businessProfile?['offerWarranty'] == true;

          final certs =
              businessProfile?['certifications'] as Map<String, dynamic>?;
          if (certs != null) {
            _certifications.forEach((key, value) {
              _certifications[key] = certs[key] == true;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading business profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBusinessProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'businessProfile': {
              'yearsInBusiness':
                  int.tryParse(_yearsInBusinessController.text) ?? 0,
              'employeeCount': int.tryParse(_employeeCountController.text) ?? 1,
              'businessHours': _businessHoursController.text.trim(),
              'offerWarranty': _offerWarranty,
              'warranty': _offerWarranty ? _warrantyController.text.trim() : '',
              'awards': _awardsController.text.trim(),
              'certifications': _certifications,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _yearsInBusinessController.dispose();
    _employeeCountController.dispose();
    _businessHoursController.dispose();
    _warrantyController.dispose();
    _awardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveBusinessProfile,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const ProfileSkeleton()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info Card
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Build trust with detailed business information',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Business Experience
                  Text(
                    'Business Experience',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _yearsInBusinessController,
                    decoration: const InputDecoration(
                      labelText: 'Years in Business',
                      hintText: '5',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      helperText: 'How long have you been operating?',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter years in business';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _employeeCountController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Employees',
                      hintText: '3',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people),
                      helperText: 'Including yourself',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter employee count';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _businessHoursController,
                    decoration: const InputDecoration(
                      labelText: 'Business Hours',
                      hintText: 'Mon-Fri: 8 AM - 6 PM, Sat: 9 AM - 3 PM',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      helperText: 'Your typical availability',
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  // Certifications
                  Text(
                    'Certifications & Badges',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select all that apply to your business',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: _certifications.keys.map((key) {
                          return CheckboxListTile(
                            title: Text(key),
                            value: _certifications[key],
                            onChanged: (value) {
                              setState(() {
                                _certifications[key] = value ?? false;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Warranty & Guarantees
                  Text(
                    'Warranty & Guarantees',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Offer Warranty/Guarantee'),
                    subtitle: const Text(
                      'Do you provide warranties on your work?',
                    ),
                    value: _offerWarranty,
                    onChanged: (value) {
                      setState(() {
                        _offerWarranty = value;
                      });
                    },
                  ),

                  if (_offerWarranty) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _warrantyController,
                      decoration: const InputDecoration(
                        labelText: 'Warranty Details',
                        hintText: '1-year warranty on all installations...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified_user),
                        helperText: 'Describe your warranty or guarantee',
                      ),
                      maxLines: 3,
                      validator: _offerWarranty
                          ? (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please describe your warranty';
                              }
                              return null;
                            }
                          : null,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Awards & Recognition
                  Text(
                    'Awards & Recognition',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _awardsController,
                    decoration: const InputDecoration(
                      labelText: 'Awards & Recognition (optional)',
                      hintText: 'Best Contractor 2024, Top Rated Pro...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emoji_events),
                      helperText: 'List any awards or recognition received',
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveBusinessProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save Business Profile'),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Why complete your business profile?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Stand out from competitors\n'
                            '• Build customer trust\n'
                            '• Show your professionalism\n'
                            '• Increase booking rates\n'
                            '• Get featured in search results',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
