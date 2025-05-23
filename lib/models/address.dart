enum AddressType { SHIPPING, BILLING }

class Address {
  String? id;
  String name;
  String street;
  String apartment;
  String emirate;
  String city;
  String pincode;
  String country;
  String phone;
  bool isDefault;
  AddressType type;
  DateTime? createdAt;
  DateTime? updatedAt;

  static const List<String> emirates = [
    'ABU_DHABI',
    'DUBAI',
    'SHARJAH',
    'AJMAN',
    'UMM_AL_QUWAIN',
    'RAS_AL_KHAIMAH',
    'FUJAIRAH',
    'AL_AIN'
  ];

  static String formatEmirateForDisplay(String emirate) {
    switch (emirate) {
      case 'ABU_DHABI':
        return 'Abu Dhabi';
      case 'DUBAI':
        return 'Dubai';
      case 'SHARJAH':
        return 'Sharjah';
      case 'AJMAN':
        return 'Ajman';
      case 'UMM_AL_QUWAIN':
        return 'Umm Al Quwain';
      case 'RAS_AL_KHAIMAH':
        return 'Ras Al Khaimah';
      case 'FUJAIRAH':
        return 'Fujairah';
      default:
        return emirate;
    }
  }

  Address({
    this.id,
    required this.name,
    required this.street,
    required this.apartment,
    required this.emirate,
    required this.city,
    this.pincode = '',
    this.country = 'United Arab Emirates',
    this.phone = '',
    this.isDefault = false,
    this.type = AddressType.SHIPPING,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    try {
      final emirate = json['emirate'] as String? ?? 'DUBAI';
      final typeStr = json['type'] as String? ?? 'SHIPPING';
      return Address(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        street: json['street'] as String? ?? '',
        apartment: json['apartment'] as String? ?? '',
        emirate: emirates.contains(emirate) ? emirate : 'DUBAI',
        city: json['city'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        country: json['country'] as String? ?? 'United Arab Emirates',
        phone: json['phone'] as String? ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
        type: AddressType.values.firstWhere(
          (e) => e.toString() == 'AddressType.$typeStr',
          orElse: () => AddressType.SHIPPING,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );
    } catch (e) {
      print('Error parsing address from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    try {
      return {
        if (id != null) 'id': id,
        'name': name.trim(),
        'street': street.trim(),
        'apartment': apartment.trim(),
        'emirate': emirate,
        'city': city.trim(),
        'pincode': pincode.trim(),
        'country': country,
        'phone': phone.trim(),
        'isDefault': isDefault,
        'type': type.toString().split('.').last,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
    } catch (e) {
      print('Error converting address to JSON: $e');
      rethrow;
    }
  }

  Address copyWith({
    String? id,
    String? name,
    String? street,
    String? apartment,
    String? emirate,
    String? city,
    String? pincode,
    String? country,
    String? phone,
    bool? isDefault,
    AddressType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      street: street ?? this.street,
      apartment: apartment ?? this.apartment,
      emirate: emirate ?? this.emirate,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedAddress {
    final parts = [
      name,
      street,
      if (apartment.isNotEmpty) apartment,
      city,
      formatEmirateForDisplay(emirate),
      if (pincode.isNotEmpty) pincode,
      country,
    ];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }
}
