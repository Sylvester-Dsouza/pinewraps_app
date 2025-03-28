import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../models/customer_details.dart';
import '../models/address.dart';
import '../models/order.dart';
import '../models/reward.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final String _baseUrl = EnvironmentConfig.apiBaseUrl;
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheExpiry = const Duration(minutes: 5);
  List<Address>? _addressesCache;
  DateTime? _addressesCacheTime;
  CustomerDetails? _cachedCustomerDetails;
  DateTime? _cachedCustomerDetailsTime;
  int? _cachedRewardPoints;
  List<dynamic>? _cachedOrders;
  String? _cachedToken;
  String? _cachedCustomerEmail;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      listFormat: ListFormat.multiCompatible,
    ));

    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: print,
        retries: 2,
        retryDelays: const [
          Duration(milliseconds: 500),
          Duration(seconds: 1),
        ],
      ),
    );
    
    // Add caching for GET requests
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.method == 'GET') {
          final cacheKey = '${options.method}:${options.path}';
          final cachedData = _cache[cacheKey];
          if (cachedData != null) {
            final cacheTime = cachedData['time'] as DateTime;
            if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: cachedData['data'],
                  statusCode: 200,
                ),
              );
            }
            _cache.remove(cacheKey);
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.requestOptions.method == 'GET' && response.statusCode == 200) {
          final cacheKey = '${response.requestOptions.method}:${response.requestOptions.path}';
          _cache[cacheKey] = {
            'data': response.data,
            'time': DateTime.now(),
          };
        }
        return handler.next(response);
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get the stored token and add it to the request
        final token = await _getCachedFirebaseToken();
        print('Token available: ${token != null}');
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (error, handler) async {
        print('API Error: ${error.message}');
        print('Status code: ${error.response?.statusCode}');
        
        // For 401 errors, try to refresh the token and retry the request
        if (error.response?.statusCode == 401) {
          print('Received 401 - Attempting to refresh token...');
          
          try {
            // Get firebase auth instance
            final firebaseAuth = firebase_auth.FirebaseAuth.instance;
            final currentUser = firebaseAuth.currentUser;
            
            if (currentUser != null) {
              // Get a fresh token
              print('Current user found, refreshing token...');
              final newToken = await currentUser.getIdToken(true);
              
              if (newToken != null) {
                // Update the stored token
                print('Received new token, updating cache...');
                await _setCachedFirebaseToken(newToken);
                
                // Clone the original request
                final RequestOptions originalOptions = error.requestOptions;
                
                // Update authorization header with new token
                originalOptions.headers['Authorization'] = 'Bearer $newToken';
                
                print('Retrying request with new token...');
                // Retry the request with the new token
                final response = await _dio.fetch(originalOptions);
                
                // Return the response to continue the chain
                return handler.resolve(response);
              } else {
                print('Failed to get new token, signing out');
                // Force sign out if we can't get a new token
                _clearTokenCache();
                firebaseAuth.signOut();
                return handler.next(error);
              }
            } else {
              print('No current user found, signing out');
              // No current user, clear token and continue with error
              _clearTokenCache();
              return handler.next(error);
            }
          } catch (e) {
            print('Error refreshing token: $e');
            // If token refresh fails, clear token and sign out
            _clearTokenCache();
            firebase_auth.FirebaseAuth.instance.signOut();
            return handler.next(error);
          }
        }
        
        // For other errors, just continue
        return handler.next(error);
      },
    ));

    if (EnvironmentConfig.isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('API Log: $obj'),
      ));
    }
  }

  Future<String?> _getCachedFirebaseToken() async {
    if (_cachedToken != null) return _cachedToken;
    
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('firebase_token');
    return _cachedToken;
  }

  Future<void> _setCachedFirebaseToken(String? token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('firebase_token', token);
    } else {
      await prefs.remove('firebase_token');
    }
  }

  void _clearTokenCache() {
    _cachedToken = null;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add authorization header if token is available
    final token = await _getCachedFirebaseToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    print('API Error: ${err.message}');
    print('Status code: ${err.response?.statusCode}');
    
    return handler.next(err);
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String token,
  }) async {
    try {
      print('Making registration request to backend...');
      print('Using token: ${token.substring(0, 10)}...');
      
      final response = await _dio.post(
        '/customer-auth/register',
        data: {
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'token': token,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Register response status: ${response.statusCode}');
      print('Register response data type: ${response.data.runtimeType}');
      print('Register response data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return response.data;
        }
        
        // Handle the case where data is nested
        if (response.data['data'] is Map<String, dynamic>) {
          return response.data['data'];
        }
        
        // If we still don't have the right format, create a proper response
        return {
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'isEmailVerified': false,
          'rewardPoints': 0,
        };
      }
      
      throw ApiException(
        message: response.data['message'] ?? 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('API Registration error (DioException): ${e.message}');
      print('Response: ${e.response?.data}');
      final response = e.response;
      final errorMessage = response?.data is Map ? response?.data['message'] : null;
      throw ApiException(
        message: errorMessage ?? 'Registration failed: ${e.message}',
        statusCode: response?.statusCode ?? 500,
      );
    } catch (e) {
      print('API Registration error (Other): $e');
      throw ApiException(
        message: 'Registration failed: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String token,
  }) async {
    try {
      print('Making login request to backend...');
      print('Using token: ${token.substring(0, 10)}...');
      
      // Cache the token first
      await _setCachedFirebaseToken(token);
      
      final response = await _dio.post(
        '/customer-auth/login',
        data: {
          'email': email,
          'token': token,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response data: ${response.data}');

      if (response.data is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Invalid response format from server',
          statusCode: 500,
        );
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Login API Error: $e');
      if (e is DioException) {
        throw ApiException(
          message: e.response?.data?['message'] ?? 'Login failed',
          statusCode: e.response?.statusCode ?? 500,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> socialAuth({
    required String provider,
    required String email,
    required String firstName,
    String? lastName,
    String? imageUrl,
    String? phone,
    required String token,
  }) async {
    try {
      // Cache the token first
      await _setCachedFirebaseToken(token);
      
      print('Sending social auth request to: $_baseUrl/customer-auth/social');
      print('Provider: $provider, Email: $email');
      print('Token available: ${token.isNotEmpty}');
      
      final data = {
        'token': token,
        'provider': provider,
        'email': email,
        'firstName': firstName,
        'lastName': lastName ?? '',
        'imageUrl': imageUrl,
        'phone': phone,
      };
      
      print('Request data: $data');
      
      final response = await _dio.post(
        '/customer-auth/social',
        data: data,
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => true, // Allow any status code for better error handling
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Social auth response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['data'] == null) {
          print('Invalid response format - missing data field');
          throw ApiException(
            message: 'Invalid response format from server: missing data field',
            statusCode: 500,
          );
        }
        
        // Double check the data structure
        final responseData = response.data['data'];
        print('Parsed response data: $responseData');
        
        // Make sure the token in the response is stored
        if (responseData is Map && responseData['token'] != null) {
          final newToken = responseData['token'] as String;
          print('New token received from server');
          await _setCachedFirebaseToken(newToken);
        }
        
        return response.data['data'];
      }

      // More detailed error handling
      String errorMessage = 'Social authentication failed';
      int statusCode = response.statusCode ?? 500;
      
      if (response.data is Map) {
        final errorData = response.data as Map;
        if (errorData['error'] is Map) {
          final error = errorData['error'] as Map;
          errorMessage = error['message'] ?? errorMessage;
          if (error['code'] != null) {
            print('Error code from server: ${error['code']}');
          }
        } else if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
      }
      
      print('Error response: $errorMessage (status: $statusCode)');
      throw ApiException(
        message: errorMessage,
        statusCode: statusCode,
      );
    } catch (e) {
      print('Social Auth Error: $e');
      if (e is DioException) {
        print('Dio error type: ${e.type}');
        print('Dio error message: ${e.message}');
        if (e.response != null) {
          print('Response status: ${e.response?.statusCode}');
          print('Response data: ${e.response?.data}');
        }
        
        final responseData = e.response?.data;
        String errorMessage = 'Social authentication failed';
        
        if (responseData is Map) {
          if (responseData['error'] is Map) {
            final error = responseData['error'] as Map;
            errorMessage = error['message'] ?? errorMessage;
          } else if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } else if (e.message != null) {
          errorMessage = e.message!;
        }
        
        throw ApiException(
          message: errorMessage,
          statusCode: e.response?.statusCode ?? 500,
        );
      }
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Social authentication failed: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  Future<CustomerDetails> getCustomerDetails() async {
    // Return cached customer details if available and not expired
    if (_cachedCustomerDetails != null && _cachedCustomerDetailsTime != null) {
      final cacheDuration = DateTime.now().difference(_cachedCustomerDetailsTime!);
      if (cacheDuration < const Duration(minutes: 5)) {
        return _cachedCustomerDetails!;
      }
      return _cachedCustomerDetails!;
    }
    
    try {
      final response = await _dio.get('/customers/profile');
      
      if (response.statusCode == 200) {
        // Handle different response formats
        Map<String, dynamic> customerData;
        if (response.data['data'] != null) {
          customerData = response.data['data'];
        } else if (response.data is Map<String, dynamic>) {
          customerData = response.data;
        } else {
          throw ApiException(
            message: 'Invalid response format',
            statusCode: 500,
          );
        }
        
        _cachedCustomerDetails = CustomerDetails.fromJson(customerData);
        _cachedCustomerDetailsTime = DateTime.now();
        
        // Save email to cache when we get customer details
        _cachedCustomerEmail = _cachedCustomerDetails!.email;
              return _cachedCustomerDetails!;
      } else {
        throw ApiException(
          message: 'Failed to get customer details',
          statusCode: response.statusCode ?? 500,
        );
      }
    } catch (e) {
      print('Error getting customer details: $e');
      if (e is DioException && e.response?.statusCode == 401) {
        throw ApiException(
          message: 'Please log in to continue',
          statusCode: 401,
        );
      }
      rethrow;
    }
  }

  String? getCachedCustomerEmail() {
    return _cachedCustomerEmail;
  }
  
  Future<String?> getCachedCustomerEmailAsync() async {
    // First check in-memory cache
    if (_cachedCustomerEmail != null && _cachedCustomerEmail!.isNotEmpty) {
      print('Using in-memory cached email: $_cachedCustomerEmail');
      return _cachedCustomerEmail;
    }
    
    // If in-memory cache is empty, try to get from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('customer_email');
      if (email != null && email.isNotEmpty) {
        print('Retrieved email from SharedPreferences: $email');
        _cachedCustomerEmail = email; // Update in-memory cache
        return email;
      }
    } catch (e) {
      print('Error retrieving email from SharedPreferences: $e');
    }
    
    print('No cached email found');
    return null;
  }

  Future<CustomerDetails> getCurrentCustomer() async {
    try {
      return await getCustomerDetails();
    } catch (e) {
      print('Error in getCurrentCustomer: $e');
      
      // If we have cached customer details, return those even if the API call fails
      if (_cachedCustomerDetails != null) {
        print('Returning cached customer details as fallback');
        return _cachedCustomerDetails!;
      }
      
      // If we have no cached customer details, but we know the customer email
      if (_cachedCustomerEmail != null && _cachedCustomerEmail!.isNotEmpty) {
        print('Creating minimal customer details from cached email');
        return CustomerDetails(
          email: _cachedCustomerEmail!,
          id: '',
          firstName: '',
          lastName: '',
        );
      }
      
      // No cached data, rethrow the error
      rethrow;
    }
  }

  Future<void> clearCustomerCache() async {
    print('Clearing all customer cache data');
    _cachedCustomerDetails = null;
    _cachedCustomerEmail = null;
    _cachedRewardPoints = null;
    _addressesCache = null;
    _addressesCacheTime = null;
    
    // Clear specific cache entries related to customer data
    final customerCacheKeys = _cache.keys.where((key) => 
      key.contains('/customers/') || 
      key.contains('/customer-auth/') || 
      key.contains('/profile') ||
      key.contains('/addresses')
    ).toList();
    
    for (final key in customerCacheKeys) {
      print('Removing cache key: $key');
      _cache.remove(key);
    }
    
    // Also clear the cached token
    _cachedToken = null;
    
    // Clear token from secure storage
    await clearCachedFirebaseToken();
  }

  Future<CustomerDetails> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
  }) async {
    final response = await _dio.put(
      '/customers/profile',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      },
    );

    if (response.statusCode == 200) {
      // Handle different response formats
      Map<String, dynamic> customerData;
      
      print('Profile update response: ${response.data}');
      
      if (response.data['data'] != null && response.data['data'] is Map<String, dynamic>) {
        if (response.data['data']['customer'] != null) {
          customerData = response.data['data']['customer'];
        } else {
          customerData = response.data['data'];
        }
      } else if (response.data['customer'] != null) {
        customerData = response.data['customer'];
      } else if (response.data is Map<String, dynamic>) {
        customerData = response.data;
      } else {
        throw ApiException(
          message: 'Invalid response format',
          statusCode: 500,
        );
      }
      
      // Ensure we have the email from the current cached details if not in response
      if (!customerData.containsKey('email') || customerData['email'] == null) {
        if (_cachedCustomerDetails != null) {
          customerData['email'] = _cachedCustomerDetails!.email;
        } else if (_cachedCustomerEmail != null) {
          customerData['email'] = _cachedCustomerEmail;
        }
      }
      
      // Create new customer details and update cache
      _cachedCustomerDetails = CustomerDetails.fromJson(customerData);
      _cachedCustomerDetailsTime = DateTime.now();
      
      // Also update the cached email
      _cachedCustomerEmail = _cachedCustomerDetails!.email;
          
      print('Updated customer details: ${_cachedCustomerDetails!.toJson()}');
      return _cachedCustomerDetails!;
    } else {
      throw ApiException(
        message: 'Failed to update profile',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<List<Address>> getSavedAddresses() async {
    if (_addressesCache != null && _addressesCacheTime != null) {
      final cacheDuration = DateTime.now().difference(_addressesCacheTime!);
      if (cacheDuration < const Duration(minutes: 5)) {
        return _addressesCache!;
      }
    }

    final response = await _dio.get('/customers/addresses');
    
    if (response.statusCode == 200) {
      final List<dynamic> addressesJson = response.data['data'];
      _addressesCache = addressesJson.map((json) => Address.fromJson(json)).toList();
      _addressesCacheTime = DateTime.now();
      return _addressesCache!;
    } else {
      throw ApiException(
        message: 'Failed to get saved addresses',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<Map<String, dynamic>> getCurrentUserMap() async {
    final customerDetails = await getCustomerDetails();
    return customerDetails.toJson();
  }

  Future<List<Address>> getAddresses() async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      // Force a fresh fetch by clearing cache
      _addressesCache = null;
      _addressesCacheTime = null;

      final response = await _dio.get(
        '/customers/addresses',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Get addresses response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final List<dynamic> addressesJson = responseData['data'];
          _addressesCache = addressesJson.map((json) => Address.fromJson(json)).toList();
          _addressesCacheTime = DateTime.now();
          return _addressesCache!;
        }
      }

      throw ApiException(
        message: 'Failed to fetch addresses',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching addresses: $e');
      rethrow;
    }
  }

  Future<Address> addAddress(Address address) async {
    final token = await _getCachedFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final data = address.toJson();
    print('Adding address with data: $data');

    try {
      final response = await _dio.post(
        '/customers/addresses',
        data: data,
      );

      print('Response status: ${response.statusCode}');

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] != true || !responseData.containsKey('data')) {
          throw ApiException(
            message: responseData['error']?['message'] ?? 'Invalid response format from server',
            statusCode: response.statusCode ?? 500,
          );
        }
        // Clear the addresses cache after successful addition
        _addressesCache = null;
        return Address.fromJson(responseData['data']);
      }

      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Failed to add address',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while adding address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to add address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  Future<Address> updateAddress(String addressId, Address address) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final data = address.toJson();
      print('Updating address with data: $data');

      final response = await _dio.put(
        '/customers/addresses/$addressId',
        data: data,
      );
      
      // Clear both the addresses cache and the general cache
      _addressesCache = null;
      _addressesCacheTime = null;
      const cacheKey = 'GET:/customers/addresses';
      _cache.remove(cacheKey);
      
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          return Address.fromJson(responseData['data']);
        }
      }

      throw ApiException(
        message: 'Failed to update address',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.delete(
        '/customers/addresses/$addressId',
      );

      if (response.statusCode != 200 || response.data?['success'] != true) {
        throw ApiException(
          message: response.data?['error']?['message'] ?? 'Failed to delete address',
          statusCode: response.statusCode ?? 500,
        );
      }
      
      // Clear the addresses cache after successful deletion
      _addressesCache = null;
    } on DioException catch (e) {
      print('DioException while deleting address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to delete address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  Future<Address> setDefaultAddress(String addressId) async {
    final token = await _getCachedFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    try {
      final response = await _dio.patch(
        '/customers/addresses/$addressId/default',
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] != true || !responseData.containsKey('data')) {
          throw ApiException(
            message: responseData['error']?['message'] ?? 'Invalid response format from server',
            statusCode: response.statusCode ?? 500,
          );
        }
        
        // Clear the addresses cache after updating default
        _addressesCache = null;
        
        return Address.fromJson(responseData['data']);
      }

      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Failed to set default address',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while setting default address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to set default address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error setting default address: $e');
      rethrow;
    }
  }

  Future<OrdersResponse> getOrders({
    OrderStatus? status,
    required int page,
    required int limit,
  }) async {
    try {
      print('Fetching orders - page: $page, limit: $limit, status: ${status?.name}');
      
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status != OrderStatus.all) 'status': status.name,
      };

      print('Request URL: $_baseUrl/orders');
      print('Query params: $queryParams');
      print('Using auth token: ${token.substring(0, 10)}...');

      final response = await _dio.get(
        '/orders',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        return OrdersResponse.fromJson(response.data);
      }
      throw ApiException(
        message: 'Failed to fetch orders',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching orders: $e');
      rethrow;
    }
  }

  Future<OrdersResponse> getAllOrdersByEmail({
    required String email,
    OrderStatus? status,
    required int page,
    required int limit,
  }) async {
    try {
      print('Fetching all orders by email: $email - page: $page, limit: $limit, status: ${status?.name}');
      
      // Check that email is not null or empty
      if (email.isEmpty) {
        print('Error: Email is empty');
        throw ApiException(message: 'Email is required to fetch orders', statusCode: 400);
      }
      
      final token = await _getCachedFirebaseToken();
      if (token == null) {
        print('Error: No authentication token');
        throw ApiException(message: 'Please log in to continue', statusCode: 401);
      }

      final queryParams = {
        'email': email,
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status != OrderStatus.all) 'status': status.name,
      };

      print('Request URL: $_baseUrl/orders/customer/all-orders');
      print('Query params: $queryParams');
      
      try {
        final response = await _dio.get(
          '/orders/customer/all-orders',
          queryParameters: queryParams,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
            },
          ),
        );

        print('Response status: ${response.statusCode}');
        
        // Handle empty response or null data
        if (response.data == null) {
          print('Response data is null');
          return OrdersResponse(
            results: [],
            pagination: Pagination(total: 0, page: page, limit: limit),
          );
        }
        
        // Enhanced debugging for the response structure
        if (response.data is Map) {
          final responseMap = response.data as Map<String, dynamic>;
          
          // Print nested structure for debugging
          if (responseMap.containsKey('data') && responseMap['data'] is Map) {
            final dataMap = responseMap['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('results') && dataMap['results'] is List) {
              final results = dataMap['results'] as List;
              if (results.isNotEmpty && results.first is Map) {
                // Print only the first item for debugging
                final firstItem = results.first as Map<String, dynamic>;
                print('Sample order item structure:');
                firstItem.forEach((key, value) {
                  print('  $key: ${value?.runtimeType}');
                  
                  // Specifically log the items field structure
                  if (key == 'items' && value is List && value.isNotEmpty) {
                    print('    Sample item field structure:');
                    final firstOrderItem = value.first;
                    if (firstOrderItem is Map) {
                      firstOrderItem.forEach((itemKey, itemValue) {
                        print('      $itemKey: ${itemValue?.runtimeType}');
                      });
                    } else {
                      print('    First order item is not a Map: ${firstOrderItem.runtimeType}');
                    }
                  }
                });
              }
            }
          }
        }
        
        // Check response structure and adapt to different formats
        if (response.data is Map) {
          final responseMap = response.data as Map<String, dynamic>;
          
          // For format: { data: { results: [], pagination: {} } }
          if (responseMap['data'] is Map && 
              (responseMap['data'] as Map).containsKey('results')) {
            return OrdersResponse.fromJson(responseMap);
          }
          
          // For format: { results: [], pagination: {} }
          else if (responseMap.containsKey('results')) {
            // Add a data wrapper to match our parser
            return OrdersResponse.fromJson({
              'data': responseMap
            });
          }
          
          // For format: { data: [] }
          else if (responseMap['data'] is List) {
            final List<dynamic> results = responseMap['data'];
            print('Response contains direct result list: ${results.length} items');
            
            return OrdersResponse(
              results: results
                  .whereType<Map<String, dynamic>>()
                  .map((item) => Order.fromJson(item as Map<String, dynamic>))
                  .toList(),
              pagination: Pagination(
                total: results.length,
                page: page,
                limit: limit,
              ),
            );
          }
        }
        
        // Default parsing for standard format
        if (response.statusCode == 200) {
          return OrdersResponse.fromJson(response.data);
        }
        
        throw ApiException(
          message: 'Failed to fetch all orders',
          statusCode: response.statusCode ?? 500,
        );
      } on DioException catch (e) {
        print('DioException in getAllOrdersByEmail: $e');
        print('DioException type: ${e.type}');
        print('DioException message: ${e.message}');
        
        if (e.response != null) {
          print('DioException response status: ${e.response?.statusCode}');
          print('DioException response data: ${e.response?.data}');
        }
        
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout || 
            e.type == DioExceptionType.sendTimeout) {
          throw ApiException(
            message: 'Connection timeout. Please check your internet connection.',
            statusCode: 408,
          );
        }
        
        if (e.response?.statusCode == 401) {
          throw ApiException(
            message: 'Please log in to continue',
            statusCode: 401,
          );
        }
        
        rethrow;
      }
    } catch (e) {
      print('Error fetching all orders: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Failed to fetch orders: $e',
        statusCode: 500,
      );
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.get('/orders/$orderId');

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return Order.fromJson(data);
      }
      throw ApiException(
        message: 'Failed to fetch order',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching order: $e');
      rethrow;
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.delete('/orders/$orderId');

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to cancel order',
          statusCode: response.statusCode ?? 500,
        );
      }
    } catch (e) {
      print('Error canceling order: $e');
      rethrow;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Response> sendRequest(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getCachedFirebaseToken() : null;
      
      final options = Options(
        method: method,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        validateStatus: (status) {
          // Accept 302 status for payment redirects
          return status != null && (status < 400 || status == 302);
        },
      );

      final response = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response;
    } on DioException catch (e) {
      print('API Error: ${e.message}');
      print('Status code: ${e.response?.statusCode}');
      
      if (e.response?.statusCode == 401) {
        _clearTokenCache();
      }
      
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Request failed',
        statusCode: e.response?.statusCode ?? 500,
      );
    }
  }

  // Rewards API endpoints
  Future<CustomerReward?> getCustomerRewards() async {
    try {
      final response = await _dio.get('$_baseUrl/rewards');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CustomerReward.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching customer rewards: $e');
      return null;
    }
  }

  Future<bool> redeemPoints(int points) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/rewards/redeem',
        data: {'points': points},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error redeeming points: $e');
      return false;
    }
  }

  Future<Response> validateCoupon(String code, double total) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.post(
        '/coupons/$code/validate', 
        data: {
          'total': total,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['success'] == true && responseData['data'] != null) {
          return response;
        }
        throw ApiException(
          message: responseData['error']?['message'] ?? 'Invalid response format from server',
          statusCode: response.statusCode ?? 500,
        );
      }
      
      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Invalid coupon code',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while validating coupon: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to validate coupon',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error validating coupon: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _dio.post(
        '/customers/auth/social-login',
        data: {
          'provider': provider,
          'token': token,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }

      throw ApiException(
        message: 'Failed to sync social login with backend',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('Social Login Error: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw ApiException(
          message: 'Authentication failed',
          statusCode: 401,
        );
      }
      throw ApiException(
        message: e.message ?? 'Failed to connect to server',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Unexpected error in socialLogin: $e');
      throw ApiException(
        message: 'An unexpected error occurred',
        statusCode: 500,
      );
    }
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      // Get a fresh token
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw ApiException(
          message: 'User not authenticated',
          statusCode: 401,
        );
      }

      final token = await firebaseUser.getIdToken(true);
      if (token == null) {
        throw ApiException(
          message: 'Failed to get authentication token',
          statusCode: 401,
        );
      }

      print('Creating order with token: ${token.substring(0, 10)}...');

      // Calculate delivery charge based on emirate
      final isDelivery = orderData['deliveryMethod']?.toString().toUpperCase() == 'DELIVERY';
      final emirate = orderData['emirate']?.toString().toUpperCase() ?? 'DUBAI';
      final deliveryCharge = isDelivery ? (emirate == 'DUBAI' ? 30 : 50) : null;

      // Ensure all required fields are present and properly formatted
      final validatedOrderData = {
        'firstName': orderData['firstName'],
        'lastName': orderData['lastName'],
        'email': orderData['email'],
        'phone': orderData['phone'],
        'idempotencyKey': orderData['idempotencyKey'],
        'deliveryMethod': orderData['deliveryMethod']?.toString().toUpperCase(),
        'items': (orderData['items'] as List).map((item) => {
          'name': item['name'],
          'variant': item['variant']?.toString().toUpperCase() ?? '',
          'price': (item['price'] as num).floor(),
          'quantity': item['quantity'],
          'cakeWriting': item['cakeWriting'] ?? '',
        }).toList(),
        'subtotal': (orderData['subtotal'] as num).floor(),
        'total': (orderData['total'] as num).floor(),
        'paymentMethod': orderData['paymentMethod']?.toString().toUpperCase(),
        'isGift': orderData['isGift'] ?? false,
        'pointsRedeemed': orderData['pointsRedeemed'] ?? 0,
        'emirate': emirate, // Always include emirate
        'deliveryCharge': deliveryCharge, // Always include deliveryCharge (null for pickup)
      };

      // Add delivery-specific fields
      if (isDelivery) {
        validatedOrderData.addAll({
          'deliveryDate': orderData['deliveryDate'],
          'deliveryTimeSlot': orderData['deliveryTimeSlot'],
          'streetAddress': orderData['streetAddress'] ?? '',
          'apartment': orderData['apartment'] ?? '',
          'city': orderData['city'] ?? '',
          'pincode': orderData['pincode'] ?? '',
        });
      } else {
        validatedOrderData.addAll({
          'pickupDate': orderData['pickupDate'],
          'pickupTimeSlot': orderData['pickupTimeSlot'],
          'storeLocation': orderData['storeLocation'],
          'streetAddress': '', // Add empty strings for required fields
          'apartment': '',
          'city': '',
          'pincode': '',
        });
      }

      // Add gift-specific fields if it's a gift
      if (orderData['isGift'] == true) {
        validatedOrderData.addAll({
          'giftMessage': orderData['giftMessage'] ?? '',
          'giftRecipientName': orderData['giftRecipientName'] ?? '',
          'giftRecipientPhone': orderData['giftRecipientPhone'] ?? '',
        });
      }

      print('Sending validated order data: ${json.encode(validatedOrderData)}');

      final response = await _dio.post(
        '/orders',
        data: validatedOrderData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            print('Order creation status code: $status');
            return status! < 500;
          },
        ),
      );

      print('Order creation response status: ${response.statusCode}');
      print('Order creation response data: ${json.encode(response.data)}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            return responseData['data'];
          }
          return responseData;
        }
        throw ApiException(
          message: 'Invalid response format from server',
          statusCode: response.statusCode ?? 500,
        );
      }

      final errorMessage = response.data is Map 
          ? response.data['message'] ?? response.data['error']?.toString() ?? 'Failed to create order'
          : 'Failed to create order';

      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while creating order: ${e.message}');
      print('Response data: ${e.response?.data}');
      print('Request data: ${e.requestOptions.data}');
      print('Request headers: ${e.requestOptions.headers}');
      print('Response headers: ${e.response?.headers}');
      
      final errorMessage = e.response?.data is Map 
          ? e.response?.data['message'] ?? e.response?.data['error']?.toString() ?? 'Failed to create order'
          : 'Failed to create order';
          
      throw ApiException(
        message: errorMessage,
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error creating order: $e');
      throw ApiException(
        message: 'Failed to create order: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  // Clear all cached data
  Future<void> clearAllCache() async {
    try {
      // We no longer clear the token as it's needed for authentication persistence
      // await _setCachedFirebaseToken(null);
      
      // Clear any other cached data
      _cachedCustomerDetails = null;
      _cachedRewardPoints = null;
      _cachedOrders = null;
      _addressesCache = null;
      _addressesCacheTime = null;
      _cache.clear();
      
      // Reset interceptors
      _dio.interceptors.clear();
      _setupInterceptors();

      print('Successfully cleared all API cache');
    } catch (e) {
      print('Error clearing API cache: $e');
      rethrow;
    }
  }

  Future<void> clearOrdersCache() async {
    _cachedOrders = null;
    const cacheKey = 'GET:/orders';
    _cache.remove(cacheKey);
  }

  dynamic _getCachedData(String cacheKey) {
    final cachedData = _cache[cacheKey];
    if (cachedData != null) {
      final cacheTime = cachedData['timestamp'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cachedData['data'];
      }
      // Cache expired, remove it
      _cache.remove(cacheKey);
    }
    return null;
  }

  void _setCachedData(String cacheKey, dynamic data) {
    _cache[cacheKey] = {
      'data': data,
      'timestamp': DateTime.now(),
    };
  }

  // Public method to cache Firebase token that can be called from outside classes
  Future<void> cacheFirebaseToken(String token) async {
    print('Caching Firebase token...');
    await _setCachedFirebaseToken(token);
  }

  // Clear the cached Firebase token
  Future<void> clearCachedFirebaseToken() async {
    _cachedToken = null;
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: 'firebase_token');
      print('Firebase token cleared from secure storage');
    } catch (e) {
      print('Error clearing Firebase token: $e');
    }
  }

  // Register device token for push notifications
  Future<bool> registerDeviceToken(String token, String platform) async {
    try {
      print('API Service: Starting FCM token registration');
      final email = await getCachedCustomerEmailAsync();
      print('API Service: Cached email: ${email ?? 'null'}');
      
      if (email == null || email.isEmpty) {
        print('API Service: No logged in user to register device token');
        return false;
      }

      print('API Service: Registering FCM token for email: $email');
      print('API Service: Token: $token');
      print('API Service: Platform: $platform');

      // Create a separate Dio instance without auth interceptors for public endpoint
      final publicDio = Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ));
      
      print('API Service: Created public Dio instance');
      print('API Service: Base URL: ${publicDio.options.baseUrl}');

      // Use the public endpoint that doesn't require authentication
      print('API Service: Sending request to register-fcm-token-public endpoint');
      try {
        final response = await publicDio.post(
          '/customer-auth/register-fcm-token-public',
          data: {
            'token': token,
            'email': email,
            'platform': platform,
          },
        );

        print('API Service: FCM token registration response status: ${response.statusCode}');
        print('API Service: FCM token registration response data: ${response.data}');

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (requestError) {
        print('API Service: Error making FCM token registration request: $requestError');
        
        // Try the authenticated endpoint as a fallback
        print('API Service: Trying authenticated endpoint as fallback');
        try {
          final authResponse = await _dio.post(
            '/customer-auth/fcm-token',
            data: {
              'token': token,
              'platform': platform,
            },
            options: Options(
              headers: await getAuthHeaders(),
            ),
          );
          
          print('API Service: Authenticated FCM token registration response: ${authResponse.statusCode}');
          print('API Service: Authenticated FCM token registration data: ${authResponse.data}');
          
          return authResponse.statusCode == 200 || authResponse.statusCode == 201;
        } catch (authError) {
          print('API Service: Error with authenticated endpoint too: $authError');
          return false;
        }
      }
    } catch (e) {
      print('API Service: Error registering device token: $e');
      print('API Service: Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Unregister device token
  Future<bool> unregisterDeviceToken(String token) async {
    try {
      print('Unregistering FCM token: $token');
      
      // Check if we have a cached email to use for token unregistration
      final email = await getCachedCustomerEmailAsync();
      if (email == null || email.isEmpty) {
        print('No cached email available for FCM token unregistration');
        return false;
      }
      
      // Create a separate Dio instance without auth interceptors
      final publicDio = Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ));
      
      // Use the public endpoint that doesn't require authentication
      final response = await publicDio.post(
        '/customer-auth/unregister-fcm-token-public',
        data: {
          'token': token,
          'email': email,
        },
      );

      print('FCM token unregistration response: ${response.statusCode}');
      print('FCM token unregistration data: ${response.data}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error unregistering device token: $e');
      return false;
    }
  }

  // Get unread notifications count
  Future<Map<String, dynamic>> getUnreadNotificationsCount(int lastReadTime) async {
    try {
      final email = await getCachedCustomerEmailAsync();
      if (email == null || email.isEmpty) {
        print('No logged in user to get unread notifications count');
        return {'count': 0};
      }

      final response = await _dio.get(
        '/customer/notifications/unread-count',
        queryParameters: {
          'since': lastReadTime.toString(),
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'count': 0};
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return {'count': 0};
    }
  }

  // Get customer notifications
  Future<Map<String, dynamic>> getCustomerNotifications({
    required int page,
    required int limit,
  }) async {
    try {
      final email = await getCachedCustomerEmailAsync();
      if (email == null || email.isEmpty) {
        print('No logged in user to get notifications');
        return {'notifications': [], 'pagination': {'hasMore': false}};
      }

      final response = await _dio.get(
        '/customer/notifications',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'notifications': [], 'pagination': {'hasMore': false}};
    } catch (e) {
      print('Error getting customer notifications: $e');
      return {'notifications': [], 'pagination': {'hasMore': false}};
    }
  }
}

