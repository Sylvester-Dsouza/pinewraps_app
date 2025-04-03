import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/modern_notification.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart' as dom;
import 'package:flutter_html/flutter_html.dart';

// Extension method to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

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
  bool _mounted = false;
  Product? _product;
  bool _isLoading = true;
  String? _error;
  String? _selectedSize;
  String? _selectedFlavour;
  int _cartItemCount = 0;
  double _currentPrice = 0;
  final TextEditingController _cakeTextController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  // State for Sets category cake flavors
  List<Map<String, dynamic>> _cakeFlavors = [];
  bool _allCakeFlavorsSelected = false;

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
    _pageController.dispose();
    super.dispose();
  }

  // Check if product is in Sets category
  bool get _isSetCategory {
    if (_product == null) return false;

    return _product!.categoryId.toLowerCase() == 'sets' ||
        _product!.category.name.toLowerCase() == 'sets' ||
        _product!.name.toLowerCase().contains('set of') ||
        _product!.description.toLowerCase().contains('set of 4');
  }

  Future<void> _loadProduct() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final product = await _productService.getProduct(widget.productId);
      if (!mounted) return;

      // Debug product details
      print('\n===== PRODUCT DETAILS =====');
      print('Name: ${product.name}');
      print('Base Price: ${product.basePrice}');
      print('Has ${product.variations.length} variations');
      print(
          'Has ${product.flavours.length} flavours and ${product.sizes.length} sizes');

      if (product.flavours.isNotEmpty) {
        print('Available flavours: ${product.flavours.join(", ")}');
      }

      if (product.sizes.isNotEmpty) {
        print('Available sizes: ${product.sizes.join(", ")}');
      }

      // Setup initial selections from available options
      String? initialSize;
      String? initialFlavour;

      // Get the first size option if available
      if (product.sizes.isNotEmpty) {
        initialSize = product.sizes.first;
      }

      // Get the first flavour option if available
      if (product.flavours.isNotEmpty) {
        initialFlavour = product.flavours.first;
      }

      // Calculate initial price based on selections
      double initialPrice = product.basePrice;
      if (initialSize != null || initialFlavour != null) {
        initialPrice =
            product.getPriceForVariations(initialSize, initialFlavour);
      }

      print(
          'Initial setup - Size: $initialSize, Flavour: $initialFlavour, Price: $initialPrice');

      setState(() {
        _product = product;
        _selectedSize = initialSize;
        _selectedFlavour = initialFlavour;
        _currentPrice = initialPrice;
        _isLoading = false;
      });

      // Initialize cake flavors for Sets category
      if (_isSetCategory) {
        // Get all variations from the product
        List<ProductVariation> availableVariations = _product!.variations;

        // If no variations are available, don't show the UI
        if (availableVariations.isEmpty) {
          return;
        }

        // Try to get flavor variation first
        ProductVariation? selectedVariation =
            _product!.getVariationByType('FLAVOUR');

        // If no flavor variation, use the first available variation
        if (selectedVariation == null) {
          selectedVariation = availableVariations.first;
        }

        List<ProductOption> variationOptions = selectedVariation.options;
        String variationType = selectedVariation.type;

        // Initialize with default flavor for all 4 cakes
        List<Map<String, dynamic>> initialFlavors = [];
        for (int i = 1; i <= 4; i++) {
          initialFlavors.add({
            'cakeNumber': i,
            'flavorId':
                variationOptions.isNotEmpty ? variationOptions.first.value : '',
            'variationType': variationType,
          });
        }

        setState(() {
          _cakeFlavors = initialFlavors;
          _allCakeFlavorsSelected = true;
        });

        // Recalculate price with flavors
        _updateCartPrice();
      }

      // Prefetch images after product is loaded
      await _prefetchImages();

      // Get cart count
      setState(() {
        _cartItemCount = _cartService.cartItems.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _calculatePrice() {
    if (_product == null) return 0;

    print('\nCalculating price:');
    print('Selected Size: $_selectedSize');
    print('Selected Flavour: $_selectedFlavour');
    print('Number of variations: ${_product!.variations.length}');

    // For Sets category, calculate price based on selected cake flavors
    if (_isSetCategory) {
      double totalPrice = _product!.basePrice;
      print('Base price for set: $totalPrice');

      // Add price adjustments for each cake flavor
      for (var flavor in _cakeFlavors) {
        String flavorId = flavor['flavorId'];
        String variationType = flavor['variationType'] ?? 'FLAVOUR';

        if (flavorId.isNotEmpty) {
          // Find the variation by type
          final variation = _product!.getVariationByType(variationType);
          if (variation != null) {
            // Find the option for this flavor
            try {
              final option = variation.options.firstWhere(
                (o) => o.value == flavorId,
              );
              if (option.priceAdjustment > 0) {
                print(
                    'Adding price for Cake ${flavor['cakeNumber']} ${variation.type}: ${option.priceAdjustment}');
                totalPrice += option.priceAdjustment;
              }
            } catch (e) {
              print('Option not found for $flavorId: $e');
            }
          }
        }
      }

      print('Total price for set: $totalPrice');
      return totalPrice;
    }

    // For regular products, calculate price based on selected size and flavor
    return _product!.getPriceForVariations(_selectedSize, _selectedFlavour);
  }

  void _updateCartPrice() {
    if (_product == null) return;

    setState(() {
      _currentPrice = _calculatePrice();
    });

    print('Updated price: $_currentPrice');
  }

  void _onCakeFlavorSelected(
      {required int cakeNumber, required String flavorId}) {
    // Get the current variation type
    String variationType = 'FLAVOUR';
    if (_product != null && _product!.variations.isNotEmpty) {
      ProductVariation? flavorVariation =
          _product!.getVariationByType('FLAVOUR');
      if (flavorVariation == null && _product!.variations.isNotEmpty) {
        flavorVariation = _product!.variations.first;
      }
      if (flavorVariation != null) {
        variationType = flavorVariation.type;
      }
    }

    final updatedFlavors = [..._cakeFlavors];
    final existingIndex =
        updatedFlavors.indexWhere((f) => f['cakeNumber'] == cakeNumber);

    if (existingIndex >= 0) {
      // Update existing flavor
      updatedFlavors[existingIndex]['flavorId'] = flavorId;
      updatedFlavors[existingIndex]['variationType'] = variationType;
    } else {
      // Add new flavor
      updatedFlavors.add({
        'cakeNumber': cakeNumber,
        'flavorId': flavorId,
        'variationType': variationType,
      });
    }

    // Check if all flavors are selected
    bool allSelected = true;
    for (var flavor in updatedFlavors) {
      if (flavor['flavorId'] == null || flavor['flavorId'].isEmpty) {
        allSelected = false;
        break;
      }
    }

    setState(() {
      _cakeFlavors = updatedFlavors;
      _allCakeFlavorsSelected = allSelected;
      _updateCartPrice();
    });
  }

  // Get the selected flavor for a specific cake
  String _getSelectedCakeFlavor(int cakeNumber) {
    final flavor = _cakeFlavors.firstWhere((f) => f['cakeNumber'] == cakeNumber,
        orElse: () => {'cakeNumber': cakeNumber, 'flavorId': ''});
    return flavor['flavorId'];
  }

  Widget _buildSizeOption(String size) {
    final isSelected = _selectedSize == size;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSize = size;
            _currentPrice = _calculatePrice();
            print('Size selected: $size');
            print('New price: $_currentPrice');
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            size,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlavourOption(String flavour) {
    final isSelected = _selectedFlavour == flavour;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFlavour = flavour;
            _currentPrice = _calculatePrice();
            print('Flavour selected: $flavour');
            print('New price: $_currentPrice');
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            flavour,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDescriptionWidgets() {
    if (_product?.description == null) return [];

    final document = htmlparser.parse(_product!.description);
    final List<Widget> widgets = [];
    var currentH3Section = '';
    var currentContent = StringBuffer();
    bool insideH3Section = false;

    for (var node in document.body!.nodes) {
      if (node is dom.Element) {
        if (node.localName == 'h3') {
          // If we were inside an h3 section, add it to widgets
          if (insideH3Section && currentH3Section.isNotEmpty) {
            widgets.add(_buildAccordionSection(
              currentH3Section,
              currentContent.toString(),
            ));
            currentContent.clear();
          }
          currentH3Section = node.text;
          insideH3Section = true;
        } else if (insideH3Section) {
          currentContent.writeln(node.outerHtml);
        } else {
          // Regular content outside h3 sections
          widgets.add(Html(
            data: node.outerHtml,
            style: {
              "body": Style(
                fontSize: FontSize(14),
                color: Colors.black87,
              ),
              "p": Style(
                margin: Margins(
                  top: Margin(8),
                  bottom: Margin(8),
                ),
              ),
              "li": Style(
                margin: Margins(
                  bottom: Margin(8),
                ),
              ),
            },
          ));
        }
      }
    }

    // Add the last h3 section if exists
    if (insideH3Section && currentH3Section.isNotEmpty) {
      widgets.add(_buildAccordionSection(
        currentH3Section,
        currentContent.toString(),
      ));
    }

    return widgets;
  }

  Widget _buildAccordionSection(String title, String content) {
    bool isExpanded = false;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Html(
              data: content,
              style: {
                "body": Style(
                  fontSize: FontSize(14),
                  color: Colors.black87,
                ),
                "p": Style(
                  margin: Margins(
                    top: Margin(8),
                    bottom: Margin(8),
                  ),
                ),
                "li": Style(
                  margin: Margins(
                    bottom: Margin(8),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantOptions() {
    if (_product == null) {
      return const SizedBox.shrink();
    }

    List<Widget> variantWidgets = [];

    // For Sets category, show cake flavor selection
    if (_isSetCategory) {
      // Get all variations from the product
      List<ProductVariation> availableVariations = _product!.variations;

      // If no variations are available, don't show the UI
      if (availableVariations.isEmpty) {
        return const SizedBox.shrink();
      }

      // Try to get flavor variation first
      ProductVariation? selectedVariation =
          _product!.getVariationByType('FLAVOUR');

      // If no flavor variation, use the first available variation
      if (selectedVariation == null) {
        selectedVariation = availableVariations.first;
      }

      List<ProductOption> variationOptions = selectedVariation.options;
      String variationType = selectedVariation.type;

      variantWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select ${variationType.capitalize()} for Each Cake',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [1, 2, 3, 4].map((cakeNumber) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cake $cakeNumber ${variationType.capitalize()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _getSelectedCakeFlavor(cakeNumber),
                            isExpanded: true,
                            hint:
                                Text('Select a ${variationType.toLowerCase()}'),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            items: variationOptions.map((option) {
                              return DropdownMenuItem<String>(
                                value: option.value,
                                child: Text(option.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              _onCakeFlavorSelected(
                                cakeNumber: cakeNumber,
                                flavorId: value,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (!_allCakeFlavorsSelected)
              const Text(
                'Please select a flavor for each cake',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );

      // Show selected flavors summary
      if (_allCakeFlavorsSelected) {
        variantWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Flavors',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ..._cakeFlavors.map((flavor) {
                      final String flavorId = flavor['flavorId'];
                      // Find the flavor option that matches the selected flavorId
                      final flavorOption = variationOptions.firstWhere(
                        (option) => option.value == flavorId,
                        orElse: () => ProductOption(
                            id: '',
                            value: 'Not selected',
                            priceAdjustment: 0,
                            stock: 0),
                      );

                      final flavorName = flavorOption.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cake ${flavor['cakeNumber']}: $flavorName',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(),
                    // Only show base price if not in Sets category
                    if (!_isSetCategory)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Base Price:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_product!.basePrice.toStringAsFixed(0)} AED',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }

      // Return early for Sets category
      if (variantWidgets.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: variantWidgets,
          ),
        );
      }
    }

    // Add size options if available
    if (_product!.sizes.isNotEmpty) {
      variantWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Size',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _product!.sizes
                    .map((size) => _buildSizeOption(size))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Add flavour options if available
    if (_product!.flavours.isNotEmpty) {
      variantWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flavour',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _product!.flavours
                    .map((flavour) => _buildFlavourOption(flavour))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Check if we have any variant options to display
    if (variantWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    // Return the full widget with all variant options
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: variantWidgets,
      ),
    );
  }

  Widget _buildImageGallery() {
    if (_product == null || _product!.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Image Slider
        SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.45,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: _product!.images.length,
            itemBuilder: (context, index) {
              final image = _product!.images[index];
              return Image.network(
                image.url,
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.45,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading image ${index + 1}/${_product!.images.length}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              color: Colors.black,
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
        // Image Indicators
        if (_product!.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _product!.images.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withAlpha(128),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addToCart() async {
    if (_product == null) return;

    // Get the cart service
    final cartService = Provider.of<CartService>(context, listen: false);

    // Create a map of selected options
    Map<String, dynamic> selectedOptions = {};

    // For Sets category, add cake flavors to selected options
    if (_isSetCategory) {
      List<Map<String, dynamic>> cakeFlavorsData = [];
      String variationType = '';

      for (var flavor in _cakeFlavors) {
        // Ensure the flavor has a valid ID
        if (flavor['flavorId'] != null && flavor['flavorId'].isNotEmpty) {
          variationType = flavor['variationType'] ?? 'FLAVOUR';
          cakeFlavorsData.add({
            'cakeNumber': flavor['cakeNumber'],
            'flavor': flavor['flavorId'],
            'variationType': variationType,
          });
        } else {
          // If any flavor is missing, show an error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Please select a ${variationType.toLowerCase()} for each cake'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      // Add cake flavors to selected options
      selectedOptions['cakeFlavors'] = cakeFlavorsData;
      selectedOptions['variationType'] = variationType;
    } else {
      // For regular products, add size and flavor
      if (_selectedSize != null && _selectedSize!.isNotEmpty) {
        selectedOptions['size'] = _selectedSize;
      }

      if (_selectedFlavour != null && _selectedFlavour!.isNotEmpty) {
        selectedOptions['flavour'] = _selectedFlavour;
      }
    }

    // Add custom text if provided
    if (_cakeTextController.text.isNotEmpty) {
      selectedOptions['cakeText'] = _cakeTextController.text;
    }

    try {
      // Add the product to the cart
      await cartService.addToCart(
        productId: _product!.id,
        quantity: 1,
        price: _currentPrice,
        selectedOptions: selectedOptions,
      );

      // Show success message
      _showAddedToCartMessage();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddedToCartMessage() {
    ModernNotification.show(
      context: context,
      message: 'Added to cart',
      actionLabel: 'VIEW CART',
      onActionPressed: _navigateToCart,
    );
  }

  void _navigateToCart() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {'initialTab': 2}, // Cart tab index
    );
  }

  Future<void> _prefetchImages() async {
    if (_product == null || !mounted) return;

    for (var image in _product!.images) {
      await precacheImage(NetworkImage(image.url), context);
    }
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
                          _buildImageGallery(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
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
                                    ..._buildDescriptionWidgets(),
                                    if (_product!.category.name.toLowerCase() ==
                                        'flowers') ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Colors.grey[200]!),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Important Note:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'If a flower illustrated is unavailable (for any reason), we will substitute this for a flower of the same or higher monetary value and in a similar style and colour. Kindly keep in mind that with natural products there may be slight variances in colours.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.5,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                  ],
                                  _buildVariantOptions(),
                                  if (_product!.category.name.toLowerCase() ==
                                          'cakes' ||
                                      _product!.category.name.toLowerCase() ==
                                          'cake') ...[
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
                                          hintText:
                                              'Enter text to be written on cake',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
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
                                  const SizedBox(height: 24),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_currentPrice.toStringAsFixed(0)} AED',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _navigateToCart,
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
