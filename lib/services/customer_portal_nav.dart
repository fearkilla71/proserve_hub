import 'package:flutter/foundation.dart';

/// Lightweight cross-route signal to switch the Customer portal tab.
///
/// This avoids circular imports between the portal -> service select -> wizards.
class CustomerPortalNav {
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  static void requestTab(int index) {
    tabRequest.value = index;
  }

  static void clear() {
    tabRequest.value = null;
  }
}
