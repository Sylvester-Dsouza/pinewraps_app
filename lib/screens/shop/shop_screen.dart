import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/product_card.dart';
import '../product/product_details_screen.dart';

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
  bool _isLoading = true;
  String? _error;
  bool _mounted = false;
  bool _isSearchVisible = false;
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isSearching = false;

  // Pagination variables
  int _currentPage = 1;
  final int _pageLimit = 10;
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;

  // Categories list - will be dynamically populated
  List<ProductCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _isSearchVisible = false;
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    // Set initial category if provided
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }

    // Load categories first, then products
    _loadCategories().then((_) => _loadProducts());
  }

  // Load categories from the API
  Future<void> _loadCategories() async {
    try {
      final categories = await _productService.getCategories();

      if (!_mounted) return;

      setState(() {
        _categories = categories;
        // Print categories to debug
        print('Loaded ${_categories.length} categories:');
        for (var category in _categories) {
          print('  - Category: ${category.name} (ID: ${category.id})');
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      _searchQuery = _searchController.text;
      // Don't trigger search on every keystroke
      if (!_isSearching) {
        _isSearching = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_mounted) {
            _loadProducts();
            _isSearching = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (!_mounted) return;
    try {
      setState(() {
        if (!loadMore) {
          _isLoading = true;
          _error = null;
          _currentPage = 1;
        } else {
          _isLoadingMore = true;
        }
      });

      // Use the search query if it exists
      if (_searchQuery.isNotEmpty) {
        final searchResults = await _productService.searchProducts(_searchQuery);
        if (!_mounted) return;
        setState(() {
          _products = searchResults;
          _isLoading = false;
          _isLoadingMore = false;
          _hasMoreProducts = false; // Search doesn't support pagination yet
        });
        return;
      }

      // Use category filtering if selected
      if (_selectedCategory != null) {
        // Find the category ID by name first
        print('Looking for category: $_selectedCategory');

        final matchingCategory = _categories.firstWhere(
          (cat) => cat.name.toLowerCase() == _selectedCategory?.toLowerCase(),
          orElse: () => ProductCategory(id: '', name: ''),
        );

        if (matchingCategory.id.isNotEmpty) {
          print('Found matching category ID: ${matchingCategory.id} for name: ${matchingCategory.name}');
          final filteredProducts = await _productService.getProductsByCategory(
            matchingCategory.id,
            page: _currentPage,
            limit: _pageLimit,
          );

          if (!_mounted) return;

          setState(() {
            if (loadMore) {
              _products.addAll(filteredProducts);
            } else {
              _products = filteredProducts;
            }
            _isLoading = false;
            _isLoadingMore = false;
            _hasMoreProducts = filteredProducts.length >= _pageLimit;
          });
          return;
        } else {
          print('No matching category found for: $_selectedCategory');
          print('Available categories:');
          for (var cat in _categories) {
            print('  - ${cat.name} (${cat.id})');
          }
        }
      }

      // Fallback to getting all products
      final products = await _productService.getAllProducts(
        page: _currentPage,
        limit: _pageLimit,
      );

      if (!_mounted) return;

      setState(() {
        if (loadMore) {
          _products.addAll(products);
        } else {
          _products = products;
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMoreProducts = products.length >= _pageLimit;
      });
    } catch (e) {
      print('Error loading products: $e');
      if (!_mounted) return;
      setState(() {
        _error = 'Failed to load products';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;

    _currentPage++;
    await _loadProducts(loadMore: true);
  }

  Future<void> _refreshData() async {
    await _loadProducts();
  }

  void _navigateToProductDetails(String productId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(productId: productId),
      ),
    ).then((_) {
      // Refresh products when returning
      if (mounted) {
        _loadProducts();
      }
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadProducts();
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
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          _selectCategory(null);
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.black,
                        checkmarkColor: Colors.white, // Make the tick icon white
                        labelStyle: TextStyle(
                          color: _selectedCategory == null ? Colors.white : Colors.black,
                          fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    ..._categories.map((category) {
                      final isSelected = _selectedCategory?.toLowerCase() == category.name.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            _selectCategory(selected ? category.name : null);
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.black,
                          checkmarkColor: Colors.white, // Make the tick icon white
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
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
          else if (_products.isEmpty)
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
                    if (_searchController.text.isNotEmpty || _selectedCategory != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _selectCategory(null);
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ProductCard(
                        product: _products[index],
                        width: double.infinity,
                        onTap: () {
                          // Debug: Print product category information
                          print('Product: ${_products[index].name}');
                          print('Category ID: ${_products[index].categoryId}');
                          print('Category Name: ${_products[index].category.name}');
                          _navigateToProductDetails(_products[index].id);
                        },
                      ),
                    );
                  },
                  childCount: _products.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  // Calculate mainAxisExtent to ensure 1:1 image ratio plus space for text
                  mainAxisExtent: MediaQuery.of(context).size.width > 600 
                    ? (MediaQuery.of(context).size.width / 3) + 80 // For tablets: image + text
                    : (MediaQuery.of(context).size.width / 2) + 80, // For phones: image + text
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
              ),
            ),
          // Load more button
          if (!_isLoading && _products.isNotEmpty && _hasMoreProducts)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        )
                      : ElevatedButton(
                          onPressed: _loadMoreProducts,
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
                          child: const Text('Load More'),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
