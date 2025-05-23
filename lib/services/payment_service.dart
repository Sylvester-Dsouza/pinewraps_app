import 'dart:async';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../config/environment.dart';

class PaymentService {
  final ApiService _apiService;
  final bool _useSandbox = false; // Set to false for production environment

  PaymentService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<Map<String, String>> createPaymentOrder({
    required String orderId,
  }) async {
    try {
      print('Creating payment order for orderId: $orderId');

      final response = await _apiService.sendRequest(
        '/payments/create',
        method: 'POST',
        data: {
          'orderId': orderId,
          'platform': 'mobile', // Specify mobile platform
          'sandbox': _useSandbox,
        },
      );

      print('Server response for payment order: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        // Check if data is nested in a 'data' field
        final responseData = response.data is Map
            ? (response.data['data'] ?? response.data)
            : response.data;

        print('Processing response data: $responseData');

        final paymentUrl = responseData['paymentUrl']?.toString();
        print('Extracted payment URL: $paymentUrl');

        if (paymentUrl == null || paymentUrl.isEmpty) {
          throw Exception('Payment URL is missing from server response');
        }

        // Extract all the necessary data from the response
        final merchantOrderId = responseData['merchantOrderId']?.toString();
        final orderId = responseData['orderId']?.toString();
        final orderNumber = responseData['orderNumber']?.toString();

        return {
          'paymentUrl': paymentUrl,
          'reference':
              merchantOrderId ?? '', // Using merchantOrderId as reference
          'orderId': orderId ?? '',
          'orderNumber': orderNumber ?? ''
        };
      }

      print('Invalid response status code: ${response.statusCode}');
      throw Exception(
          'Failed to create payment order: Invalid response from server');
    } catch (e) {
      print('Error creating payment order: $e');
      rethrow;
    }
  }

  Future<bool> verifyPayment(String reference) async {
    try {
      print('Verifying payment for reference: $reference');

      // Maximum number of retries
      const maxRetries = 5;
      // Wait time between retries in seconds
      const retryDelay = 2;
      bool callbackTriggered = false;

      for (int i = 0; i < maxRetries; i++) {
        // Check the payment status directly without triggering the callback
        // This prevents duplicate reward points processing
        final response = await _apiService.sendRequest(
          '/payments/mobile/status/$reference',
          method: 'GET',
        );

        print('Payment status response: ${response.data}');

        if (response.statusCode == 200 && response.data != null) {
          final responseData = response.data['data'];
          final paymentStatus =
              responseData['status']?.toString().toUpperCase();
          print('Payment status: $paymentStatus');

          // Check if payment is captured
          if (paymentStatus == 'CAPTURED') {
            print('Payment captured successfully');

            // Only trigger the callback once per verification session
            // and only if it hasn't been triggered yet
            if (!callbackTriggered) {
              callbackTriggered = true;
              try {
                // Use a direct API call instead of the sendRequest method
                // to avoid any potential caching or retry mechanisms
                final dio = Dio();
                final baseUrl = EnvironmentConfig.apiBaseUrl;
                await dio.get(
                  '$baseUrl/payments/mobile-callback',
                  queryParameters: {'ref': reference},
                );
                print('Successfully triggered payment callback after capture');
              } catch (e) {
                print('Error triggering callback after capture: $e');
                // Continue even if callback fails, as the payment was successful
              }
            } else {
              print(
                  'Callback already triggered, skipping to avoid duplicate reward points');
            }

            return true;
          }

          // If payment failed or was cancelled, stop retrying
          if (paymentStatus == 'FAILED' || paymentStatus == 'CANCELLED') {
            print('Payment failed or cancelled. Status: $paymentStatus');
            return false;
          }

          // If still pending and not last attempt, wait and retry
          if (i < maxRetries - 1) {
            print(
                'Payment still pending, waiting ${retryDelay}s before retry ${i + 2}/$maxRetries');
            await Future.delayed(const Duration(seconds: retryDelay));
          }
        }
      }

      print('Payment verification failed after $maxRetries attempts');
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  Future<bool> waitForPaymentCompletion(String reference) async {
    const maxAttempts = 60; // 5 minutes with 5-second intervals
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final isComplete = await verifyPayment(reference);
        if (isComplete) {
          print('Payment completed successfully');
          return true;
        }

        print('Payment not complete yet, attempt ${attempts + 1}/$maxAttempts');
        // Wait 5 seconds before next attempt
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
      } catch (e) {
        print('Error checking payment status: $e');
        // Continue trying even if there's an error
      }
    }

    print('Payment verification timed out after ${maxAttempts * 5} seconds');
    return false;
  }
}
