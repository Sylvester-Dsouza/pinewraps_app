import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../models/product_addon.dart';
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
  // State for product addons
  List<ProductAddon> _productAddons = [];
  List<SelectedAddonOption> _selectedAddons = [];
  Map<String, String> _addonCustomTexts =
      {}; // Maps addonId_optionId_selectionIndex to custom text

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

      // Prefetch images to improve loading performance
      _prefetchImages();

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

      // Set initial product state
      setState(() {
        _product = product;
        _selectedSize = initialSize;
        _selectedFlavour = initialFlavour;
        _currentPrice = initialPrice;
        _isLoading = false;
      });

      // Load product addons after setting initial product state
      try {
        final addons = await _productService.fetchProductAddons(product.id);

        if (addons.isNotEmpty) {
          print('Loaded ${addons.length} product addons');

          // Initialize selected addons with required addons' default options
          List<SelectedAddonOption> initialSelectedAddons = [];

          for (var addon in addons) {
            // Select the first option for all dropdowns by default if options exist
            if (addon.options.isNotEmpty) {
              // Determine how many dropdowns to show and initialize
              int dropdownCount = addon.maxSelections;

              // If addon is required, ensure we show at least the minimum required dropdowns
              if (addon.required && addon.minSelections > dropdownCount) {
                dropdownCount = addon.minSelections;
              }

              // Initialize each dropdown with the first option
              for (int i = 0; i < dropdownCount; i++) {
                // Use modulo to cycle through available options if there are fewer options than dropdowns
                int optionIndex = i % addon.options.length;

                initialSelectedAddons.add(SelectedAddonOption(
                  addonId: addon.id,
                  optionId: addon.options[optionIndex].id,
                  selectionIndex: i,
                ));
              }
            }
          }

          setState(() {
            _productAddons = addons;
            _selectedAddons = initialSelectedAddons;
          });

          // Recalculate price with addons
          _updateCartPrice();
        }
      } catch (e) {
        print('Error loading product addons: $e');
        // Continue without addons if there's an error
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

    // Calculate base price from product variations (size, flavor, etc.)
    double totalPrice =
        _product!.getPriceForVariations(_selectedSize, _selectedFlavour);
    print('Base price for product: $totalPrice');

    // Add price adjustments for selected addons
    if (_selectedAddons.isNotEmpty) {
      double addonPrice = 0;

      for (var selectedAddon in _selectedAddons) {
        // Find the addon group
        final addonGroup = _productAddons.firstWhere(
          (addon) => addon.id == selectedAddon.addonId,
          orElse: () => ProductAddon(
            id: '',
            name: '',
            description: '',
            required: false,
            minSelections: 0,
            maxSelections: 0,
            options: [],
          ),
        );

        if (addonGroup.id.isNotEmpty) {
          // Find the selected option
          final option = addonGroup.options.firstWhere(
            (opt) => opt.id == selectedAddon.optionId,
            orElse: () => AddonOption(id: '', name: '', price: 0),
          );

          if (option.id.isNotEmpty && option.price > 0) {
            print(
                'Adding price for ${addonGroup.name}: ${option.name} - ${option.price}');
            addonPrice += option.price;
          }
        }
      }

      totalPrice += addonPrice;
      print('Total price with addons: $totalPrice');
    }

    return totalPrice;
  }

  void _updateCartPrice() {
    if (_product == null) return;

    setState(() {
      _currentPrice = _calculatePrice();
    });

    print('Updated price: $_currentPrice');
  }

  // Cake flavor functionality removed

  // Handle addon option selection for toggle-style selection
  void _handleAddonOptionSelect(String addonId, String optionId) {
    // Find the addon group to get its configuration
    final addonGroup = _productAddons.firstWhere(
      (addon) => addon.id == addonId,
      orElse: () => ProductAddon(
        id: '',
        name: '',
        description: '',
        required: false,
        minSelections: 0,
        maxSelections: 0,
        options: [],
      ),
    );

    if (addonGroup.id.isEmpty) return;

    setState(() {
      // Find existing selections for this addon group
      final existingSelections =
          _selectedAddons.where((item) => item.addonId == addonId).toList();

      // If this option is already selected, remove it (toggle behavior)
      final existingSelection = existingSelections.firstWhere(
        (item) => item.optionId == optionId,
        orElse: () => SelectedAddonOption(addonId: '', optionId: ''),
      );

      if (existingSelection.addonId.isNotEmpty) {
        // Don't allow deselection if it would violate minimum selections for required addons
        if (addonGroup.required &&
            existingSelections.length <= addonGroup.minSelections) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You must select at least ${addonGroup.minSelections} option(s) for ${addonGroup.name}'),
            duration: const Duration(seconds: 2),
          ));
          return;
        }

        // Remove the option
        _selectedAddons.removeWhere(
            (item) => item.addonId == addonId && item.optionId == optionId);
      } else {
        // Check if adding would exceed max selections
        if (existingSelections.length >= addonGroup.maxSelections) {
          // If we're at max selections, replace the oldest selection
          if (existingSelections.isNotEmpty) {
            final oldestSelection = existingSelections.first;
            _selectedAddons.removeWhere((item) =>
                item.addonId == addonId &&
                item.optionId == oldestSelection.optionId);
          }
        }

        // Add the new selection with a unique selection index
        _selectedAddons.add(SelectedAddonOption(
          addonId: addonId,
          optionId: optionId,
          selectionIndex: existingSelections.length,
        ));
      }
    });

    // Update price
    _updateCartPrice();
  }

  // Handle dropdown selection for addons
  void _handleAddonDropdownSelect(
      String addonId, int dropdownIndex, String optionId) {
    // Find the addon group to get its configuration
    final addonGroup = _productAddons.firstWhere(
      (addon) => addon.id == addonId,
      orElse: () => ProductAddon(
        id: '',
        name: '',
        description: '',
        required: false,
        minSelections: 0,
        maxSelections: 0,
        options: [],
      ),
    );

    if (addonGroup.id.isEmpty) return;

    setState(() {
      // Find existing selections for this addon group
      final existingSelections =
          _selectedAddons.where((item) => item.addonId == addonId).toList();

      // Find the existing selection at this dropdown index, if any
      final existingSelection = existingSelections.firstWhere(
        (item) => item.selectionIndex == dropdownIndex,
        orElse: () => SelectedAddonOption(addonId: '', optionId: ''),
      );

      String? existingCustomText;

      // If there's an existing selection at this index, preserve its custom text if the option is the same
      if (existingSelection.addonId.isNotEmpty &&
          existingSelection.optionId == optionId) {
        existingCustomText = existingSelection.customText;
      }

      // Remove any existing selection for this dropdown index
      _selectedAddons.removeWhere((item) =>
          item.addonId == addonId && item.selectionIndex == dropdownIndex);

      // Add the new selection if an option was selected (not empty)
      if (optionId.isNotEmpty) {
        _selectedAddons.add(SelectedAddonOption(
          addonId: addonId,
          optionId: optionId,
          selectionIndex: dropdownIndex,
          customText: existingCustomText,
        ));
      }
    });

    // Update price
    _updateCartPrice();
  }

  // Handle custom text input for addon options
  void _handleAddonCustomTextChange(
      String addonId, String optionId, String text, int selectionIndex) {
    // Update the custom text for this specific addon option selection
    setState(() {
      _addonCustomTexts['${addonId}_${optionId}_${selectionIndex}'] = text;

      // Also update the selectedAddons array with the custom text
      for (int i = 0; i < _selectedAddons.length; i++) {
        final item = _selectedAddons[i];
        if (item.addonId == addonId &&
            item.optionId == optionId &&
            (item.selectionIndex == selectionIndex)) {
          _selectedAddons[i] = SelectedAddonOption(
            addonId: item.addonId,
            optionId: item.optionId,
            customText: text,
            selectionIndex: item.selectionIndex,
          );
          break;
        }
      }
    });

    // Update price after changing custom text
    _updateCartPrice();
  }
  
  // Helper method to create a controller with cursor at the end
  TextEditingController _createControllerWithEndCursor(String text) {
    final controller = TextEditingController(text: text);
    // Set the selection to the end of the text
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    return controller;
  }

  // Custom TextField widget that properly handles text direction
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required Function(String) onChanged,
    required String hintText,
    int? maxLength,
    InputDecoration? decoration,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        keyboardType: TextInputType.text,
        decoration: decoration ?? InputDecoration(
          hintText: hintText,
          hintTextDirection: TextDirection.ltr,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        maxLength: maxLength ?? 50,
        onChanged: (text) {
          // Maintain cursor position at the end when text changes
          final cursorPos = controller.selection.base.offset;
          onChanged(text);
          // Only fix cursor if it jumped to the beginning
          if (cursorPos > 0 && controller.selection.base.offset == 0) {
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
          }
        },
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          locale: Locale('en', 'US'), // Force English locale
        ),
        textInputAction: TextInputAction.done,
        strutStyle: const StrutStyle(forceStrutHeight: true), // Helps with text rendering
      ),
    );
  }

  // Get custom text for a specific addon option selection
  String _getAddonCustomText(
      String addonId, String optionId, int selectionIndex) {
    return _addonCustomTexts['${addonId}_${optionId}_${selectionIndex}'] ?? '';
  }

  // Check if an addon option is selected
  bool _isAddonOptionSelected(String addonId, String optionId) {
    return _selectedAddons
        .any((item) => item.addonId == addonId && item.optionId == optionId);
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

    // Add product addons if available
    if (_productAddons.isNotEmpty) {
      for (var addon in _productAddons) {
        // Skip empty addon groups
        if (addon.options.isEmpty) continue;

        // Create UI based on addon configuration
        if (addon.maxSelections == 1) {
          // Single selection addon - use toggle buttons
          variantWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addon.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (addon.required)
                      const Text(
                        ' *',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                if (addon.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      addon.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: addon.options.map((option) {
                    final isSelected =
                        _isAddonOptionSelected(addon.id, option.id);
                    return InkWell(
                      onTap: () {
                        _handleAddonOptionSelect(addon.id, option.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.name,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (option.price > 0)
                              Text(
                                ' +${option.price.toStringAsFixed(2)} AED',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Custom text input for selected option that allows it
                ..._buildCustomTextInputs(addon, 0),

                const SizedBox(height: 24),
              ],
            ),
          );
        } else {
          // Multi-selection addon - use dropdowns
          variantWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addon.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (addon.required)
                      const Text(
                        ' *',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                if (addon.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      addon.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                Text(
                  'Select ${addon.minSelections > 0 ? 'at least ${addon.minSelections}' : 'up to ${addon.maxSelections}'} option${addon.maxSelections > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),

                // Generate dropdowns based on min/max selections
                ..._buildDropdownSelections(addon),

                const SizedBox(height: 24),
              ],
            ),
          );
        }
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

  // Helper method to build custom text inputs for selected addon options
  List<Widget> _buildCustomTextInputs(ProductAddon addon, int selectionIndex) {
    List<Widget> textInputs = [];

    // Find selected options for this addon
    final selectedOptions = _selectedAddons
        .where((item) =>
            item.addonId == addon.id && item.selectionIndex == selectionIndex)
        .toList();

    for (var selection in selectedOptions) {
      // Find the option details
      final option = addon.options.firstWhere(
        (opt) => opt.id == selection.optionId,
        orElse: () => AddonOption(id: '', name: '', price: 0),
      );

      // If this option allows custom text, show the input
      if (option.allowsCustomText) {
        textInputs.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.customTextLabel ??
                      'Add custom text for ${option.name}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildCustomTextField(
                  controller: _createControllerWithEndCursor(
                    _getAddonCustomText(addon.id, option.id, selectionIndex),
                  ),
                  hintText: 'Enter custom text',
                  maxLength: option.maxTextLength ?? 50,
                  onChanged: (text) {
                    _handleAddonCustomTextChange(
                        addon.id, option.id, text, selectionIndex);
                  },
                ),
              ],
            ),
          ),
        );
      }
    }

    return textInputs;
  }

  // Helper method to build dropdown selections for multi-selection addons
  List<Widget> _buildDropdownSelections(ProductAddon addon) {
    List<Widget> dropdowns = [];

    // Always use maxSelections to determine how many dropdowns to show
    int dropdownCount = addon.maxSelections;

    // If addon is required, ensure we show at least the minimum required dropdowns
    if (addon.required && addon.minSelections > dropdownCount) {
      dropdownCount = addon.minSelections;
    }

    // Generate dropdowns
    for (int i = 0; i < dropdownCount; i++) {
      // Find current selection for this dropdown index
      final currentSelection = _selectedAddons
          .where((item) => item.addonId == addon.id && item.selectionIndex == i)
          .map((item) => item.optionId)
          .firstOrNull;

      dropdowns.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Option ${i + 1}${i < addon.minSelections ? ' *' : ''}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentSelection,
                    isExpanded: true,
                    hint: Text(
                      'Select an option',
                      style: const TextStyle(fontSize: 14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: [
                      // Add an empty option for clearing the selection
                      if (!addon.required || i >= addon.minSelections)
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text(
                            'None',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      // Add all addon options
                      ...addon.options.map((option) {
                        return DropdownMenuItem<String>(
                          value: option.id,
                          child: Text(
                            option.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _handleAddonDropdownSelect(addon.id, i, value);
                    },
                  ),
                ),
              ),

              // Custom text input widget (conditionally rendered)
              if (currentSelection != null && currentSelection.isNotEmpty)
                Builder(builder: (context) {
                  // Find the option details
                  final option = addon.options.firstWhere(
                    (opt) => opt.id == currentSelection,
                    orElse: () => AddonOption(id: '', name: '', price: 0),
                  );

                  // Only show text input if option allows custom text
                  if (option.allowsCustomText) {
                    final currentText = _getAddonCustomText(addon.id, currentSelection, i);
                    final controller = _createControllerWithEndCursor(currentText);
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildCustomTextField(
                        controller: controller,
                        hintText: option.customTextLabel ?? 'Add custom writing',
                        maxLength: option.maxTextLength ?? 50,
                        onChanged: (text) {
                          _handleAddonCustomTextChange(
                              addon.id, currentSelection, text, i);
                        },
                      ),
                    );
                  } else {
                    return const SizedBox
                        .shrink(); // Empty widget if no custom text needed
                  }
                })
            ],
          ),
        ),
      );
    }

    return dropdowns;
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
              return CachedNetworkImage(
                imageUrl: image.url,
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.45,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                memCacheWidth: 800, // Optimize memory cache size
                maxWidthDiskCache: 1200, // Optimize disk cache size
                errorWidget: (context, url, error) {
                  print('Error loading image: $error');
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  );
                },
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 10),
                        const Text('Loading image...'),
                      ],
                    ),
                  ),
                ),
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

    // For all products, add size and flavor
    if (_selectedSize != null && _selectedSize!.isNotEmpty) {
      selectedOptions['size'] = _selectedSize;
    }

    if (_selectedFlavour != null && _selectedFlavour!.isNotEmpty) {
      selectedOptions['flavour'] = _selectedFlavour;
    }

    // Add custom text if provided (only for non-Sets category)
    if (!_isSetCategory && _cakeTextController.text.isNotEmpty) {
      selectedOptions['cakeText'] = _cakeTextController.text;
    }
    
    // Add selected addons and their custom text
    if (_selectedAddons.isNotEmpty) {
      List<Map<String, dynamic>> addonsData = [];
      
      for (var selectedAddon in _selectedAddons) {
        // Find the addon group
        final addonGroup = _productAddons.firstWhere(
          (addon) => addon.id == selectedAddon.addonId,
          orElse: () => ProductAddon(
            id: '',
            name: '',
            description: '',
            required: false,
            minSelections: 0,
            maxSelections: 0,
            options: [],
          ),
        );
        
        if (addonGroup.id.isEmpty) continue;
        
        // Find the selected option
        final option = addonGroup.options.firstWhere(
          (opt) => opt.id == selectedAddon.optionId,
          orElse: () => AddonOption(id: '', name: '', price: 0),
        );
        
        if (option.id.isEmpty) continue;
        
        // Add addon data including custom text if available
        Map<String, dynamic> addonData = {
          'addonId': selectedAddon.addonId,
          'addonName': addonGroup.name,
          'optionId': selectedAddon.optionId,
          'optionName': option.name,
          'price': option.price,
          'selectionIndex': selectedAddon.selectionIndex,
        };
        
        // Add custom text if available
        if (selectedAddon.customText != null && selectedAddon.customText!.isNotEmpty) {
          addonData['customText'] = selectedAddon.customText;
        }
        
        addonsData.add(addonData);
      }
      
      // Add addons data to selected options
      if (addonsData.isNotEmpty) {
        selectedOptions['addons'] = addonsData;
      }
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
      await precacheImage(CachedNetworkImageProvider(image.url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                                  if ((_product!.category.name.toLowerCase() ==
                                              'cakes' ||
                                          _product!.category.name
                                                  .toLowerCase() ==
                                              'cake') &&
                                      !_isSetCategory) ...[
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
                                      child: _buildCustomTextField(
                                        controller: _cakeTextController,
                                        hintText: 'Enter text to be written on cake',
                                        maxLength: 100,
                                        decoration: InputDecoration(
                                          hintText: 'Enter text to be written on cake',
                                          hintTextDirection: TextDirection.ltr,
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
                                        onChanged: (text) {
                                          setState(() {});
                                        },
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
                // Add padding to ensure button stays above keyboard
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
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
