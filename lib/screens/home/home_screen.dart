import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import '../../widgets/app_drawer.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../product/product_details_screen.dart';
import '../shop/shop_screen.dart';
import '../main_screen.dart';
import '../notifications/notification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/notification_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      print('Home screen: Loading featured products');
      // Use the product service to get a limited number of products for the home screen
      final products = await _productService.getAllProducts(limit: 8);
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
        print('Home screen: Loaded ${products.length} products successfully');
      }
    } catch (e) {
      print('Error in _loadProducts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          // Extract the most user-friendly part of the error message
          String errorMsg = e.toString();
          if (errorMsg.contains('Could not connect to the server')) {
            if (errorMsg.contains('physical device')) {
              // This is a special error message we added for physical devices
              _error = errorMsg;
            } else {
              _error = 'Could not connect to the server. Please check if the server is running.';
            }
          } else if (errorMsg.contains('Connection timed out')) {
            _error = 'Connection timed out. Please check your internet connection.';
          } else if (errorMsg.contains('Connection refused')) {
            _error = 'Could not connect to the server. If you\'re using a physical device, make sure the server IP address is correct.';
          } else {
            // Limit error message length to avoid UI issues
            if (errorMsg.length > 100) {
              errorMsg = '${errorMsg.substring(0, 100)}...';
            }
            _error = 'Failed to load products: $errorMsg';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          const NotificationIcon(),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/banner_bg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Welcome to Pinewraps",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainScreen(initialIndex: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Shop Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Shop by Category
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'SHOP BY CATEGORY',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.grey[300])),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Category Cards
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryCard(
                  'Cakes',
                  'Delicious Cakes for all occasions',
                  LineIcons.birthdayCake,
                ),
                const SizedBox(height: 14),
                _buildCategoryCard(
                  'Flowers',
                  'Beautiful Flower Arrangements',
                  LineIcons.seedling,
                ),
                const SizedBox(height: 14),
                _buildCategoryCard(
                  'Sets',
                  'Combinations of Cakes and Flowers',
                  LineIcons.gift,
                ),
              ],
            ),

            const SizedBox(height: 50),

            // New Arrivals
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'NEW ARRIVALS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.grey[300])),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // New Arrivals Grid
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'No products available',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 20,
                      children: _products
                          .take(4)
                          .map((product) => SizedBox(
                                width: cardWidth,
                                child: _buildProductCard(product),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),

            // Earn Points Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LineIcons.star,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Earn Points with Every Order',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Redeem Points for Rewards',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPointsFeature(
                        context,
                        LineIcons.shoppingBag,
                        'Shop & Earn',
                        'Points on purchases',
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[200],
                      ),
                      _buildPointsFeature(
                        context,
                        LineIcons.gift,
                        'Redeem',
                        'For exclusive rewards',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, String items, IconData icon) {
    String imagePath = 'assets/images/category_${title.toLowerCase()}.jpg';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              initialIndex: 1,
              shopCategory: title,
            ),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                items,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(productId: product.id),
          ),
        );
      },
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Use minimum space needed
            children: [
              // Product Image
              AspectRatio(
                aspectRatio: 1.0, // Enforce 1:1 aspect ratio
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(product.images.first.url),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // Product Details
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Use minimum space needed
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2, // Allow two lines for product name
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Price
                    Text(
                      '${product.price.toStringAsFixed(2)} AED',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsFeature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.black,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
