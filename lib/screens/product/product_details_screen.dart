import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../cart/cart_screen.dart';
import '../../widgets/modern_notification.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final TextEditingController _cakeTextController = TextEditingController();
  bool _mounted = true;

  Product? _product;
  bool _isLoading = true;
  String? _error;
  String? _selectedSize;
  String? _selectedFlavour;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _loadProduct();
    _updateCartCount();
    // Listen to cart changes
    _cartService.cartStream.listen((items) {
      if (_mounted) {
        setState(() {
          _cartItemCount = items.length;
        });
      }
    });
  }

  void _updateCartCount() {
    if (_mounted) {
      setState(() {
        _cartItemCount = _cartService.cartItems.length;
      });
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _cakeTextController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (!_mounted) return;

    try {
      final product = await _productService.getProduct(widget.productId);
      if (!_mounted) return;

      setState(() {
        _product = product;
        _isLoading = false;
        print('Product Category: ${_product?.category.name}'); // Debug log
        
        // Set initial selections
        if (_product != null) {
          final flavours = _product!.flavours;
          if (flavours.isNotEmpty) {
            _selectedFlavour = flavours.first;
          }

          final sizes = _product!.sizes;
          if (sizes.isNotEmpty) {
            _selectedSize = sizes.first;
          }
        }
      });
    } catch (e) {
      if (!_mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _getPrice() {
    if (_product == null) return 0;
    
    // If product has no variations, return base price
    if (_product!.sizes.isEmpty && _product!.flavours.isEmpty) {
      return _product!.basePrice;
    }
    
    // If product has variations, get combination price
    final price = _product!.getPriceForVariations(_selectedSize, _selectedFlavour);
    return price > 0 ? price : _product!.basePrice;
  }

  Future<void> _addToCart() async {
    if (_product == null) return;

    // Only check for variations if they exist
    final hasVariations = _product!.sizes.isNotEmpty || _product!.flavours.isNotEmpty;
    final variationsSelected = !hasVariations || 
        (_product!.sizes.isEmpty || _selectedSize != null) && 
        (_product!.flavours.isEmpty || _selectedFlavour != null);

    if (!variationsSelected) {
      ModernNotification.show(
        context: context,
        message: 'Please select all required options',
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    String cakeText = '';
    if (_product!.category.name.toLowerCase() == 'cake' || _product!.category.name.toLowerCase() == 'cakes') {
      cakeText = _cakeTextController.text.trim();
    }

    _cartService.addToCart(
      product: _product!,
      selectedSize: _selectedSize ?? '',
      selectedFlavour: _selectedFlavour ?? '',
      cakeText: cakeText,
      quantity: 1,
    );

    if (!_mounted) return;

    ModernNotification.show(
      context: context,
      message: 'Added to cart',
      actionLabel: 'VIEW CART',
      onActionPressed: () {
        if (!_mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CartScreen(),
          ),
        );
      },
    );
  }

  Widget _buildSizeOption(String size) {
    final isSelected = _selectedSize == size;
    final sizeVariation = _product!.getVariationByType('SIZE');
    final sizeOption = sizeVariation?.options.firstWhere((o) => o.value == size);
    final priceAdjustment = sizeOption?.priceAdjustment ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (!_mounted) return;
          setState(() {
            _selectedSize = size;
            _updatePrice();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Text(
                size,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              if (priceAdjustment > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+${priceAdjustment.toStringAsFixed(0)} AED',
                  style: TextStyle(
                    color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _updatePrice() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _product == null
                  ? const Center(child: Text('Product not found'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_product!.imageUrl != null)
                            Stack(
                              children: [
                                Image.network(
                                  _product!.imageUrl!,
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.height * 0.45,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: MediaQuery.of(context).padding.top + 8,
                                  left: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back, size: 20),
                                      color: Colors.black,
                                      onPressed: () {
                                        if (!_mounted) return;
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _product!.name,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Text(
                                            //   'Starting from ${_product!.basePrice.toStringAsFixed(0)} AED',
                                            //   style: TextStyle(
                                            //     fontSize: 16,
                                            //     color: Colors.grey[600],
                                            //     height: 1.2,
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 50),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _product!.category.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_product!.description.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      _product!.description,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        height: 1.5,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (_product!.sizes.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Text(
                                          'Select Size',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _product!.sizes.map((size) => _buildSizeOption(size)).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                  ],
                                  if (_product!.flavours.isNotEmpty) ...[
                                    const Text(
                                      'Select Flavour',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedFlavour,
                                          hint: const Text('Choose a flavour'),
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down),
                                          elevation: 2,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 15,
                                          ),
                                          items: _product!.flavours.map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              _selectedFlavour = newValue;
                                              _updatePrice();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (_product!.category.name.toLowerCase() == 'cakes' || _product!.category.name.toLowerCase() == 'cake') ...[
                                    const Text(
                                      'Add Text on Cake',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _cakeTextController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter text to be written on cake',
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        maxLength: 100,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: _product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Add to Cart • ${_getPrice().toStringAsFixed(0)} AED',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (_cartItemCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _cartItemCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
