import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/state/app_state.dart';

/// Lightweight widget that reads AppState and displays key values.
class _AppStateReader extends StatelessWidget {
  const _AppStateReader();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    return Text(
      'signed=${state.isSignedIn}|role=${state.role ?? "null"}'
      '|loading=${state.isLoading}',
    );
  }
}

void main() {
  group('AppStateProvider / AppState.of', () {
    testWidgets('provides AppState to descendants', (tester) async {
      final state = AppState.test();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppStateProvider(
          notifier: state,
          child: const MaterialApp(home: Scaffold(body: _AppStateReader())),
        ),
      );

      await tester.pumpAndSettle();

      // AppState.test() starts with isSignedIn=false, loading=false
      expect(find.textContaining('signed=false'), findsOneWidget);
      expect(find.textContaining('loading=false'), findsOneWidget);
    });

    testWidgets('AppState.read does not rebuild on change', (tester) async {
      final state = AppState.test();
      addTearDown(state.dispose);

      int buildCount = 0;

      await tester.pumpWidget(
        AppStateProvider(
          notifier: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildCount++;
                  // Use read — should NOT register for notifications.
                  AppState.read(context);
                  return const Text('reader');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialBuildCount = buildCount;

      // Trigger a notification — Builder should NOT rebuild.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      state.notifyListeners();
      await tester.pump();

      expect(buildCount, initialBuildCount);
    });
  });

  group('AppState getters (unit)', () {
    test('isContractor / isCustomer reflect role', () {
      final state = AppState.test();
      addTearDown(state.dispose);

      // Default: role is null.
      expect(state.isContractor, isFalse);
      expect(state.isCustomer, isFalse);
    });

    test('isSignedIn is false without Firebase', () {
      final state = AppState.test();
      addTearDown(state.dispose);

      expect(state.isSignedIn, isFalse);
    });

    test('default state values', () {
      final state = AppState.test();
      addTearDown(state.dispose);

      expect(state.user, isNull);
      expect(state.uid, isNull);
      expect(state.role, isNull);
      expect(state.profile, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.phoneVerified, isFalse);
      expect(state.emailVerified, isFalse);
    });
  });
}
