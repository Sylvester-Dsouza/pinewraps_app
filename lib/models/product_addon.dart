class AddonOption {
  final String id;
  final String name;
  final double price;
  final bool allowsCustomText;
  final String? customTextLabel;
  final int? maxTextLength;

  AddonOption({
    required this.id,
    required this.name,
    required this.price,
    this.allowsCustomText = false,
    this.customTextLabel,
    this.maxTextLength,
  });

  factory AddonOption.fromJson(Map<String, dynamic> json) {
    return AddonOption(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      allowsCustomText: json['allowsCustomText'] as bool? ?? false,
      customTextLabel: json['customTextLabel'] as String?,
      maxTextLength: json['maxTextLength'] as int?,
    );
  }
}

class ProductAddon {
  final String id;
  final String name;
  final String description;
  final bool required;
  final int minSelections;
  final int maxSelections;
  final List<AddonOption> options;

  ProductAddon({
    required this.id,
    required this.name,
    required this.description,
    required this.required,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  factory ProductAddon.fromJson(Map<String, dynamic> json) {
    return ProductAddon(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      minSelections: json['minSelections'] as int? ?? 0,
      maxSelections: json['maxSelections'] as int? ?? 1,
      options: (json['options'] as List<dynamic>?)
              ?.map((option) => AddonOption.fromJson(option as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SelectedAddonOption {
  final String addonId;
  final String optionId;
  final String? customText;
  final int selectionIndex;

  SelectedAddonOption({
    required this.addonId,
    required this.optionId,
    this.customText,
    this.selectionIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'addonId': addonId,
      'optionId': optionId,
      'customText': customText,
      'selectionIndex': selectionIndex,
    };
  }

  factory SelectedAddonOption.fromJson(Map<String, dynamic> json) {
    return SelectedAddonOption(
      addonId: json['addonId'] as String,
      optionId: json['optionId'] as String,
      customText: json['customText'] as String?,
      selectionIndex: json['selectionIndex'] as int? ?? 0,
    );
  }
}
