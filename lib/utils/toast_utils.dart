import 'package:flutter/material.dart';

class ToastUtils {
  static void showSuccessToast(String message, {BuildContext? context}) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static void showErrorToast(String message, {BuildContext? context}) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static void showInfoToast(String message, {BuildContext? context}) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Global method for showing toast without context
  static void showGlobalToast(String message, {bool isError = false, bool isSuccess = false}) {
    // This is a fallback for when context is not available
    // You can implement a different approach here if needed
    debugPrint('Toast: ${isError ? "ERROR" : isSuccess ? "SUCCESS" : "INFO"} - $message');
  }
}
