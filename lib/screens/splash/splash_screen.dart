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
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Navigate after animation
    Future.delayed(const Duration(seconds: 3), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => user != null ? const MainScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
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
