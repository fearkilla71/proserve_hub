import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for generating and managing SOW / contract documents.
class ContractGeneratorService {
  ContractGeneratorService._();
  static final instance = ContractGeneratorService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('contractors').doc(_uid).collection('contracts');

  // ── Watch contracts ──
  Stream<QuerySnapshot<Map<String, dynamic>>> watchContracts() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  // ── Create contract from quote data ──
  Future<DocumentReference> createContract({
    required String clientName,
    required String clientEmail,
    required String jobAddress,
    required String serviceType,
    required String scopeOfWork,
    required double totalPrice,
    required DateTime expectedStart,
    required DateTime expectedEnd,
    String? paymentTerms,
    String? warrantyClause,
    String? cancellationPolicy,
    List<Map<String, dynamic>>? lineItems,
    String? notes,
    String? jobId,
  }) async {
    final contractorDoc = await _fs.collection('contractors').doc(_uid).get();
    final contractorData = contractorDoc.data() ?? {};

    return _col.add({
      'contractorId': _uid,
      'contractorName':
          contractorData['companyName'] ??
          contractorData['displayName'] ??
          'Contractor',
      'contractorEmail': contractorData['email'] ?? '',
      'contractorPhone': contractorData['phone'] ?? '',
      'clientName': clientName,
      'clientEmail': clientEmail,
      'jobAddress': jobAddress,
      'serviceType': serviceType,
      'scopeOfWork': scopeOfWork,
      'lineItems': lineItems ?? [],
      'totalPrice': totalPrice,
      'expectedStartDate': Timestamp.fromDate(expectedStart),
      'expectedEndDate': Timestamp.fromDate(expectedEnd),
      'paymentTerms': paymentTerms ?? _defaultPaymentTerms,
      'warrantyClause': warrantyClause ?? _defaultWarranty,
      'cancellationPolicy': cancellationPolicy ?? _defaultCancellation,
      'notes': notes,
      'jobId': jobId,
      'status': 'draft', // draft | sent | signed | completed | cancelled
      'version': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update contract ──
  Future<void> updateContract(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(updates);
  }

  // ── Update status ──
  Future<void> updateStatus(String id, String status) async {
    await _col.doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete contract ──
  Future<void> deleteContract(String id) async {
    await _col.doc(id).delete();
  }

  // ── Generate contract text ──
  String generateContractText(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('SERVICE CONTRACT');
    buf.writeln('=' * 50);
    buf.writeln();
    buf.writeln('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}');
    buf.writeln('Contract #: ${data['id'] ?? 'DRAFT'}');
    buf.writeln();
    buf.writeln('CONTRACTOR:');
    buf.writeln('  ${data['contractorName']}');
    buf.writeln('  ${data['contractorEmail']}');
    buf.writeln('  ${data['contractorPhone']}');
    buf.writeln();
    buf.writeln('CLIENT:');
    buf.writeln('  ${data['clientName']}');
    buf.writeln('  ${data['clientEmail']}');
    buf.writeln('  ${data['jobAddress']}');
    buf.writeln();
    buf.writeln('SERVICE TYPE: ${data['serviceType']}');
    buf.writeln();
    buf.writeln('SCOPE OF WORK:');
    buf.writeln(data['scopeOfWork']);
    buf.writeln();

    final items = data['lineItems'] as List? ?? [];
    if (items.isNotEmpty) {
      buf.writeln('LINE ITEMS:');
      for (final item in items) {
        final desc = item['description'] ?? '';
        final qty = item['quantity'] ?? 1;
        final price = item['unitPrice'] ?? 0;
        buf.writeln('  - $desc (x$qty) \$${(qty * price).toStringAsFixed(2)}');
      }
      buf.writeln();
    }

    buf.writeln(
      'TOTAL PRICE: \$${(data['totalPrice'] as num).toStringAsFixed(2)}',
    );
    buf.writeln();
    buf.writeln('EXPECTED START: ${_formatTs(data['expectedStartDate'])}');
    buf.writeln('EXPECTED END: ${_formatTs(data['expectedEndDate'])}');
    buf.writeln();
    buf.writeln('PAYMENT TERMS:');
    buf.writeln(data['paymentTerms'] ?? _defaultPaymentTerms);
    buf.writeln();
    buf.writeln('WARRANTY:');
    buf.writeln(data['warrantyClause'] ?? _defaultWarranty);
    buf.writeln();
    buf.writeln('CANCELLATION POLICY:');
    buf.writeln(data['cancellationPolicy'] ?? _defaultCancellation);
    buf.writeln();
    if (data['notes'] != null && (data['notes'] as String).isNotEmpty) {
      buf.writeln('ADDITIONAL NOTES:');
      buf.writeln(data['notes']);
      buf.writeln();
    }
    buf.writeln('=' * 50);
    buf.writeln();
    buf.writeln('Contractor Signature: _________________________');
    buf.writeln();
    buf.writeln('Client Signature:     _________________________');
    buf.writeln();
    buf.writeln('Date:                 _________________________');

    return buf.toString();
  }

  String _formatTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.month}/${d.day}/${d.year}';
    }
    return ts?.toString() ?? 'TBD';
  }

  static const _defaultPaymentTerms =
      '50% deposit due upon signing. Remaining 50% due upon completion. '
      'All payments are due within 7 days of invoice date.';

  static const _defaultWarranty =
      'Contractor warrants all workmanship for a period of one (1) year '
      'from the date of completion. This warranty covers defects in '
      'workmanship but does not cover normal wear and tear.';

  static const _defaultCancellation =
      'Either party may cancel this contract with 48 hours written notice. '
      'If cancelled by client after work has begun, client agrees to pay '
      'for all work completed and materials purchased to date.';
}
