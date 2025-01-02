import 'dart:async';
import 'package:dio/dio.dart';
import '../config/environment.dart';
import 'api_service.dart';

class PaymentService {
  final ApiService _apiService;
  final String _apiUrl;
  final bool _useSandbox = true; // Set to true for sandbox testing
  late final Dio _dio;

  PaymentService({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService(),
        _apiUrl = EnvironmentConfig.apiBaseUrl {
    _dio = Dio(BaseOptions(baseUrl: _apiUrl));
  }

  String get _nGeniusBaseUrl => _useSandbox 
      ? 'https://api-gateway.sandbox.ngenius-payments.com'
      : 'https://api-gateway.ngenius-payments.com';

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
        final responseData = response.data is Map ? 
            (response.data['data'] ?? response.data) : response.data;
            
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
          'reference': merchantOrderId ?? '',  // Using merchantOrderId as reference
          'orderId': orderId ?? '',
          'orderNumber': orderNumber ?? ''
        };
      }

      print('Invalid response status code: ${response.statusCode}');
      throw Exception('Failed to create payment order: Invalid response from server');
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
      
      for (int i = 0; i < maxRetries; i++) {
        // First, trigger the callback to update payment status
        try {
          await _apiService.sendRequest(
            '/payments/mobile-callback',
            method: 'GET',
            queryParameters: {
              'ref': reference
            },
          );
        } catch (e) {
          print('Error triggering callback (attempt ${i + 1}): $e');
          // Continue to status check even if callback fails
        }

        // Then check the payment status
        final response = await _apiService.sendRequest(
          '/payments/mobile/status/$reference',  
          method: 'GET',
        );

        print('Payment status response: ${response.data}');

        if (response.statusCode == 200 && response.data != null) {
          final responseData = response.data['data'];
          final paymentStatus = responseData['status']?.toString().toUpperCase();
          print('Payment status: $paymentStatus');
          
          // Check if payment is captured
          if (paymentStatus == 'CAPTURED') {
            print('Payment captured successfully');
            return true;
          }
          
          // If payment failed or was cancelled, stop retrying
          if (paymentStatus == 'FAILED' || paymentStatus == 'CANCELLED') {
            print('Payment failed or cancelled. Status: $paymentStatus');
            return false;
          }
          
          // If still pending and not last attempt, wait and retry
          if (i < maxRetries - 1) {
            print('Payment still pending, waiting ${retryDelay}s before retry ${i + 2}/$maxRetries');
            await Future.delayed(Duration(seconds: retryDelay));
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
    final maxAttempts = 60; // 5 minutes with 5-second intervals
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
