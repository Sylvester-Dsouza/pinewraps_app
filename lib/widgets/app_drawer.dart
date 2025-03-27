import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/main_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final bool isLoggedIn = user != null;

        return Drawer(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                        ),
                        child: isLoggedIn && user.photoURL != null
                            ? ClipOval(
                                child: Image.network(
                                  user.photoURL!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.person_outline,
                                  size: 40,
                                  color: Colors.black54,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      if (isLoggedIn) ...[
                        Text(
                          user.displayName ?? 'Welcome!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.email != null)
                          Text(
                            user.email!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ] else ...[
                        const Text(
                          'Welcome!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Sign in / Register',
                            style: TextStyle(
                              color: Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildDrawerItem(
                        icon: Icons.home_rounded,
                        title: 'Home',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainScreen(initialIndex: 0),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.shopping_bag_rounded,
                        title: 'Shop',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainScreen(initialIndex: 1),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      if (isLoggedIn) ...[
                        _buildDrawerItem(
                          icon: Icons.shopping_cart_rounded,
                          title: 'Cart',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainScreen(initialIndex: 2),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.person_rounded,
                          title: 'Profile',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainScreen(initialIndex: 3),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          onTap: () async {
                            // Show confirmation dialog
                            final shouldLogout = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text('Are you sure you want to logout?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldLogout == true) {
                              try {
                                await AuthService().signOut();
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Error logging out. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}
