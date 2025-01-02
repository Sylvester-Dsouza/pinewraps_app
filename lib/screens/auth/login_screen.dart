import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../styles/auth_styles.dart';
import '../main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );
      
      if (mounted) {
        // Navigate to main screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'An error occurred');
    } catch (e) {
      _showError('An unexpected error occurred');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Start Google Sign In process
      final googleUser = await _authService.startGoogleSignIn();
      if (googleUser != null && mounted) {
        // Complete the backend sync and wait for it
        final result = await _authService.completeGoogleSignIn(googleUser);
        print('Backend sync completed: $result'); // Debug log
        
        if (result.isEmpty) {
          throw ApiException(
            message: 'Failed to sync user data with backend',
            statusCode: 500,
          );
        }

        if (mounted) {
          // Navigate to main screen and remove all previous routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        throw ApiException(
          message: 'Google sign in was cancelled',
          statusCode: 401,
        );
      }
    } catch (e) {
      print('Google Sign In Error: $e'); // Debug log
      String errorMessage = 'Failed to sign in with Google';
      if (e is ApiException) {
        errorMessage = e.message;
      }
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithApple();
      print('Apple sign in result: $result'); // Debug log
      
      if (result != null && mounted) {
        // Navigate to main screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Apple Sign In Error: $e'); // Debug log
      _showError('Failed to sign in with Apple');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // const SizedBox(height: 48),
                // Image.asset(
                //   'assets/images/logo.png',
                //   height: 60,
                //   fit: BoxFit.contain,
                // ),
                const SizedBox(height: 32),
                Text(
                  'Welcome To PINEWRAPS',
                  style: AuthStyles.titleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue shopping',
                  style: AuthStyles.subtitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: AuthStyles.inputDecoration('Email')
                    .copyWith(
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: AuthStyles.inputDecoration('Password')
                    .copyWith(
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signInWithEmailPassword(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmailPassword,
                  style: AuthStyles.elevatedButtonStyle,
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Login', style: AuthStyles.buttonTextStyle),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: AuthStyles.outlinedButtonStyle,
                  icon: Image.asset(
                    'assets/images/google.png',
                    height: 18,
                  ),
                  label: Text('Continue with Google', style: AuthStyles.buttonTextStyle),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithApple,
                  style: AuthStyles.outlinedButtonStyle,
                  icon: Image.asset(
                    'assets/images/apple.png',
                    height: 20,
                  ),
                  label: Text('Continue with Apple', style: AuthStyles.buttonTextStyle),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: null, // Disabled for now
                  style: AuthStyles.outlinedButtonStyle,
                  icon: Image.asset(
                    'assets/images/facebook.png',
                    height: 20,
                  ),
                  label: Text('Continue with Facebook', style: AuthStyles.buttonTextStyle),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/register');
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot-password');
                  },
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
