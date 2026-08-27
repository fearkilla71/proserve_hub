import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/utils/payment_error_mapper.dart';

void main() {
  group('humanizePaymentError', () {
    test('hides internal Firebase details from user-facing copy', () {
      final message = humanizePaymentError(
        FirebaseFunctionsException(
          code: 'internal',
          message: 'INTERNAL: Firebase App Check token rejected',
        ),
      );

      expect(
        message,
        'Payment service is temporarily unavailable. Please try again in a moment.',
      );
      expect(message.toLowerCase(), isNot(contains('firebase')));
      expect(message.toLowerCase(), isNot(contains('app check')));
      expect(message.toLowerCase(), isNot(contains('internal')));
    });

    test('keeps clear failed-precondition messages', () {
      final message = humanizePaymentError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Connect payouts before accepting paid jobs.',
        ),
      );

      expect(message, 'Connect payouts before accepting paid jobs.');
    });

    test('sanitizes generic technical exception strings', () {
      final message = humanizePaymentError(
        Exception('cloud_functions permission-denied HTTP 403'),
      );

      expect(
        message,
        'Payment service is temporarily unavailable. Please try again in a moment.',
      );
    });
  });
}
