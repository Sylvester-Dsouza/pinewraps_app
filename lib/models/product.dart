import 'dart:convert';
import 'dart:math';

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
    this.allowCustomText = false,
  });

  String? get imageUrl => images.isNotEmpty ? images[0].url : null;

  List<String> get sizes {
    final sizeVariation = getVariationByType('SIZE');
    return sizeVariation?.options.map((o) => o.value).toList() ?? [];
  }

  List<String> get flavours {
    final flavourVariation = getVariationByType('FLAVOUR');
    return flavourVariation?.options.map((o) => o.value).toList() ?? [];
  }

  ProductVariation? getVariationByType(String type) {
    try {
      return variations.firstWhere(
        (v) => v.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  // Get formatted price string
  String getFormattedPrice() {
    // For single variant products, show the option prices directly
    if (variations.length == 1) {
      final options = variations[0].options;
      if (options.isNotEmpty) {
        // Get all prices directly from options
        final prices = options.map((opt) => opt.priceAdjustment).toList()..sort();
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
    // For single variant products, return the option price directly
    if (variations.length == 1) {
      final variation = variations[0];
      final selectedValue = variation.type == 'SIZE' ? size : flavour;
      
      if (selectedValue != null) {
        try {
          final option = variation.options.firstWhere(
            (o) => o.value == selectedValue,
          );
          // Return the option price directly, not as an adjustment
          return option.priceAdjustment;
        } catch (_) {}
      }
    }
    
    // For multi-variant products, check combinations
    if (variantCombinations.isNotEmpty && size != null && flavour != null) {
      try {
        final combo = variantCombinations.firstWhere(
          (c) => c['size'].toString() == size && c['flavour'].toString() == flavour,
        );
        final price = combo['price'];
        return price is int ? price.toDouble() : (price as double);
      } catch (_) {}
    }
    
    // Only use base price if no variations exist
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
      'images': images.map((i) => {
        'id': i.id,
        'url': i.url,
        'alt': i.alt,
        'isPrimary': i.isPrimary,
      }).toList(),
      'variations': variations.map((v) => {
        'id': v.id,
        'type': v.type,
        'options': v.options.map((o) => {
          'id': o.id,
          'value': o.value,
          'priceAdjustment': o.priceAdjustment,
          'stock': o.stock,
        }).toList(),
      }).toList(),
      'variantCombinations': variantCombinations,
      'allowCustomText': allowCustomText,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseCombinations(dynamic combinations) {
      if (combinations == null) return [];
      if (combinations is String) {
        try {
          final List<dynamic> parsed = jsonDecode(combinations);
          return List<Map<String, dynamic>>.from(parsed);
        } catch (e) {
          print('Error parsing variant combinations: $e');
          return [];
        }
      }
      if (combinations is List) {
        return List<Map<String, dynamic>>.from(combinations);
      }
      return [];
    }

    try {
      // Parse variations first so we can use them for initial price
      final variations = json['variations'] != null
          ? (json['variations'] as List)
              .map((v) => ProductVariation.fromJson(v as Map<String, dynamic>))
              .toList()
          : <ProductVariation>[];

      // For single variant products, use the first option's price as base price
      double initialPrice = ((json['basePrice'] ?? json['price']) as num).toDouble();
      if (variations.length == 1 && variations[0].options.isNotEmpty) {
        initialPrice = variations[0].options[0].priceAdjustment;
      }

      return Product(
        id: json['_id'] as String? ?? json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        basePrice: initialPrice,  // Use the calculated initial price
        categoryId: json['categoryId'] as String? ?? '',
        variations: variations,  // Use the already parsed variations
        images: json['images'] != null
            ? (json['images'] as List)
                .map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
                .toList()
            : [],
        category: json['category'] != null
            ? ProductCategory.fromJson(json['category'] as Map<String, dynamic>)
            : ProductCategory(id: '', name: ''),
        variantCombinations: parseCombinations(json['variantCombinations']),
        allowCustomText: json['allowCustomText'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      print('Error parsing product: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }
}
