import 'package:flutter/material.dart';
import '../models/reward.dart';

class NextTierInfo {
  final RewardTier tier;
  final int pointsNeeded;
  final double progress;

  const NextTierInfo({
    required this.tier,
    required this.pointsNeeded,
    required this.progress,
  });
}

Color getTierColor(RewardTier tier) {
  switch (tier) {
    case RewardTier.GREEN:
      return Colors.green;
    case RewardTier.SILVER:
      return Colors.grey;
    case RewardTier.GOLD:
      return Colors.amber;
    case RewardTier.PLATINUM:
      return Colors.blue;
  }
}

String getTierBenefits(RewardTier tier) {
  switch (tier) {
    case RewardTier.GREEN:
      return 'Earn  point for every spent';
    case RewardTier.SILVER:
      return 'Earn  point for every spent';
    case RewardTier.GOLD:
      return 'Earn  point for every spent';
    case RewardTier.PLATINUM:
      return 'Earn  point for every spent';
  }
}

NextTierInfo? getNextTierInfo(RewardTier currentTier, int totalPoints) {
  switch (currentTier) {
    case RewardTier.GREEN:
      const pointsNeeded = 1000;
      return NextTierInfo(
        tier: RewardTier.SILVER,
        pointsNeeded: pointsNeeded - totalPoints,
        progress: totalPoints / pointsNeeded,
      );
    case RewardTier.SILVER:
      const pointsNeeded = 5000;
      return NextTierInfo(
        tier: RewardTier.GOLD,
        pointsNeeded: pointsNeeded - totalPoints,
        progress: totalPoints / pointsNeeded,
      );
    case RewardTier.GOLD:
      const pointsNeeded = 10000;
      return NextTierInfo(
        tier: RewardTier.PLATINUM,
        pointsNeeded: pointsNeeded - totalPoints,
        progress: totalPoints / pointsNeeded,
      );
    case RewardTier.PLATINUM:
      return null;
  }
}

int getPointsForTier(RewardTier tier) {
  switch (tier) {
    case RewardTier.GREEN:
      return 0;
    case RewardTier.SILVER:
      return 1000;
    case RewardTier.GOLD:
      return 5000;
    case RewardTier.PLATINUM:
      return 10000;
  }
}
