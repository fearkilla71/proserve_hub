String adminFriendlyError(Object? error, String action) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('permission-denied') ||
      text.contains('permission denied')) {
    return 'Could not $action. Your admin account does not have permission for this action.';
  }
  if (text.contains('unavailable') ||
      text.contains('network') ||
      text.contains('failed host lookup')) {
    return 'Could not $action. Check your connection and try again.';
  }
  if (text.contains('not-found') || text.contains('not found')) {
    return 'Could not $action. This record may have been moved or deleted.';
  }
  return 'Could not $action. Please try again.';
}
