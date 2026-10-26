import 'package:flutter/material.dart';

/// Shared feedback wrapper for Supabase operations.
///
/// It keeps error formatting and SnackBar styling consistent across screens
/// while allowing each screen to keep its own loading/state logic.
class SupabaseErrorHandler {
  const SupabaseErrorHandler._();

  static void showError(
    BuildContext context, {
    required String operation,
    required Object error,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$operation হয়নি: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static Future<T?> run<T>(
    BuildContext context, {
    required String operation,
    required Future<T> Function() action,
    String? successMessage,
  }) async {
    try {
      final result = await action();
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      return result;
    } catch (error) {
      if (context.mounted) {
        showError(context, operation: operation, error: error);
      }
      return null;
    }
  }
}
