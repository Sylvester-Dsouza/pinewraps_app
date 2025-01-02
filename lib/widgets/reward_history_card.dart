import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reward.dart';

class RewardHistoryCard extends StatelessWidget {
  final RewardHistory history;

  const RewardHistoryCard({
    Key? key,
    required this.history,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEarned = history.action == RewardHistoryType.EARNED;
    final points = isEarned ? history.pointsEarned : history.pointsRedeemed;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEarned ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isEarned ? Icons.add_circle : Icons.remove_circle,
            color: isEarned ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          history.description,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy').format(history.createdAt),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '${isEarned ? '+' : '-'}$points pts',
          style: TextStyle(
            color: isEarned ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
