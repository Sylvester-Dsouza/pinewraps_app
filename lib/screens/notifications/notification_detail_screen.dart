import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import '../../widgets/app_bar.dart';

class NotificationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailScreen({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String title = notification['title'] ?? 'No Title';
    final String body = notification['body'] ?? 'No Content';
    final DateTime? createdAt = notification['createdAt'] != null
        ? DateTime.parse(notification['createdAt'])
        : null;
    final String formattedDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt)
        : 'Unknown date';
    
    // Extract additional data if available
    final Map<String, dynamic> data = notification['data'] is Map
        ? Map<String, dynamic>.from(notification['data'])
        : {};
    
    // Check if there's an action type in the data
    final String? actionType = data['type'] as String?;
    final String? actionId = data['id'] as String?;
    final String? imageUrl = data['imageUrl'] as String?;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Notification Details',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and timestamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LineIcons.bell,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Body
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ),
            
            // Image if available
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // Action button if there's an action type
            if (actionType != null && actionId != null) ...[
              const SizedBox(height: 24),
              _buildActionButton(context, actionType, actionId),
            ],
            
            // Additional data section
            if (data.isNotEmpty && data.keys.any((key) => key != 'type' && key != 'id' && key != 'imageUrl')) ...[
              const SizedBox(height: 24),
              const Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildAdditionalDataSection(context, data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String actionType, String actionId) {
    String buttonText = 'View Details';
    IconData iconData = Icons.arrow_forward;
    
    // Customize button based on action type
    switch (actionType) {
      case 'order':
        buttonText = 'View Order';
        iconData = LineIcons.shoppingBag;
        break;
      case 'product':
        buttonText = 'View Product';
        iconData = LineIcons.tag;
        break;
      case 'reward':
        buttonText = 'View Reward';
        iconData = LineIcons.gift;
        break;
      case 'promotion':
        buttonText = 'View Promotion';
        iconData = LineIcons.percentage;
        break;
    }
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Handle different action types
          _handleActionButtonPress(context, actionType, actionId);
        },
        icon: Icon(iconData),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _handleActionButtonPress(BuildContext context, String actionType, String actionId) {
    // This would navigate to different screens based on the action type
    // For now, just show a snackbar with the action info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: $actionType, ID: $actionId'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAdditionalDataSection(BuildContext context, Map<String, dynamic> data) {
    // Filter out special keys that we handle separately
    final filteredData = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => ['type', 'id', 'imageUrl'].contains(key));
    
    if (filteredData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredData.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, index) {
          final key = filteredData.keys.elementAt(index);
          final value = filteredData[key];
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatKey(key),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatKey(String key) {
    // Convert camelCase or snake_case to Title Case with spaces
    final formattedKey = key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceAll('_', ' ')
        .trim();
    
    return formattedKey.substring(0, 1).toUpperCase() + formattedKey.substring(1);
  }
}
