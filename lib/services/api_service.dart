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
  int? _cachedRewardPoints;
  List<dynamic>? _cachedOrders;
  String? _cachedToken;

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
        retryableExtraStatuses: {408, 429},
      ),
    );

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
        final token = await _getCachedFirebaseToken();
        print('Token available: ${token != null}');
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        print('Status code: ${error.response?.statusCode}');
        if (error.response?.statusCode == 401) {
          _clearTokenCache();
          firebase_auth.FirebaseAuth.instance.signOut();
        }
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
        '/customers/auth/register',
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
  }) async {
    final token = await _getCachedFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.post(
      '/customers/auth/login',
      data: {
        'email': email,
      },
    );

    if (response.statusCode == 200) {
      return response.data['data'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
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
      
      print('Sending social auth request with token: ${token.substring(0, 10)}...');
      
      final response = await _dio.post(
        '/customers/auth/social',
        data: {
          'token': token, // Send token in request body
          'provider': provider,
          'email': email,
          'firstName': firstName,
          'lastName': lastName ?? '',
          'imageUrl': imageUrl,
          'phone': phone,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => true, // Allow any status code for better error handling
        ),
      );

      print('Social auth response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['data'] == null) {
          throw ApiException(
            message: 'Invalid response format from server: missing data field',
            statusCode: 500,
          );
        }
        return response.data['data'];
      }

      final errorMessage = response.data is Map ? response.data['message'] ?? 'Social authentication failed' : 'Social authentication failed';
      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Social Auth Error: $e');
      if (e is DioException) {
        final responseData = e.response?.data;
        final errorMessage = responseData is Map ? responseData['message'] ?? e.message : e.message;
        throw ApiException(
          message: errorMessage ?? 'Social authentication failed',
          statusCode: e.response?.statusCode ?? 500,
        );
      }
      rethrow;
    }
  }

  Future<CustomerDetails> getCustomerDetails() async {
    if (_cachedCustomerDetails != null) {
      return _cachedCustomerDetails!;
    }
    
    final response = await _dio.get('/customers/profile');
    
    if (response.statusCode == 200) {
      _cachedCustomerDetails = CustomerDetails.fromJson(response.data['data']);
      return _cachedCustomerDetails!;
    } else {
      throw ApiException(
        message: 'Failed to get customer details',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<CustomerDetails> getCurrentCustomer() async {
    return getCustomerDetails();
  }

  Future<CustomerDetails> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
  }) async {
    final response = await _dio.put(
      '/customers/auth/profile',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      },
    );

    if (response.statusCode == 200) {
      _cachedCustomerDetails = CustomerDetails.fromJson(response.data['data']['customer']);
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
      final cacheKey = 'GET:/customers/addresses';
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
            'Content-Type': 'application/json',
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
      throw ApiException(
        message: 'Failed to fetch orders: ${e.toString()}',
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
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      // First create or get customer
      final customerData = {
        'email': orderData['email'],
        'firstName': orderData['firstName'],
        'lastName': orderData['lastName'],
        'phone': orderData['phone'],
      };

      print('Creating/updating customer with data: $customerData');
      try {
        final customerResponse = await _dio.post(
          '/customers',
          data: customerData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        print('Customer creation/update response: ${customerResponse.data}');
      } catch (e) {
        print('Customer already exists or error creating: $e');
        // We can ignore this error as the customer might already exist
      }

      // Now create the order
      print('Creating order with data: ${json.encode(orderData)}');
      final response = await _dio.post(
        '/orders',
        data: orderData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Order creation response status: ${response.statusCode}');
      print('Order creation response data: ${json.encode(response.data)}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'];
        }
        throw ApiException(
          message: responseData['error']?['message'] ?? 'Invalid response format',
          statusCode: response.statusCode ?? 500,
        );
      }

      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Failed to create order',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while creating order: ${e.message}');
      print('Response data: ${e.response?.data}');
      print('Request data: ${e.requestOptions.data}');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to create order',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  // Clear all cached data
  Future<void> clearAllCache() async {
    try {
      // Clear the cached token
      await _setCachedFirebaseToken(null);
      
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
    final data = json['data'] as Map<String, dynamic>;
    return OrdersResponse(
      results: (data['results'] as List<dynamic>)
          .map((item) => Order.fromJson(item))
          .toList(),
      pagination: Pagination.fromJson(data['pagination']),
    );
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
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}
