import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for saving & loading reusable quote/estimate templates.
class QuoteTemplateService {
  QuoteTemplateService._();
  static final instance = QuoteTemplateService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('contractors').doc(_uid).collection('quote_templates');

  // ── Watch all templates ──
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTemplates() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  // ── Create template ──
  Future<DocumentReference> createTemplate({
    required String name,
    required String serviceType,
    required List<Map<String, dynamic>> lineItems,
    double? laborRate,
    double? markupPercent,
    String? notes,
    String? termsAndConditions,
    int? validityDays,
  }) async {
    return _col.add({
      'name': name,
      'serviceType': serviceType,
      'lineItems': lineItems,
      'laborRate': laborRate,
      'markupPercent': markupPercent ?? 0,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'validityDays': validityDays ?? 30,
      'usageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update template ──
  Future<void> updateTemplate(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(updates);
  }

  // ── Delete template ──
  Future<void> deleteTemplate(String id) async {
    await _col.doc(id).delete();
  }

  // ── Increment usage count ──
  Future<void> incrementUsage(String id) async {
    await _col.doc(id).update({
      'usageCount': FieldValue.increment(1),
      'lastUsedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Duplicate template ──
  Future<void> duplicateTemplate(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return;
    final data = Map<String, dynamic>.from(snap.data()!);
    data['name'] = '${data['name']} (Copy)';
    data['usageCount'] = 0;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data.remove('lastUsedAt');
    await _col.add(data);
  }

  // ── Get templates by service type ──
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getTemplatesByService(String serviceType) async {
    final snap = await _col
        .where('serviceType', isEqualTo: serviceType)
        .orderBy('usageCount', descending: true)
        .get();
    return snap.docs;
  }

  // ── Generate quote from template ──
  Map<String, dynamic> generateQuoteData(
    Map<String, dynamic> template, {
    required String clientName,
    required String jobAddress,
    String? jobId,
  }) {
    final items = (template['lineItems'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    double subtotal = 0;
    for (final item in items) {
      subtotal +=
          ((item['quantity'] as num? ?? 1) * (item['unitPrice'] as num? ?? 0))
              .toDouble();
    }
    final markup = (template['markupPercent'] as num? ?? 0).toDouble();
    final total = subtotal * (1 + markup / 100);
    final validDays = template['validityDays'] as int? ?? 30;

    return {
      'templateId': template['id'],
      'templateName': template['name'],
      'serviceType': template['serviceType'],
      'clientName': clientName,
      'jobAddress': jobAddress,
      'jobId': jobId,
      'lineItems': items,
      'subtotal': subtotal,
      'markupPercent': markup,
      'total': total,
      'laborRate': template['laborRate'],
      'notes': template['notes'],
      'termsAndConditions': template['termsAndConditions'],
      'validUntil': DateTime.now()
          .add(Duration(days: validDays))
          .toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'draft',
    };
  }

  static const serviceTypes = <String, String>{
    'painting': 'Interior Painting',
    'exterior_painting': 'Exterior Painting',
    'cabinet_painting': 'Cabinet Painting',
    'drywall': 'Drywall Repair',
    'pressure_washing': 'Pressure Washing',
  };
}
