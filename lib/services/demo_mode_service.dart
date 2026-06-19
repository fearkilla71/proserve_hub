import 'package:flutter/foundation.dart';

class DemoModeService {
  DemoModeService._();

  static const _enabledByDefine = bool.fromEnvironment('PROSERVE_DEMO_MODE');

  static bool get isAvailable => kDebugMode || _enabledByDefine;

  static const captureRoutes = <DemoCaptureRoute>[
    DemoCaptureRoute('Landing', '/', 'First-open role choice screen'),
    DemoCaptureRoute('Customer Home', '/customer-portal', 'Customer dashboard'),
    DemoCaptureRoute(
      'Browse Pros',
      '/browse-contractors',
      'Contractor discovery',
    ),
    DemoCaptureRoute(
      'Contractor Home',
      '/contractor-portal',
      'Contractor dashboard',
    ),
    DemoCaptureRoute(
      'Tools',
      '/contractor-portal?tab=tools',
      'Contractor tools hub',
    ),
    DemoCaptureRoute('Leads', '/job-feed', 'Lead marketplace'),
  ];
}

class DemoCaptureRoute {
  const DemoCaptureRoute(this.label, this.route, this.description);

  final String label;
  final String route;
  final String description;
}
