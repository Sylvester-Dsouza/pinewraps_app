import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
      // Attempt to sign in
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Make sure we have the latest auth state
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Login failed. Please try again.',
        );
      }

      if (mounted) {
        _showSuccess('Login successful! Welcome back.');
        
        // Wait a moment to show the success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to main screen and remove all previous routes
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.message}');
      String errorMessage = 'An error occurred during login';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Invalid password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please try again.';
      }
      
      _showError(errorMessage);
    } catch (e) {
      print('Login Error: $e');
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Show loading indicator for social login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signing in with Google...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Start Google Sign In process
      print('Starting Google sign-in process');
      final googleUser = await _authService.startGoogleSignIn();
      
      if (googleUser != null && mounted) {
        // Show loading indicator for backend sync
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completing sign-in...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Complete the backend sync and wait for it
        print('Completing backend sync for user: ${googleUser.email}');
        final result = await _authService.completeGoogleSignIn(googleUser);
        print('Backend sync completed successfully');
        
        if (result.isEmpty) {
          throw ApiException(
            message: 'Failed to sync user data with backend',
            statusCode: 500,
          );
        }

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in successful!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to main screen and remove all previous routes
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        print('Google sign-in was cancelled or returned null');
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
        print('API Exception: ${e.message} (${e.statusCode})');
      } else if (e is FirebaseAuthException) {
        // Handle specific Firebase auth errors
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = 'An account already exists with the same email address but different sign-in credentials';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid credentials';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Google sign-in is not enabled for this project';
            break;
          case 'user-disabled':
            errorMessage = 'Your account has been disabled';
            break;
          case 'user-not-found':
          case 'wrong-password':
            errorMessage = 'Invalid login credentials';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred during sign in';
        }
      } else {
        print('Unknown error: $e');
      }
      
      _showError(errorMessage);
      
      // Additional user feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
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
      
      if (mounted) {
        // Navigate to main screen and remove all previous routes
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
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
                const Row(
                  children: [
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
                // Only show Apple Sign-In button on iOS
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
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
                ],
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
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
