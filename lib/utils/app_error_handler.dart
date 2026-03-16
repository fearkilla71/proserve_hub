import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/error_logger.dart';

/// Centralised, user-friendly error handling.
///
/// * Shows a short, human-readable SnackBar to the user.
/// * Logs the raw error + stack trace to [ErrorLogger] (→ Crashlytics +
///   Firestore `error_logs` for your admin panel).
///
/// Usage:
/// ```dart
/// try {
///   await doSomething();
/// } catch (e, st) {
///   if (mounted) AppError.show(context, e, st, action: 'save invoice');
/// }
/// ```
class AppError {
  AppError._();

  // ── Public API ────────────────────────────────────────────────────

  /// Show a friendly SnackBar and log the real error.
  ///
  /// [action] is a short description of *what the user was doing*,
  /// e.g. `'save invoice'`, `'upload photo'`, `'send message'`.
  /// It's used both in the user-facing message and in the log context.
  static void show(
    BuildContext context,
    Object error,
    StackTrace stackTrace, {
    String? action,
    String? overrideMessage,
  }) {
    // 1) Log the full technical error for admin / Crashlytics.
    ErrorLogger.instance.logError(
      error,
      stackTrace,
      context: action ?? 'user_action',
    );

    // 2) Derive a user-friendly message.
    final friendly = overrideMessage ?? _friendlyMessage(error, action);

    // 3) Show it.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(friendly),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  /// Same as [show] but returns the friendly message string (for state-based
  /// error display instead of SnackBar).
  static String capture(
    Object error,
    StackTrace stackTrace, {
    String? action,
    String? overrideMessage,
  }) {
    ErrorLogger.instance.logError(
      error,
      stackTrace,
      context: action ?? 'user_action',
    );
    return overrideMessage ?? _friendlyMessage(error, action);
  }

  // ── Internal mapping ─────────────────────────────────────────────

  /// Maps raw exceptions to human-readable text.
  static String _friendlyMessage(Object error, String? action) {
    final prefix = action != null
        ? 'Couldn\'t $action'
        : 'Something went wrong';

    // ── Firebase Auth ────────────────────────────────────────────
    if (error is FirebaseAuthException) {
      return _mapAuthCode(error.code) ?? '$prefix. Please try again.';
    }

    // ── Cloud Functions ──────────────────────────────────────────
    if (error is FirebaseFunctionsException) {
      return _mapFunctionsCode(error.code, prefix);
    }

    // ── Firestore ────────────────────────────────────────────────
    if (error is FirebaseException) {
      return _mapFirebaseCode(error.code, prefix);
    }

    // ── Timeouts ─────────────────────────────────────────────────
    if (error is TimeoutException) {
      return '$prefix — the request timed out. Check your connection.';
    }

    // ── Network / Socket ─────────────────────────────────────────
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused')) {
      return '$prefix. Please check your internet connection.';
    }

    // ── Fallback ─────────────────────────────────────────────────
    return '$prefix. Please try again.';
  }

  static String? _mapAuthCode(String code) {
    return switch (code) {
      'email-already-in-use' =>
        'That email is already registered. Try signing in instead.',
      'invalid-email' => 'Please enter a valid email address.',
      'user-not-found' => 'No account found with that email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'weak-password' => 'Password is too weak. Use at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Please wait a minute and try again.',
      'user-disabled' =>
        'This account has been disabled. Contact support for help.',
      'network-request-failed' =>
        'Network error. Please check your connection.',
      'requires-recent-login' =>
        'For security, please sign out and sign back in first.',
      'credential-already-in-use' =>
        'This credential is already linked to another account.',
      _ => null,
    };
  }

  static String _mapFunctionsCode(String code, String prefix) {
    return switch (code) {
      'unavailable' => '$prefix — service temporarily unavailable. Try again.',
      'resource-exhausted' => '$prefix — too many requests. Wait a moment.',
      'unauthenticated' => 'Please sign in and try again.',
      'permission-denied' => 'You don\'t have permission to do that.',
      'not-found' => '$prefix — the requested item was not found.',
      'deadline-exceeded' => '$prefix — the request took too long. Try again.',
      'already-exists' => '$prefix — this already exists.',
      'internal' => '$prefix. If the issue persists, contact support.',
      _ => '$prefix. Please try again.',
    };
  }

  static String _mapFirebaseCode(String code, String prefix) {
    return switch (code) {
      'permission-denied' => 'You don\'t have permission to do that.',
      'unavailable' => '$prefix — you appear to be offline.',
      'not-found' => '$prefix — the item was not found.',
      'already-exists' => '$prefix — this already exists.',
      'cancelled' => '$prefix — the operation was cancelled.',
      'data-loss' => '$prefix. Please try again.',
      _ => '$prefix. Please try again.',
    };
  }
}
