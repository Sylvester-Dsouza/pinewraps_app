import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    print("SplashScreen initState called");
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
    print("Animation controller started");

    // Navigate after animation
    print("Setting up navigation delay");
    Future.delayed(const Duration(seconds: 3), () {
      print("Navigation delay completed, checking auth");
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    print("_checkAuthAndNavigate started");
    try {
      print("Getting current user");
      final user = FirebaseAuth.instance.currentUser;
      print("Current user: ${user?.uid ?? 'null'}");
      
      if (!mounted) {
        print("Widget not mounted, returning");
        return;
      }
      
      if (user != null) {
        print("User is logged in, navigating to MainScreen");
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print("User is not logged in, navigating to LoginScreen");
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print("Error during navigation: $e");
      // Fallback to login screen if there's an error
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    print("SplashScreen dispose called");
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/splash_icon.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              // App Name
              // const Text(
              //   'Pine Wraps',
              //   style: TextStyle(
              //     fontSize: 32,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.black,
              //   ),
              // ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
