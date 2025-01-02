import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/environment.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  // Get base URL from environment config
  String get baseUrl => EnvironmentConfig.baseUrl;

  Future<List<Product>> getAllProducts() async {
    try {
      print('Fetching products from: $baseUrl/api/products/public');
      final response = await http.get(Uri.parse('$baseUrl/api/products/public'));
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<Product> getProduct(String id) async {
    try {
      print('Fetching product from: $baseUrl/api/products/public/$id');
      final response = await http.get(Uri.parse('$baseUrl/api/products/public/$id'));
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        return Product.fromJson(data);
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching product: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      print('Fetching products by category from: $baseUrl/api/products?category=$category');
      final response = await http.get(
        Uri.parse('$baseUrl/api/products?category=$category'),
      );
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products by category: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      print('Searching products from: $baseUrl/api/products/search?q=$query');
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/search?q=$query'),
      );
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching products: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<List<ProductCategory>> getCategories() async {
    try {
      // Get all products since categories come with products
      final products = await getAllProducts();
      
      // Extract unique categories from products
      final Map<String, ProductCategory> uniqueCategories = {};
      for (var product in products) {
        uniqueCategories[product.category.id] = product.category;
      }
      
      return uniqueCategories.values.toList();
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Failed to get categories: $e');
    }
  }
}
