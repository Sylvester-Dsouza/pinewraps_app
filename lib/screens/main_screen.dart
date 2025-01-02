import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'shop/shop_screen.dart';
import 'profile/profile_screen.dart';
import 'cart/cart_screen.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final CartService _cartService = CartService();
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _updateCartCount();
    // Listen to cart changes
    _cartService.cartStream.listen((items) {
      if (mounted) {
        _updateCartCount();
      }
    });
  }

  void _updateCartCount() {
    setState(() {
      _cartItemCount = _cartService.cartItems.length;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          ShopScreen(),
          CartScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('$_cartItemCount'),
              isLabelVisible: _cartItemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: Badge(
              label: Text('$_cartItemCount'),
              isLabelVisible: _cartItemCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
