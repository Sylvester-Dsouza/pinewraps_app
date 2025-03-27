import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/environment.dart';
import '../services/api_service.dart' as api; // Import ApiService with alias

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  // Get base URL from environment config
  String get baseUrl => EnvironmentConfig.apiBaseUrl;
  
  // API Service instance for use with notification icon
  final api.ApiService apiService = api.ApiService();

  Future<List<Product>> getAllProducts({int page = 1, int limit = 20, String? category}) async {
    try {
      // Build URL with query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
      };
      
      final uri = Uri.parse('$baseUrl/products/public').replace(queryParameters: queryParams);
      print('Fetching products from: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your server settings and internet connection.');
        },
      );
      
      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Extract products from the nested data structure
          final productsData = jsonResponse['data']['products'] as List<dynamic>;
          
          print('Received ${productsData.length} products');
          return productsData
              .map((json) => Product.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          print('Invalid API response format: $jsonResponse');
          throw Exception('Invalid API response format');
        }
      } else {
        print('Failed to load products: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('SocketException when fetching products: $e');
      if (e.message.contains('Connection refused')) {
        String helpText = '';
        if (EnvironmentConfig.isDevelopment) {
          if (Platform.isAndroid) {
            helpText = '\n\nYou seem to be running on a physical device. '
                'Make sure the API server is running and check if the IP address '
                'in the environment config (${Uri.parse(baseUrl).host}) is correct for your network.';
          }
        }
        throw Exception('Could not connect to the server.$helpText');
      }
      throw Exception('Network error: ${e.message}');
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please check your server settings and internet connection.');
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<Product> getProduct(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/products/public/$id');
      print('Fetching product from: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your server settings and internet connection.');
        },
      );
      
      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Log the full product data for debugging
          final productData = jsonResponse['data'] as Map<String, dynamic>;
          print('Product data received: ${productData.keys.join(', ')}');
          
          // Log variants and options structure
          if (productData['options'] != null) {
            final options = productData['options'] as List<dynamic>;
            print('Product has ${options.length} option types:');
            for (var i = 0; i < options.length; i++) {
              final option = options[i] as Map<String, dynamic>;
              final values = option['values'] as List<dynamic>;
              print('Option ${i+1}: ${option['name']} has ${values.length} values');
              for (var j = 0; j < values.length; j++) {
                final value = values[j] as Map<String, dynamic>;
                print(' - Value ${j+1}: ${value['value']}, price adjustment: ${value['priceAdjustment']}');
              }
            }
          } else {
            print('Product has no options defined');
          }
          
          // Log variant combinations if available
          if (productData['variantCombinations'] != null) {
            final combinations = productData['variantCombinations'];
            if (combinations is List && combinations.isNotEmpty) {
              print('Product has ${combinations.length} variant combinations:');
              for (var i = 0; i < min(5, combinations.length); i++) { // Show first 5 for brevity
                print(' - Combination ${i+1}: ${combinations[i]}');
              }
              if (combinations.length > 5) {
                print(' - ... and ${combinations.length - 5} more combinations');
              }
            } else {
              print('Product has empty or invalid variant combinations');
            }
          } else {
            print('Product has no variant combinations defined');
          }
          
          return Product.fromJson(productData);
        } else {
          print('Invalid API response format: $jsonResponse');
          throw Exception('Invalid API response format');
        }
      } else {
        print('Failed to load product: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('SocketException when fetching product: $e');
      if (e.message.contains('Connection refused')) {
        String helpText = '';
        if (EnvironmentConfig.isDevelopment) {
          if (Platform.isAndroid) {
            helpText = '\n\nYou seem to be running on a physical device. '
                'Make sure the API server is running and check if the IP address '
                'in the environment config (${Uri.parse(baseUrl).host}) is correct for your network.';
          }
        }
        throw Exception('Could not connect to the server.$helpText');
      }
      throw Exception('Network error: ${e.message}');
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please check your server settings and internet connection.');
    } catch (e) {
      print('Error fetching product: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<List<Product>> getProductsByCategory(String categoryId, {int page = 1, int limit = 20}) async {
    try {
      // Build URL with query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'category': categoryId,
      };
      
      final uri = Uri.parse('$baseUrl/products/public').replace(queryParameters: queryParams);
      print('Fetching products by category from: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your server settings and internet connection.');
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Extract products from the nested data structure
          final productsData = jsonResponse['data']['products'] as List<dynamic>;
          
          print('Received ${productsData.length} products for category $categoryId (page $page)');
          return productsData
              .map((json) => Product.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          print('Invalid API response format for category products: $jsonResponse');
          throw Exception('Invalid API response format');
        }
      } else {
        print('Failed to load category products: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load category products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products by category: $e');
      throw Exception('Failed to load products for this category');
    }
  }

  Future<List<Product>> searchProducts(String query, {int page = 1, int limit = 20}) async {
    try {
      // Build URL with query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'search': query
      };
      
      final uri = Uri.parse('$baseUrl/products/public').replace(queryParameters: queryParams);
      print('Searching products from: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your server settings and internet connection.');
        },
      );
      
      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Extract products from the nested data structure
          final productsData = jsonResponse['data']['products'] as List<dynamic>;
          
          print('Received ${productsData.length} products from search');
          return productsData
              .map((json) => Product.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          print('Invalid API response format: $jsonResponse');
          throw Exception('Invalid API response format');
        }
      } else {
        print('Failed to search products: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('SocketException when searching products: $e');
      if (e.message.contains('Connection refused')) {
        String helpText = '';
        if (EnvironmentConfig.isDevelopment) {
          if (Platform.isAndroid) {
            helpText = '\n\nYou seem to be running on a physical device. '
                'Make sure the API server is running and check if the IP address '
                'in the environment config (${Uri.parse(baseUrl).host}) is correct for your network.';
          }
        }
        throw Exception('Could not connect to the server.$helpText');
      }
      throw Exception('Network error: ${e.message}');
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please check your server settings and internet connection.');
    } catch (e) {
      print('Error searching products: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<List<ProductCategory>> getCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/categories/public');
      print('Fetching categories from: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your server settings and internet connection.');
        },
      );
      
      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final categoriesData = jsonResponse['data'] as List<dynamic>;
          
          print('Received ${categoriesData.length} categories');
          return categoriesData
              .map((json) => ProductCategory.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          // If categories API fails, try to extract them from products
          final products = await getAllProducts();
          
          // Extract unique categories from products
          final Map<String, ProductCategory> uniqueCategories = {};
          for (var product in products) {
            if (product.category.id.isNotEmpty) {
              uniqueCategories[product.category.id] = product.category;
            }
          }
          
          return uniqueCategories.values.toList();
        }
      } else {
        print('Failed to load categories, extracting from products');
        // Fall back to extracting categories from products
        final products = await getAllProducts();
        
        // Extract unique categories from products
        final Map<String, ProductCategory> uniqueCategories = {};
        for (var product in products) {
          if (product.category.id.isNotEmpty) {
            uniqueCategories[product.category.id] = product.category;
          }
        }
        
        return uniqueCategories.values.toList();
      }
    } on SocketException catch (e) {
      print('SocketException when fetching categories: $e');
      if (e.message.contains('Connection refused')) {
        String helpText = '';
        if (EnvironmentConfig.isDevelopment) {
          if (Platform.isAndroid) {
            helpText = '\n\nYou seem to be running on a physical device. '
                'Make sure the API server is running and check if the IP address '
                'in the environment config (${Uri.parse(baseUrl).host}) is correct for your network.';
          }
        }
        throw Exception('Could not connect to the server.$helpText');
      }
      throw Exception('Network error: ${e.message}');
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please check your server settings and internet connection.');
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Failed to get categories: $e');
    }
  }
}
