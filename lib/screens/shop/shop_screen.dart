import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/product_card.dart';

class ShopScreen extends StatefulWidget {
  final String? initialCategory;

  const ShopScreen({
    Key? key,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ProductService _productService = ProductService();
  late TextEditingController _searchController;
  List<Product> _products = [];
  Set<ProductCategory> _categories = {};
  bool _isLoading = true;
  String? _error;
  bool _mounted = false;
  bool _isSearchVisible = false;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _isSearchVisible = false;
    _searchController = TextEditingController();
    _loadData();
    
    // Set initial category if provided
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final category = _categories.firstWhere(
          (c) => c.name.toLowerCase() == widget.initialCategory?.toLowerCase(),
          orElse: () => _categories.first,
        );
        if (_mounted) {
          setState(() {
            _selectedCategoryId = category.id;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!_mounted) return;
    try {
      final products = await _productService.getAllProducts();
      if (!_mounted) return;

      // Extract unique categories
      final uniqueCategories = <ProductCategory>{};
      for (var product in products) {
        uniqueCategories.add(product.category);
      }

      setState(() {
        _categories = uniqueCategories;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (!_mounted) return;
      setState(() {
        _error = 'Failed to load categories';
      });
    }
  }

  Future<void> _loadProducts() async {
    if (!_mounted) return;
    try {
      final products = await _productService.getAllProducts();
      if (!_mounted) return;

      setState(() {
        _products = products;
      });
    } catch (e) {
      print('Error loading products: $e');
      if (!_mounted) return;
      setState(() {
        _error = 'Failed to load products';
      });
    }
  }

  Future<void> _loadData() async {
    if (!_mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _loadCategories();
      await _loadProducts();

      if (!_mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!_mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchController.text.isEmpty ||
          product.name.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesCategory = _selectedCategoryId == null ||
          product.category.id == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isSearchVisible
                  ? TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      style: const TextStyle(color: Colors.black),
                      onChanged: (value) => setState(() {}),
                    )
                  : const Text('Shop'),
            ),
            actions: [
              IconButton(
                icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearchVisible = !_isSearchVisible;
                    if (!_isSearchVisible) {
                      _searchController.clear();
                    }
                  });
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategoryId == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryId = null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          color: _selectedCategoryId == null ? Colors.white : Colors.black,
                          fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    ..._categories.map((category) {
                      final isSelected = category.id == _selectedCategoryId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId = selected ? category.id : null;
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.black,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_filteredProducts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty || _selectedCategoryId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedCategoryId = null;
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ProductCard(product: _filteredProducts[index]);
                  },
                  childCount: _filteredProducts.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
