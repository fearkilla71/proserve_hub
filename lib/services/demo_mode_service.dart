import 'package:flutter/foundation.dart';

class DemoModeService {
  DemoModeService._();

  static const _enabledByDefine = bool.fromEnvironment('PROSERVE_DEMO_MODE');
  static const demoJobId = 'demo-job';
  static const demoEscrowId = 'demo-escrow';
  static const demoCustomerId = 'demo-customer';
  static const demoContractorId = 'demo-contractor';

  static bool get isAvailable => kDebugMode || _enabledByDefine;

  static bool isDemoJobId(String id) => isAvailable && id == demoJobId;

  static bool isDemoEscrowId(String id) => isAvailable && id == demoEscrowId;

  static bool isDemoCapturePath(String path) {
    if (!isAvailable) return false;
    return path == '/screenshot-demo' ||
        path == '/quotes/$demoJobId' ||
        path == '/job-command/$demoJobId' ||
        path == '/invoice/$demoJobId' ||
        path == '/escrow-status/$demoEscrowId';
  }

  static Map<String, dynamic> get demoJobData => {
    'service': 'Interior Painting',
    'title': 'Interior Painting',
    'location': '77093',
    'zip': '77093',
    'description':
        'Paint living room, kitchen, hallway, and two bedrooms with minor wall repair and trim touch-ups.',
    'requesterUid': demoCustomerId,
    'claimedBy': demoContractorId,
    'contractorId': demoContractorId,
    'claimed': true,
    'status': 'escrow_funded',
    'price': 4860,
    'quoteCount': 3,
    'unreadCount': 2,
    'escrowId': demoEscrowId,
    'escrowPrice': 4860,
    'preferredDate': DateTime.now()
        .add(const Duration(days: 5))
        .toIso8601String(),
  };

  static const captureRoutes = <DemoCaptureRoute>[
    DemoCaptureRoute(
      'Landing',
      '/',
      'First-open role choice screen',
      'Start here',
    ),
    DemoCaptureRoute(
      'Customer Home',
      '/customer-portal',
      'Next-action dashboard',
      'Homeowner',
    ),
    DemoCaptureRoute(
      'Browse Pros',
      '/browse',
      'Verified contractor discovery',
      'Homeowner',
    ),
    DemoCaptureRoute(
      'Quote Comparison',
      '/quotes/demo-job',
      'Compare price, proof, scope, and escrow',
      'Homeowner',
    ),
    DemoCaptureRoute(
      'Job Command Center',
      '/job-command/demo-job',
      'Project hub for chat, escrow, invoice, photos, and review',
      'Homeowner',
    ),
    DemoCaptureRoute(
      'Contractor Home',
      '/contractor-portal',
      'Daily operating dashboard',
      'Contractor',
    ),
    DemoCaptureRoute(
      'Tools',
      '/contractor-portal?tab=tools',
      'Contractor tools hub',
      'Contractor',
    ),
    DemoCaptureRoute('Leads', '/job-feed', 'Lead marketplace', 'Contractor'),
    DemoCaptureRoute(
      'Invoice',
      '/invoice/demo-job',
      'Create and collect professional invoices',
      'Contractor',
    ),
    DemoCaptureRoute(
      'Escrow',
      '/escrow-status/demo-escrow',
      'Protected payment status and release path',
      'Trust',
    ),
  ];
}

class DemoCaptureRoute {
  const DemoCaptureRoute(
    this.label,
    this.route,
    this.description,
    this.category,
  );

  final String label;
  final String route;
  final String description;
  final String category;
}
