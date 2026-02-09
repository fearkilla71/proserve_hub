import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  final _zipCodesController = TextEditingController();
  double _serviceRadius = 25.0; // miles
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _addedZipCodes = [];

  @override
  void initState() {
    super.initState();
    _loadServiceArea();
  }

  Future<void> _loadServiceArea() async {
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
        setState(() {
          _serviceRadius = (data['serviceRadius'] as num?)?.toDouble() ?? 25.0;
          final zipCodes = data['serviceZipCodes'] as List<dynamic>?;
          if (zipCodes != null) {
            _addedZipCodes.addAll(zipCodes.map((e) => e.toString()));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading service area: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServiceArea() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'serviceRadius': _serviceRadius,
            'serviceZipCodes': _addedZipCodes,
            'serviceAreaUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service area saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addZipCode(String zipCode) {
    final trimmed = zipCode.trim();
    if (trimmed.isEmpty) return;

    // Basic validation for US zip codes
    if (trimmed.length != 5 || int.tryParse(trimmed) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 5-digit ZIP code')),
      );
      return;
    }

    if (_addedZipCodes.contains(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ZIP code already added')));
      return;
    }

    setState(() {
      _addedZipCodes.add(trimmed);
      _zipCodesController.clear();
    });
  }

  void _removeZipCode(String zipCode) {
    setState(() {
      _addedZipCodes.remove(zipCode);
    });
  }

  @override
  void dispose() {
    _zipCodesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Area'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveServiceArea,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Define where you provide services. This helps customers find you.',
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

                // Service Radius
                Text(
                  'Service Radius',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Maximum distance you\'re willing to travel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_serviceRadius.round()} miles',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Chip(
                              label: Text(
                                _serviceRadius < 10
                                    ? 'Local'
                                    : _serviceRadius < 25
                                    ? 'Regional'
                                    : 'Wide Area',
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _serviceRadius,
                          min: 5,
                          max: 100,
                          divisions: 19,
                          label: '${_serviceRadius.round()} mi',
                          onChanged: (value) {
                            setState(() => _serviceRadius = value);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '5 mi',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '100 mi',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ZIP Codes
                Text(
                  'Service ZIP Codes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add specific ZIP codes you serve (optional)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Add ZIP Code
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _zipCodesController,
                        decoration: const InputDecoration(
                          labelText: 'ZIP Code',
                          hintText: '12345',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onSubmitted: _addZipCode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      onPressed: () => _addZipCode(_zipCodesController.text),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ZIP Codes List
                if (_addedZipCodes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No ZIP codes added yet',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Added ZIP Codes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Chip(
                                label: Text('${_addedZipCodes.length}'),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _addedZipCodes.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final zipCode = _addedZipCodes[index];
                            return ListTile(
                              leading: const Icon(Icons.location_city),
                              title: Text(zipCode),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeZipCode(zipCode),
                                color: Theme.of(context).colorScheme.error,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Coverage Summary
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
                              Icons.check_circle,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Coverage Summary',
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
                          '• Service radius: ${_serviceRadius.round()} miles\n'
                          '• ZIP codes: ${_addedZipCodes.length} added\n'
                          '• Customers within your area will see your profile',
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
    );
  }
}
