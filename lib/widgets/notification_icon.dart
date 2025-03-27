import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import '../screens/notifications/notification_screen.dart';
import '../services/notification_service.dart';

class NotificationIcon extends StatefulWidget {
  const NotificationIcon({
    Key? key,
  }) : super(key: key);

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  int _unreadNotificationCount = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Listen to unread count changes
    _notificationService.unreadCount.listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(LineIcons.bell),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationScreen(),
              ),
            ).then((_) {
              // Refresh unread count when returning from notification screen
              _notificationService.refreshUnreadCount();
            });
          },
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadNotificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
