import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'address_screen.dart';
import 'help_support_screen.dart';
import 'edit_profile_screen.dart';
import '../orders/order_history_screen.dart';
import './rewards_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getUserProfile();
      print('Loaded profile: $profile');
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                child: const Icon(
                  Icons.person_outline,
                  size: 30,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        _userProfile != null && (_userProfile!['firstName'] != null || _userProfile!['lastName'] != null)
                            ? '${_userProfile!['firstName'] ?? ''} ${_userProfile!['lastName'] ?? ''}'.trim()
                            : 'Guest User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _userProfile != null && _userProfile!['email'] != null 
                          ? _userProfile!['email'] 
                          : 'Welcome to Pinewraps',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditProfileButton(),
        ],
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditProfileScreen(),
            ),
          );
          
          // Refresh profile data when returning from edit screen
          if (result == true) {
            _loadUserProfile();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: const Text('Edit Profile'),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.black,
    Widget? trailing,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title),
          trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(height: 1, indent: 70),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text(
                    'My Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: const Text('My Orders'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_border_rounded),
                  title: const Text('My Rewards'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RewardsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Delivery Addresses'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddressScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
