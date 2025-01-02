enum RewardTier {
  GREEN,
  SILVER,
  GOLD,
  PLATINUM,
}

enum RewardHistoryType {
  EARNED,
  REDEEMED,
}

class CustomerReward {
  final String id;
  final String customerId;
  final RewardTier tier;
  final int points;
  final int totalPoints;
  final List<RewardHistory> history;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerReward({
    required this.id,
    required this.customerId,
    required this.tier,
    required this.points,
    required this.totalPoints,
    required this.history,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerReward.fromJson(Map<String, dynamic> json) {
    return CustomerReward(
      id: json['id'],
      customerId: json['customerId'],
      tier: RewardTier.values.firstWhere(
        (e) => e.toString().split('.').last == json['tier'],
        orElse: () => RewardTier.GREEN,
      ),
      points: json['points'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      history: (json['history'] as List<dynamic>?)
          ?.map((e) => RewardHistory.fromJson(e))
          .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'tier': tier.toString().split('.').last,
      'points': points,
      'totalPoints': totalPoints,
      'history': history.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class RewardHistory {
  final String id;
  final String customerId;
  final String orderId;
  final String rewardId;
  final int pointsEarned;
  final int pointsRedeemed;
  final double orderTotal;
  final RewardHistoryType action;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RewardHistory({
    required this.id,
    required this.customerId,
    required this.orderId,
    required this.rewardId,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.orderTotal,
    required this.action,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RewardHistory.fromJson(Map<String, dynamic> json) {
    return RewardHistory(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      rewardId: json['rewardId'] as String? ?? '',
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      orderTotal: (json['orderTotal'] as num?)?.toDouble() ?? 0.0,
      action: RewardHistoryType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['action'] as String? ?? 'EARNED'),
        orElse: () => RewardHistoryType.EARNED,
      ),
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'orderId': orderId,
      'rewardId': rewardId,
      'pointsEarned': pointsEarned,
      'pointsRedeemed': pointsRedeemed,
      'orderTotal': orderTotal,
      'action': action.toString().split('.').last,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
