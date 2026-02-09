import 'package:flutter/material.dart';

/// Helper for optimistic UI updates - shows immediate feedback before server confirms
class OptimisticUI {
  /// Show optimistic snackbar with undo option
  static void showOptimisticFeedback(
    BuildContext context, {
    required String message,
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: onUndo != null
            ? SnackBarAction(label: 'Undo', onPressed: onUndo)
            : null,
      ),
    );
  }

  /// Show loading overlay for critical actions
  static void showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dismiss loading overlay
  static void dismissLoadingOverlay(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Execute action with optimistic update
  static Future<T?> executeWithOptimism<T>({
    required BuildContext context,
    required Future<T> Function() action,
    required String loadingMessage,
    required String successMessage,
    String? errorMessage,
    VoidCallback? onSuccess,
  }) async {
    try {
      showLoadingOverlay(context, loadingMessage);
      final result = await action();

      if (context.mounted) {
        dismissLoadingOverlay(context);
        showOptimisticFeedback(context, message: successMessage);
        onSuccess?.call();
      }

      return result;
    } catch (e) {
      if (context.mounted) {
        dismissLoadingOverlay(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }
}
