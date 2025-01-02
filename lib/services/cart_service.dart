import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  
  final List<CartItem> _cartItems = [];
  final _cartCountNotifier = ValueNotifier<int>(0);

  CartService._internal() {
    _loadCartFromPrefs();
  }

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  Stream<List<CartItem>> get cartStream => Stream.value(_cartItems);
  ValueNotifier<int> get cartCountNotifier => _cartCountNotifier;
  
  double get totalPrice => _cartItems.fold(
    0, 
    (total, item) => total + item.totalPrice
  );

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart_items');
      if (cartData != null) {
        final List<dynamic> decodedData = json.decode(cartData);
        // We'll need to load products first before reconstructing cart items
        _cartCountNotifier.value = decodedData.length;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cart: $e');
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = json.encode(
        _cartItems.map((item) => {
          'id': item.id,
          'productId': item.product.id,
          'selectedSize': item.selectedSize,
          'selectedFlavour': item.selectedFlavour,
          'cakeText': item.cakeText,
          'quantity': item.quantity,
          'price': item.price,
        }).toList()
      );
      await prefs.setString('cart_items', cartData);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  void addToCart({
    required Product product,
    String? selectedSize,
    String? selectedFlavour,
    String? cakeText,
    required int quantity,
  }) {
    final existingItemIndex = _cartItems.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedSize == selectedSize &&
          item.selectedFlavour == selectedFlavour &&
          item.cakeText == cakeText,
    );

    if (existingItemIndex != -1) {
      final existingItem = _cartItems[existingItemIndex];
      _cartItems[existingItemIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity
      );
    } else {
      _cartItems.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        product: product,
        selectedSize: selectedSize,
        selectedFlavour: selectedFlavour,
        cakeText: cakeText,
        quantity: quantity,
        price: product.getPriceForVariations(selectedSize, selectedFlavour),
      ));
    }
    
    _cartCountNotifier.value = _cartItems.length;
    _saveCartToPrefs();
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    _cartItems.removeWhere((item) => item.id == itemId);
    _cartCountNotifier.value = _cartItems.length;
    _saveCartToPrefs();
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        final item = _cartItems[index];
        _cartItems[index] = item.copyWith(quantity: quantity);
      }
      _cartCountNotifier.value = _cartItems.length;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    _cartCountNotifier.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_items');
    notifyListeners();
  }

  void dispose() {
    _cartCountNotifier.dispose();
  }
}
