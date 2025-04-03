class ProductOption {
  final String id;
  final String value;
  final double priceAdjustment;
  final int stock;

  ProductOption({
    required this.id,
    required this.value,
    required this.priceAdjustment,
    required this.stock,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as String,
      value: json['value'] as String,
      priceAdjustment: (json['priceAdjustment'] as num).toDouble(),
      stock: json['stock'] as int,
    );
  }
}

class ProductVariation {
  final String id;
  final String type;
  final List<ProductOption> options;

  ProductVariation({
    required this.id,
    required this.type,
    required this.options,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id'] as String,
      type: json['type'] as String,
      options: (json['options'] as List)
          .map((o) => ProductOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductImage {
  final String id;
  final String url;
  final String alt;
  final bool isPrimary;

  ProductImage({
    required this.id,
    required this.url,
    required this.alt,
    required this.isPrimary,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    try {
      return ProductImage(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        alt: json['alt'] as String? ?? '',
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      print('Error parsing product image: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({
    required this.id,
    required this.name,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    try {
      return ProductCategory(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
    } catch (e, stackTrace) {
      print('Error parsing product category: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String sku;
  final String status;
  final double basePrice;
  final String categoryId;
  final List<ProductVariation> variations;
  final List<ProductImage> images;
  final ProductCategory category;
  final List<Map<String, dynamic>> variantCombinations;
  final bool allowCustomText;
  final List<String> sizes;
  final List<String> flavours;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.sku,
    required this.status,
    required this.basePrice,
    required this.categoryId,
    required this.variations,
    required this.images,
    required this.category,
    required this.variantCombinations,
    required this.sizes,
    required this.flavours,
    this.allowCustomText = false,
  });

  String? get imageUrl => images.isNotEmpty ? images[0].url : null;

  List<String> get sizesList {
    final sizeVariation = getVariationByType('SIZE');
    return sizeVariation?.options.map((o) => o.value).toList() ?? [];
  }

  List<String> get flavoursList {
    final flavourVariation = getVariationByType('FLAVOUR');
    return flavourVariation?.options.map((o) => o.value).toList() ?? [];
  }

  ProductVariation? getVariationByType(String type) {
    try {
      // Handle both FLAVOUR and FLAVOR spellings
      if (type.toUpperCase() == 'FLAVOUR' || type.toUpperCase() == 'FLAVOR') {
        return variations.firstWhere(
          (v) =>
              v.type.toUpperCase() == 'FLAVOUR' ||
              v.type.toUpperCase() == 'FLAVOR',
        );
      }

      return variations.firstWhere(
        (v) => v.type.toUpperCase() == type.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to check if product is in Sets category
  bool get isSetCategory {
    return categoryId.toLowerCase() == 'sets' ||
        category.name.toLowerCase() == 'sets' ||
        name.toLowerCase().contains('set of') ||
        description.toLowerCase().contains('set of 4');
  }

  // Get formatted price string
  String getFormattedPrice() {
    // For Sets category, return static text
    if (isSetCategory) {
      return 'Starting From 332 Onwards';
    }

    // For single variant products, show the option prices directly
    if (variations.length == 1) {
      final options = variations[0].options;
      if (options.isNotEmpty) {
        // Get all prices directly from options
        final prices = options.map((opt) => opt.priceAdjustment).toList()
          ..sort();
        if (prices.length == 1) {
          return '${prices[0].toStringAsFixed(0)} AED';
        }
        return '${prices.first.toStringAsFixed(0)} - ${prices.last.toStringAsFixed(0)} AED';
      }
    }

    // For multi-variant products, check combinations
    if (variantCombinations.isNotEmpty) {
      final prices = variantCombinations
          .map((combo) => combo['price'])
          .where((price) => price != null)
          .map((price) => price is int ? price.toDouble() : (price as double))
          .toList()
        ..sort();

      if (prices.isNotEmpty) {
        if (prices.length == 1) {
          return '${prices[0].toStringAsFixed(0)} AED';
        }
        return '${prices.first.toStringAsFixed(0)} - ${prices.last.toStringAsFixed(0)} AED';
      }
    }

    // Only use base price if no variations exist
    return '${basePrice.toStringAsFixed(0)} AED';
  }

  double getPriceForVariations(String? size, String? flavour) {
    print('Getting price for - Size: $size, Flavour: $flavour'); // Debug log

    // For single variant products, return the option price directly
    if (variations.length == 1) {
      final variation = variations[0];
      final selectedValue = variation.type == 'SIZE' ? size : flavour;
      print(
          'Single variant product - Type: ${variation.type}, Selected: $selectedValue'); // Debug log

      if (selectedValue != null) {
        try {
          final option = variation.options.firstWhere(
            (o) => o.value == selectedValue,
          );
          print(
              'Found option - Value: ${option.value}, Price: ${option.priceAdjustment}'); // Debug log
          return option.priceAdjustment > 0
              ? option.priceAdjustment
              : basePrice;
        } catch (e) {
          print('Error finding option: $e'); // Debug log
          return basePrice;
        }
      }
    }

    // For multi-variant products, check combinations
    if (variantCombinations.isNotEmpty && size != null && flavour != null) {
      try {
        final combo = variantCombinations.firstWhere(
          (c) =>
              c['size'].toString() == size &&
              c['flavour'].toString() == flavour,
        );
        if (combo['price'] != null) {
          final price = combo['price'];
          return price is int ? price.toDouble() : (price as double);
        }
      } catch (_) {}
    }

    return basePrice;
  }

  double get price {
    // For single variant products, return the first option price
    if (variations.length == 1) {
      final options = variations[0].options;
      if (options.isNotEmpty) {
        return options[0].priceAdjustment;
      }
    }

    // For multi-variant products with combinations, return the first combination price
    if (variantCombinations.isNotEmpty) {
      final firstCombo = variantCombinations[0];
      final price = firstCombo['price'];
      if (price != null) {
        return price is int ? price.toDouble() : (price as double);
      }
    }

    // Only use base price if no variations exist
    return basePrice;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'status': status,
      'basePrice': basePrice,
      'categoryId': categoryId,
      'category': {
        'id': category.id,
        'name': category.name,
      },
      'images': images
          .map((i) => {
                'id': i.id,
                'url': i.url,
                'alt': i.alt,
                'isPrimary': i.isPrimary,
              })
          .toList(),
      'variations': variations
          .map((v) => {
                'id': v.id,
                'type': v.type,
                'options': v.options
                    .map((o) => {
                          'id': o.id,
                          'value': o.value,
                          'priceAdjustment': o.priceAdjustment,
                          'stock': o.stock,
                        })
                    .toList(),
              })
          .toList(),
      'variantCombinations': variantCombinations,
      'allowCustomText': allowCustomText,
      'sizes': sizes,
      'flavours': flavours,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      // Extract sizes and flavours from options
      List<String> extractedSizes = [];
      List<String> extractedFlavours = [];

      // Process options and extract values
      if (json['options'] != null && json['options'] is List) {
        for (var option in json['options']) {
          if (option is Map<String, dynamic> && option['name'] != null) {
            String optionName = option['name'].toString().toUpperCase();

            // Extract values for this option
            if (option['values'] != null && option['values'] is List) {
              List<String> values = [];
              for (var value in option['values']) {
                if (value is Map<String, dynamic> && value['value'] != null) {
                  values.add(value['value'].toString());
                }
              }

              // Determine if this is a size or flavour option
              if (optionName == 'SIZE') {
                extractedSizes = values;
                print('Extracted sizes: $extractedSizes');
              } else if (optionName == 'FLAVOUR' || optionName == 'FLAVOR') {
                extractedFlavours = values;
                print('Extracted flavours: $extractedFlavours');
              }
            }
          }
        }
      }

      // Process variants and their values
      List<ProductVariation> productVariations = [];
      List<Map<String, dynamic>> variantCombinations = [];

      if (json['variants'] != null && json['variants'] is List) {
        // Group variants by option type (SIZE/FLAVOUR)
        Map<String, ProductVariation> variationsMap = {};

        // First, process all variants to build combinations
        for (var variant in json['variants']) {
          if (variant is Map<String, dynamic>) {
            double variantPrice = variant['price'] is num
                ? (variant['price'] as num).toDouble()
                : 0.0;

            // Process variant values to determine which options they belong to
            if (variant['values'] != null && variant['values'] is List) {
              Map<String, dynamic> combinationData = {
                'price': variantPrice,
              };

              for (var valueData in variant['values']) {
                if (valueData is Map<String, dynamic> &&
                    valueData['value'] != null &&
                    valueData['value']['value'] != null) {
                  String optionName = '';
                  if (valueData['value']['option'] != null &&
                      valueData['value']['option']['name'] != null) {
                    optionName = valueData['value']['option']['name']
                        .toString()
                        .toUpperCase();
                  }

                  String optionValue = valueData['value']['value'].toString();

                  // Map to size/flavour for combinations
                  if (optionName == 'SIZE') {
                    combinationData['size'] = optionValue;
                  } else if (optionName == 'FLAVOUR' ||
                      optionName == 'FLAVOR') {
                    combinationData['flavour'] = optionValue;
                  }

                  // Create or update option variation
                  if (!variationsMap.containsKey(optionName)) {
                    variationsMap[optionName] = ProductVariation(
                      id: optionName,
                      type: optionName,
                      options: [],
                    );
                  }

                  // Add option if not already present
                  bool optionExists = variationsMap[optionName]!
                      .options
                      .any((o) => o.value == optionValue);
                  if (!optionExists) {
                    variationsMap[optionName]!.options.add(
                          ProductOption(
                            id: '$optionName-$optionValue',
                            value: optionValue,
                            priceAdjustment: variantPrice,
                            stock: variant['stock'] is num
                                ? (variant['stock'] as num).toInt()
                                : 0,
                          ),
                        );
                  }
                }
              }

              // Only add valid combinations
              if (combinationData.containsKey('size') ||
                  combinationData.containsKey('flavour')) {
                variantCombinations.add(combinationData);
              }
            }
          }
        }

        // Convert map to list
        productVariations = variationsMap.values.toList();

        // Log variation details
        print('Processed ${productVariations.length} variations:');
        for (var variation in productVariations) {
          print('- ${variation.type} with ${variation.options.length} options');
          for (var option in variation.options) {
            print('  - ${option.value}: ${option.priceAdjustment}');
          }
        }

        print('Generated ${variantCombinations.length} combinations:');
        for (var combo in variantCombinations) {
          print(
              '- Size: ${combo['size']}, Flavour: ${combo['flavour']}, Price: ${combo['price']}');
        }
      }

      // Get base price or calculate from options if needed
      double initialPrice = 0.0;

      // First try to get basePrice from json
      if (json['basePrice'] != null) {
        initialPrice = (json['basePrice'] is num)
            ? (json['basePrice'] as num).toDouble()
            : 0.0;
      }
      // Fallback to price
      else if (json['price'] != null) {
        initialPrice =
            (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0;
      }
      // If still no price but we have variations, use the first option's price
      else if (productVariations.isNotEmpty &&
          productVariations[0].options.isNotEmpty) {
        initialPrice = productVariations[0].options[0].priceAdjustment;
      }

      // Process images
      List<ProductImage> productImages = [];
      if (json['images'] != null && json['images'] is List) {
        productImages = (json['images'] as List).map<ProductImage>((img) {
          if (img is Map<String, dynamic>) {
            return ProductImage.fromJson(img);
          }
          return ProductImage(
            id: '',
            url: '',
            alt: '',
            isPrimary: false,
          );
        }).toList();
      }

      return Product(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown Product',
        description: json['description'] as String? ?? '',
        categoryId: json['categoryId'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        status: json['status'] as String? ?? 'ACTIVE',
        sizes: extractedSizes,
        flavours: extractedFlavours,
        variations: productVariations,
        variantCombinations: variantCombinations,
        category: ProductCategory.fromJson(
            json['category'] is Map<String, dynamic>
                ? json['category'] as Map<String, dynamic>
                : {'id': '', 'name': 'Uncategorized'}),
        basePrice: initialPrice,
        allowCustomText: json['allowCustomText'] as bool? ??
            (json['category'] != null &&
                json['category'] is Map<String, dynamic> &&
                json['category']['name'] != null &&
                json['category']['name'].toString().toLowerCase() == 'cake'),
        images: productImages,
      );
    } catch (e, stackTrace) {
      print('Error parsing product: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}
