import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:typed_data';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  bool _isSubmitting = false;
  bool _idFrontScanOk = false;
  bool _idBackScanOk = false;
  bool _idScanInProgress = false;
  String _idScanStatus = 'Scan both sides to verify your ID.';

  String? _idFrontUrl;
  String? _idBackUrl;
  String? _licenseFrontUrl;
  String? _licenseBackUrl;
  String? _insuranceUrl;

  final _licenseNumberController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _insurancePolicyController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVerificationData();
  }

  Future<void> _loadVerificationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _idFrontUrl = data['idVerification']?['frontUrl'];
          _idBackUrl = data['idVerification']?['backUrl'];
          _idFrontScanOk =
              (data['idVerification']?['frontScanOk'] as bool?) ?? false;
          _idBackScanOk =
              (data['idVerification']?['backScanOk'] as bool?) ?? false;
          _licenseFrontUrl = data['licenseVerification']?['frontUrl'];
          _licenseBackUrl = data['licenseVerification']?['backUrl'];
          _insuranceUrl = data['insuranceVerification']?['documentUrl'];

          _licenseNumberController.text =
              data['licenseVerification']?['licenseNumber'] ?? '';
          _licenseExpiryController.text =
              data['licenseVerification']?['expiryDate'] ?? '';
          _insurancePolicyController.text =
              data['insuranceVerification']?['policyNumber'] ?? '';
          _insuranceExpiryController.text =
              data['insuranceVerification']?['expiryDate'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading verification data: $e');
    }
  }

  DateTime? _parseDateToken(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9/]'), '');
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      var year = int.tryParse(parts[2]);
      if (year != null && year < 100) {
        year += 2000;
      }
      if (month != null && day != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    if (parts.length == 2) {
      final month = int.tryParse(parts[0]);
      var year = int.tryParse(parts[1]);
      if (year != null && year < 100) {
        year += 2000;
      }
      if (month != null && year != null) {
        return DateTime(year, month, 1);
      }
    }

    return null;
  }

  DateTime? _extractExpiry(String text) {
    final upper = text.toUpperCase();
    final lines = upper.split('\n');
    for (final line in lines) {
      if (line.contains('EXP') || line.contains('EXPIRES')) {
        final match = RegExp(
          r'(\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4})',
        ).firstMatch(line);
        if (match != null) {
          return _parseDateToken(match.group(1) ?? '');
        }
        final matchShort = RegExp(r'(\d{1,2}[\/-]\d{2,4})').firstMatch(line);
        if (matchShort != null) {
          return _parseDateToken(matchShort.group(1) ?? '');
        }
      }
    }
    return null;
  }

  bool _looksLikeFront(String text) {
    final upper = text.toUpperCase();
    return upper.contains('DRIVER') ||
        upper.contains('LICENSE') ||
        upper.contains('IDENTIFICATION') ||
        upper.contains('ID') ||
        upper.contains('BIRTH') ||
        upper.contains('DOB');
  }

  bool _looksLikeBack(String text) {
    final upper = text.toUpperCase();
    return upper.contains('PDF') ||
        upper.contains('BARCODE') ||
        upper.contains('AAMVA') ||
        upper.contains('EYES') ||
        upper.contains('HEIGHT') ||
        upper.contains('SEX') ||
        upper.contains('CLASS') ||
        upper.contains('DD');
  }

  Future<String> _extractTextFromImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<void> _scanId(bool isFront) async {
    if (_idScanInProgress) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (image == null) return;

    setState(() {
      _idScanInProgress = true;
      _idScanStatus = 'Scanning ${isFront ? 'front' : 'back'}…';
    });

    try {
      final text = await _extractTextFromImage(image.path);
      final looksOk = isFront ? _looksLikeFront(text) : _looksLikeBack(text);
      final expiry = isFront ? _extractExpiry(text) : null;
      final now = DateTime.now();
      final expiryOk = expiry == null || expiry.isAfter(now);

      final imageData = await image.readAsBytes();
      final user = FirebaseAuth.instance.currentUser!;
      final side = isFront ? 'front' : 'back';
      final url = await _uploadPhoto(
        imageData,
        'verifications/${user.uid}/id_$side.jpg',
      );

      if (url != null) {
        setState(() {
          if (isFront) {
            _idFrontUrl = url;
            _idFrontScanOk = looksOk && expiryOk;
          } else {
            _idBackUrl = url;
            _idBackScanOk = looksOk;
          }
        });
      }

      if (!looksOk) {
        _idScanStatus =
            'We couldn’t detect a valid ${isFront ? 'front' : 'back'} ID. Try again with better lighting.';
      } else if (!expiryOk) {
        _idScanStatus = 'ID appears expired. Please scan a valid ID.';
      } else {
        _idScanStatus =
            '${isFront ? 'Front' : 'Back'} scan verified. Scan the other side.';
      }

      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'idVerification': {
              'frontUrl': _idFrontUrl,
              'backUrl': _idBackUrl,
              'frontScanOk': _idFrontScanOk,
              'backScanOk': _idBackScanOk,
              'status': (_idFrontScanOk && _idBackScanOk)
                  ? 'verified'
                  : 'scanned',
              'autoVerified': _idFrontScanOk && _idBackScanOk,
              'verifiedAt': (_idFrontScanOk && _idBackScanOk)
                  ? FieldValue.serverTimestamp()
                  : null,
            },
          }, SetOptions(merge: true));

      if (_idFrontScanOk && _idBackScanOk) {
        await FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .set({
              'verified': true,
              'verifiedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID verified. You are now verified.')),
          );
        }
      }
    } catch (e) {
      _idScanStatus = 'Scan failed. Please try again.';
      debugPrint('ID scan error: $e');
    } finally {
      if (mounted) {
        setState(() => _idScanInProgress = false);
      }
    }
  }

  Future<String?> _uploadPhoto(Uint8List imageData, String path) async {
    try {
      // Compress if > 1MB
      if (imageData.length > 1024 * 1024) {
        final result = await FlutterImageCompress.compressWithList(
          imageData,
          minWidth: 1920,
          minHeight: 1920,
          quality: 70,
        );
        imageData = Uint8List.fromList(result);
      }

      final storageRef = FirebaseStorage.instance.ref().child(path);
      await storageRef.putData(imageData);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  Future<void> _pickAndUploadLicense(bool isFront) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (image == null) return;

    setState(() => _isSubmitting = true);

    try {
      final imageData = await image.readAsBytes();
      final user = FirebaseAuth.instance.currentUser!;
      final side = isFront ? 'front' : 'back';
      final url = await _uploadPhoto(
        imageData,
        'verifications/${user.uid}/license_$side.jpg',
      );

      if (url != null) {
        setState(() {
          if (isFront) {
            _licenseFrontUrl = url;
          } else {
            _licenseBackUrl = url;
          }
        });
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadInsurance() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (image == null) return;

    setState(() => _isSubmitting = true);

    try {
      final imageData = await image.readAsBytes();
      final user = FirebaseAuth.instance.currentUser!;
      final url = await _uploadPhoto(
        imageData,
        'verifications/${user.uid}/insurance.jpg',
      );

      if (url != null) {
        setState(() {
          _insuranceUrl = url;
        });
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_idFrontUrl == null || _idBackUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both sides of your ID')),
      );
      return;
    }

    if (!_idFrontScanOk || !_idBackScanOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan and verify both sides.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'idVerification': {
              'frontUrl': _idFrontUrl,
              'backUrl': _idBackUrl,
              'status': 'pending',
              'submittedAt': FieldValue.serverTimestamp(),
            },
            'licenseVerification': {
              'frontUrl': _licenseFrontUrl,
              'backUrl': _licenseBackUrl,
              'licenseNumber': _licenseNumberController.text.trim(),
              'expiryDate': _licenseExpiryController.text.trim(),
              'status': _licenseFrontUrl != null ? 'pending' : null,
              'submittedAt': _licenseFrontUrl != null
                  ? FieldValue.serverTimestamp()
                  : null,
            },
            'insuranceVerification': {
              'documentUrl': _insuranceUrl,
              'policyNumber': _insurancePolicyController.text.trim(),
              'expiryDate': _insuranceExpiryController.text.trim(),
              'status': _insuranceUrl != null ? 'pending' : null,
              'submittedAt': _insuranceUrl != null
                  ? FieldValue.serverTimestamp()
                  : null,
            },
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification documents submitted for review!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _insurancePolicyController.dispose();
    _insuranceExpiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Center')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ID Verification
            Text(
              'ID Verification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a government-issued photo ID',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _idScanStatus,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildUploadCard(
                    'ID Front',
                    _idFrontUrl,
                    () => _scanId(true),
                    Icons.credit_card,
                    subtitle: _idFrontScanOk ? 'Verified' : 'Tap to scan',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUploadCard(
                    'ID Back',
                    _idBackUrl,
                    () => _scanId(false),
                    Icons.credit_card,
                    subtitle: _idBackScanOk ? 'Verified' : 'Tap to scan',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // License Verification
            Text(
              'Professional License (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your professional license if applicable',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildUploadCard(
                    'License Front',
                    _licenseFrontUrl,
                    () => _pickAndUploadLicense(true),
                    Icons.badge,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUploadCard(
                    'License Back',
                    _licenseBackUrl,
                    () => _pickAndUploadLicense(false),
                    Icons.badge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _licenseNumberController,
              decoration: const InputDecoration(
                labelText: 'License Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _licenseExpiryController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date (MM/YYYY)',
                border: OutlineInputBorder(),
                hintText: '12/2025',
              ),
            ),

            const SizedBox(height: 32),

            // Insurance Verification
            Text(
              'Insurance Certificate (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload proof of liability insurance',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              'Insurance Document',
              _insuranceUrl,
              _pickAndUploadInsurance,
              Icons.shield,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _insurancePolicyController,
              decoration: const InputDecoration(
                labelText: 'Policy Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _insuranceExpiryController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date (MM/YYYY)',
                border: OutlineInputBorder(),
                hintText: '12/2025',
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isSubmitting || _idScanInProgress)
                    ? null
                    : _submitVerification,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for Review'),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Why verify?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Get a verified badge on your profile\n'
                      '• Build trust with customers\n'
                      '• Stand out in search results\n'
                      '• Access premium features',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildUploadCard(
    String title,
    String? imageUrl,
    VoidCallback onTap,
    IconData icon, {
    String? subtitle,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        child: SizedBox(
          height: 150,
          child: imageUrl != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(imageUrl, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? 'Tap to upload',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
