import 'package:flutter/material.dart';
import 'package:pinewraps_app/widgets/notification_icon.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showNotificationIcon;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showBackButton = true,
    this.showNotificationIcon = true,
    this.onBackPressed,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: [
        if (showNotificationIcon) const NotificationIcon(),
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