class Product {
  Product.fromJson(Map<String, dynamic> json);
}

class ApiError {
  final String message;
  final int statusCode;

  ApiError({required this.message, required this.statusCode});
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException({
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}

class OrdersResponse {
  final List<Order> results;
  final Pagination pagination;

  OrdersResponse({
    required this.results,
    required this.pagination,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing OrdersResponse from JSON: ${json.keys}');
      
      // Handle case where data might be null or not a map
      final data = json['data'];
      if (data == null) {
        print('Warning: OrdersResponse data is null');
        return OrdersResponse(
          results: [],
          pagination: Pagination(total: 0, page: 1, limit: 10),
        );
      }
      
      print('Data type: ${data.runtimeType}');
      
      // If data is not a Map, check if json itself has the right structure
      Map<String, dynamic> dataMap;
      if (data is Map<String, dynamic>) {
        dataMap = data;
      } else if (json['results'] != null && json['pagination'] != null) {
        print('Found results directly in json, not in data');
        dataMap = json;
      } else {
        print('Data is not in expected format: $data');
        return OrdersResponse(
          results: [],
          pagination: Pagination(total: 0, page: 1, limit: 10),
        );
      }
      
      // Handle results safely
      print('Looking for results in dataMap: ${dataMap.keys}');
      final resultsList = dataMap['results'];
      List<Order> orders = [];
      if (resultsList is List) {
        print('Results list contains ${resultsList.length} items');
        
        // Process each result individually with separate error handling
        for (var i = 0; i < resultsList.length; i++) {
          try {
            final item = resultsList[i];
            if (item is Map<String, dynamic>) {
              // Try to parse the order, with detailed logging if it fails
              try {
                final order = Order.fromJson(item);
                orders.add(order);
                print('Successfully parsed order ${i+1}: ${order.id}');
              } catch (e) {
                print('Failed to parse order ${i+1}: $e');
                // Log the problematic order data for debugging
                print('Problematic order data: ${item.keys}');
              }
            } else {
              print('Result item ${i+1} is not a map: ${item?.runtimeType}');
            }
          } catch (e) {
            print('Error processing result item ${i+1}: $e');
          }
        }
        print('Successfully parsed ${orders.length} orders out of ${resultsList.length}');
      } else {
        print('Results is not a List: ${resultsList?.runtimeType}');
      }
      
      // Handle pagination safely
      final paginationData = dataMap['pagination'];
      Pagination pagination;
      if (paginationData is Map<String, dynamic>) {
        print('Parsing pagination: $paginationData');
        pagination = Pagination.fromJson(paginationData);
      } else {
        print('Pagination data is not a Map: ${paginationData?.runtimeType}');
        pagination = Pagination(total: 0, page: 1, limit: 10);
      }
      
      print('Orders response created with ${orders.length} orders, pagination total: ${pagination.total}');
      return OrdersResponse(
        results: orders,
        pagination: pagination,
      );
    } catch (e) {
      print('Error parsing OrdersResponse: $e');
      // Return empty results as fallback
      return OrdersResponse(
        results: [],
        pagination: Pagination(total: 0, page: 1, limit: 10),
      );
    }
  }
}

class Pagination {
  final int total;
  final int page;
  final int limit;

  Pagination({
    required this.total,
    required this.page,
    required this.limit,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] is int ? json['total'] : 0,
      page: json['page'] is int ? json['page'] : 1,
      limit: json['limit'] is int ? json['limit'] : 10,
    );
  }
}
