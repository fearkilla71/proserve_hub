import 'package:flutter/foundation.dart';

class DemoModeService {
  DemoModeService._();

  static const _enabledByDefine = bool.fromEnvironment('PROSERVE_DEMO_MODE');

  static bool get isAvailable => kDebugMode || _enabledByDefine;

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
