import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/animated_states.dart';
import '../widgets/page_header.dart';

class ContractorSubcontractBoardScreen extends StatefulWidget {
  const ContractorSubcontractBoardScreen({super.key});

  @override
  State<ContractorSubcontractBoardScreen> createState() =>
      _ContractorSubcontractBoardScreenState();
}

class _ContractorSubcontractBoardScreenState
    extends State<ContractorSubcontractBoardScreen> {
  final _tabs = const [Tab(text: 'Open jobs'), Tab(text: 'My posts')];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subcontract jobs')),
        body: const Center(child: Text('Sign in required')),
      );
    }

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subcontract jobs'),
          bottom: TabBar(tabs: _tabs),
          actions: [
            IconButton(
              tooltip: 'Post a job',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContractorPostJobScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _JobListTab(query: _openJobsQuery()),
            _JobListTab(query: _myJobsQuery(user.uid)),
          ],
        ),
      ),
    );
  }

  Query<Map<String, dynamic>> _openJobsQuery() {
    return FirebaseFirestore.instance
        .collection('contractor_jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _myJobsQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('contractor_jobs')
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
  }
}

class _JobListTab extends StatelessWidget {
  const _JobListTab({required this.query});

  final Query<Map<String, dynamic>> query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const AnimatedStateSwitcher(
            stateKey: 'job_error',
            child: EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Could not load jobs',
              subtitle: 'Please try again.',
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const AnimatedStateSwitcher(
            stateKey: 'job_empty',
            child: EmptyStateCard(
              icon: Icons.work_outline,
              title: 'No jobs yet',
              subtitle: 'Post a job or check back soon.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] as String?)?.trim() ?? 'Job';
            final trade = (data['trade'] as String?)?.trim() ?? 'General';
            final location = (data['location'] as String?)?.trim() ?? 'Remote';
            final price = _formatPrice(data['price']);
            final status = (data['status'] as String?)?.trim() ?? 'open';
            final photoUrls =
                (data['photoUrls'] as List?)?.whereType<String>().toList() ??
                <String>[];

            return Card(
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContractorJobDetailScreen(jobId: doc.id),
                    ),
                  );
                },
                leading: photoUrls.isEmpty
                    ? CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: const Icon(Icons.work_outline),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photoUrls.first,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(title),
                subtitle: Text('$trade · $location · $status'),
                trailing: Text(
                  price,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ContractorJobDetailScreen extends StatefulWidget {
  const ContractorJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ContractorJobDetailScreen> createState() =>
      _ContractorJobDetailScreenState();
}

class _ContractorJobDetailScreenState extends State<ContractorJobDetailScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final jobRef = FirebaseFirestore.instance
        .collection('contractor_jobs')
        .doc(widget.jobId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: jobRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data();
        if (data == null) {
          return const Scaffold(body: Center(child: Text('Job not found')));
        }

        final user = FirebaseAuth.instance.currentUser;
        final createdBy = data['createdBy'] as String?;
        final isOwner = user != null && createdBy == user.uid;
        final title = (data['title'] as String?)?.trim() ?? 'Job';
        final scope = (data['scope'] as String?)?.trim() ?? '';
        final trade = (data['trade'] as String?)?.trim() ?? 'General';
        final location = (data['location'] as String?)?.trim() ?? 'Remote';
        final price = _formatPrice(data['price']);
        final status = (data['status'] as String?)?.trim() ?? 'open';
        final desired = _formatDate(data['desiredStartAt']);
        final photoUrls =
            (data['photoUrls'] as List?)?.whereType<String>().toList() ??
            <String>[];

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              PageHeader(
                title: title,
                subtitle: '$trade · $location',
                chips: [
                  _StatusChip(label: status),
                  if (desired.isNotEmpty) _StatusChip(label: 'Start: $desired'),
                ],
              ),
              if (photoUrls.isNotEmpty) ...[
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photoUrls.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          photoUrls[index],
                          width: 220,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Scope',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                scope.isEmpty ? 'No scope details provided.' : scope,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(label: 'Asking price', value: price),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(label: 'Trade', value: trade),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isOwner)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _working
                            ? null
                            : () => _submitOffer(
                                context,
                                jobRef: jobRef,
                                price: data['price'],
                                message: 'Accepting asking price',
                              ),
                        child: const Text('Accept price'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _working
                            ? null
                            : () => _showCounterDialog(context, jobRef),
                        child: const Text('Counter offer'),
                      ),
                    ),
                  ],
                ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                Text(
                  'Offers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _OfferList(
                  jobRef: jobRef,
                  jobId: widget.jobId,
                  onAccept: (offerId, contractorId) {
                    _acceptOffer(
                      context,
                      jobRef: jobRef,
                      offerId: offerId,
                      contractorId: contractorId,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCounterDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> jobRef,
  ) async {
    final priceController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Counter offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your price',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send offer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final rawPrice = double.tryParse(priceController.text.trim());
    final message = messageController.text.trim();
    if (rawPrice == null || rawPrice <= 0) return;
    if (!context.mounted) return;

    await _submitOffer(
      context,
      jobRef: jobRef,
      price: rawPrice,
      message: message,
    );
  }

  Future<void> _submitOffer(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> jobRef,
    required Object? price,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final offerPrice = price is num ? price.toDouble() : 0.0;
    if (offerPrice <= 0) return;

    setState(() => _working = true);
    try {
      await jobRef.collection('offers').add({
        'contractorId': user.uid,
        'offerPrice': offerPrice,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer sent.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send offer: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _acceptOffer(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> jobRef,
    required String offerId,
    required String contractorId,
  }) async {
    setState(() => _working = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(jobRef, {
        'status': 'assigned',
        'assignedTo': contractorId,
        'acceptedOfferId': offerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(jobRef.collection('offers').doc(offerId), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final offersSnap = await jobRef.collection('offers').get();
      for (final doc in offersSnap.docs) {
        if (doc.id == offerId) continue;
        batch.update(doc.reference, {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer accepted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept offer: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class ContractorPostJobScreen extends StatefulWidget {
  const ContractorPostJobScreen({super.key});

  @override
  State<ContractorPostJobScreen> createState() =>
      _ContractorPostJobScreenState();
}

class _ContractorPostJobScreenState extends State<ContractorPostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _scope = TextEditingController();
  final _trade = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  DateTime? _desiredStart;
  bool _submitting = false;
  final List<_PickedImage> _images = [];

  @override
  void dispose() {
    _title.dispose();
    _scope.dispose();
    _trade.dispose();
    _location.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PageHeader(
            title: 'Post a subcontract job',
            subtitle: 'Share overflow work with nearby contractors.',
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Job title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _scope,
                  decoration: const InputDecoration(labelText: 'Scope of work'),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Describe the scope';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _trade,
                  decoration: const InputDecoration(
                    labelText: 'Trade',
                    hintText: 'e.g. Painting, HVAC, Roofing',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'City or zip code',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Asking price',
                    prefixText: '\$ ',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Desired start date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _desiredStart == null
                                ? 'Select date'
                                : DateFormat.yMMMd().format(_desiredStart!),
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._images.map(
                      (image) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          image.bytes,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post job'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = <_PickedImage>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      };
      picked.add(
        _PickedImage(
          bytes: bytes,
          ext: ext,
          contentType: contentType,
          name: file.name,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _images
        ..clear()
        ..addAll(picked.take(6));
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _desiredStart ?? now,
    );
    if (picked == null) return;
    setState(() => _desiredStart = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final jobRef = FirebaseFirestore.instance
          .collection('contractor_jobs')
          .doc();
      final photoUrls = await _uploadImages(jobRef.id, user.uid);

      final payload = <String, dynamic>{
        'createdBy': user.uid,
        'title': _title.text.trim(),
        'scope': _scope.text.trim(),
        'trade': _trade.text.trim(),
        'location': _location.text.trim(),
        'price': double.parse(_price.text.trim()),
        'status': 'open',
        'photoUrls': photoUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_desiredStart != null) {
        payload['desiredStartAt'] = Timestamp.fromDate(_desiredStart!);
      }

      await jobRef.set(payload);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job posted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post job: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<List<String>> _uploadImages(String jobId, String uid) async {
    if (_images.isEmpty) return [];

    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    for (var i = 0; i < _images.length; i++) {
      final image = _images[i];
      final path = 'contractor_jobs/$uid/$jobId/photo_${i + 1}.${image.ext}';
      final ref = storage.ref().child(path);
      await ref.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }
}

class _OfferList extends StatelessWidget {
  const _OfferList({
    required this.jobRef,
    required this.jobId,
    required this.onAccept,
  });

  final DocumentReference<Map<String, dynamic>> jobRef;
  final String jobId;
  final void Function(String offerId, String contractorId) onAccept;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: jobRef.collection('offers').orderBy('createdAt').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.inbox_outlined,
            title: 'No offers yet',
            subtitle: 'Share the job with your network to get offers.',
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final contractorId = data['contractorId'] as String? ?? '';
            final offerPrice = _formatPrice(data['offerPrice']);
            final status = (data['status'] as String?)?.trim() ?? 'pending';
            final message = (data['message'] as String?)?.trim() ?? '';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offerPrice,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusChip(label: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contractorId.isEmpty
                          ? 'Contractor'
                          : 'From $contractorId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(message),
                    ],
                    const SizedBox(height: 10),
                    if (status == 'pending')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => onAccept(doc.id, contractorId),
                          child: const Text('Accept offer'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PickedImage {
  const _PickedImage({
    required this.bytes,
    required this.ext,
    required this.contentType,
    required this.name,
  });

  final Uint8List bytes;
  final String ext;
  final String contentType;
  final String name;
}

String _formatPrice(Object? raw) {
  final value = raw is num ? raw.toDouble() : 0.0;
  if (value <= 0) return '--';
  return NumberFormat.simpleCurrency().format(value);
}

String _formatDate(Object? raw) {
  if (raw is Timestamp) {
    return DateFormat.yMMMd().format(raw.toDate());
  }
  if (raw is DateTime) {
    return DateFormat.yMMMd().format(raw);
  }
  return '';
}
