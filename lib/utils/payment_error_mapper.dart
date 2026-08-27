import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

String humanizePaymentError(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unavailable':
        return 'Service unavailable. Check your internet connection and try again.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a bit and try again.';
      case 'unauthenticated':
        return 'Please sign in and try again.';
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'internal':
        // In practice this is commonly caused by App Check failures (403) or
        // networking/DNS issues on-device.
        return 'Payment service is temporarily unavailable. Please try again in a moment.';
      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'This action can\'t be completed yet.';
      case 'not-found':
        return 'Could not find the requested item. Please refresh and try again.';
      default:
        return _safePaymentMessage(error.message);
    }
  }

  if (error is StripeException) {
    final code = error.error.code;
    final message = error.error.message?.trim();

    // Common UX-friendly mappings.
    switch (code) {
      case FailureCode.Canceled:
        return 'Payment canceled.';
      case FailureCode.Failed:
        return message?.isNotEmpty == true
            ? message!
            : 'Payment failed. Please try again.';
      case FailureCode.Timeout:
        return 'Payment timed out. Please try again.';
      default:
        // StripeErrorCode values are not always consistent across platforms.
        if (message != null && message.isNotEmpty) {
          return _safePaymentMessage(message);
        }
        return 'Payment error. Please try again.';
    }
  }

  final text = error.toString();
  // Avoid surfacing overly technical exception prefixes.
  return _safePaymentMessage(text.replaceFirst('Exception: ', '').trim());
}

String _safePaymentMessage(String? raw) {
  final message = raw?.trim() ?? '';
  if (message.isEmpty) return 'Something went wrong. Please try again.';

  final lower = message.toLowerCase();
  final looksTechnical =
      lower.contains('firebase') ||
      lower.contains('cloud_firestore') ||
      lower.contains('cloud_functions') ||
      lower.contains('app check') ||
      lower.contains('permission-denied') ||
      lower.contains('internal') ||
      lower.contains('http ') ||
      lower.contains('stack') ||
      lower.contains('exception') ||
      lower.contains('stripeexception');
  if (looksTechnical) {
    return 'Payment service is temporarily unavailable. Please try again in a moment.';
  }
  return message;
}
