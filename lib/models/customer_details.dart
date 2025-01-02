class CustomerDetails {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final DateTime? birthDate;
  final bool isEmailVerified;
  final int rewardPoints;
  final String rewardTier;  
  final String? imageUrl;
  final String? provider;

  CustomerDetails({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.birthDate,
    this.isEmailVerified = false,
    this.rewardPoints = 0,
    this.rewardTier = 'BRONZE',  
    this.imageUrl,
    this.provider,
  });

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    return CustomerDetails(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      isEmailVerified: json['isEmailVerified'] ?? false,
      rewardPoints: json['rewardPoints'] ?? 0,
      rewardTier: json['rewardTier'] ?? 'BRONZE',
      imageUrl: json['imageUrl'],
      provider: json['provider'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate?.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'rewardPoints': rewardPoints,
      'rewardTier': rewardTier,
      'imageUrl': imageUrl,
      'provider': provider,
    };
  }
}
