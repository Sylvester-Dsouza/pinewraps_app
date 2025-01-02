import 'package:flutter/material.dart';
import '../../models/reward.dart';
import '../../services/api_service.dart';
import '../../widgets/tier_progress_card.dart';
import '../../widgets/reward_history_card.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<CustomerReward?> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = ApiService().getCustomerRewards();
  }

  Future<void> _refreshRewards() async {
    setState(() {
      _rewardsFuture = ApiService().getCustomerRewards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rewards'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRewards,
        child: FutureBuilder<CustomerReward?>(
          future: _rewardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading rewards',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }

            final rewards = snapshot.data;
            if (rewards == null) {
              return Center(
                child: Text(
                  'No rewards found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Points Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${rewards.points}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Available Points',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tier Progress
                TierProgressCard(
                  currentTier: rewards.tier,
                  totalPoints: rewards.totalPoints,
                ),
                const SizedBox(height: 16),

                // History Title
                const Text(
                  'Points History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // History List
                if (rewards.history.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No points history yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...rewards.history.map((history) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RewardHistoryCard(history: history),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
