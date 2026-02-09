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
        return (error.message?.trim().isNotEmpty == true)
            ? error.message!.trim()
            : 'Internal error. If you are testing, make sure App Check is configured (or disabled for debug) and that your phone has working internet.';
      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'This action can\'t be completed yet.';
      case 'not-found':
        return 'Could not find the requested item. Please refresh and try again.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Something went wrong. Please try again.';
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
        if (message != null && message.isNotEmpty) return message;
        return 'Payment error. Please try again.';
    }
  }

  final text = error.toString();
  // Avoid surfacing overly technical exception prefixes.
  return text.replaceFirst('Exception: ', '').trim().isNotEmpty
      ? text.replaceFirst('Exception: ', '').trim()
      : 'Something went wrong. Please try again.';
}
