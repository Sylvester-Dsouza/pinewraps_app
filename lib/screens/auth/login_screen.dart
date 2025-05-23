import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
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
  bool _obscurePassword = true;
  String? _errorMessage; // Used in _showError method

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    // Used to display success messages to the user
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
      print(
          'Attempting to sign in with email: ${_emailController.text.trim()}');

      // Attempt to sign in
      final customerData = await _authService.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('Login successful: $customerData');

      // Make sure we have the latest auth state
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found after login.',
        );
      }

      if (mounted) {
        _showSuccess('Login successful! Welcome back.');

        // Navigate to main screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage = 'Authentication failed';

      // Handle specific Firebase errors
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user has been disabled.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }

      _showError(errorMessage);
    } on ApiException catch (e) {
      print('API Error: ${e.message} (${e.statusCode})');
      _showError(e.message);
    } catch (e) {
      print('Unexpected Error: $e');
      _showError('An unexpected error occurred');
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
    });

    try {
      // Show loading indicator for social login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signing in with Google...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Start Google Sign In process with improved error handling
      print('Starting Google sign-in process');
      final googleUser =
          await _authService.startGoogleSignIn().catchError((error) {
        print('Caught error in UI layer: $error');
        // Convert any errors to ApiException for consistent handling
        if (error is! ApiException) {
          throw ApiException(
            message: 'Google sign-in failed: ${error.toString()}',
            statusCode: 401,
          );
        }
        throw error;
      });

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
          _showSuccess('Login successful! Welcome back.');

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

        // Special handling for error code 10 (common Google Sign In issue)
        if (e.message.contains('configuration issue') ||
            e.toString().contains('ApiException: 10:')) {
          errorMessage =
              'Google Sign In is not properly configured. Please check your internet connection and try again.';
        }
      } else if (e is FirebaseAuthException) {
        // Handle specific Firebase auth errors
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage =
                'An account already exists with the same email address but different sign-in credentials';
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
      } else if (e.toString().contains('PlatformException')) {
        // Handle platform exceptions
        if (e.toString().contains('sign_in_failed') ||
            e.toString().contains('ApiException: 10:')) {
          errorMessage =
              'Google Sign In failed. Please check your internet connection and try again.';
        } else {
          errorMessage = 'Sign in error: ${e.toString().split(',')[0]}';
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
    });

    try {
      // First check if we're on iOS
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        throw ApiException(
          message: 'Apple Sign In is only available on iOS devices',
          statusCode: 400,
        );
      }

      // Attempt to sign in with Apple
      final userInfo = await _authService.signInWithApple();
      print('Apple sign in successful: $userInfo');

      if (mounted) {
        _showSuccess('Login successful! Welcome back.');

        // Navigate to main screen and remove all previous routes
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      print('Apple Sign In Error: $e');

      String errorMessage = 'Failed to sign in with Apple';

      if (e is ApiException) {
        errorMessage = e.message;
      } else if (e is FirebaseAuthException) {
        // Handle specific Firebase auth errors
        switch (e.code) {
          case 'invalid-credential':
            errorMessage = 'Invalid Apple credentials. Please try again.';
            break;
          case 'user-disabled':
            errorMessage = 'Your account has been disabled';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Apple Sign In is not enabled for this app';
            break;
          default:
            errorMessage =
                e.message ?? 'An error occurred during Apple sign in';
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error message display
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),

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
                  decoration: AuthStyles.inputDecoration('Email').copyWith(
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
                  decoration: AuthStyles.inputDecoration('Password').copyWith(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
                // Only show Google sign-in on Android
                if (defaultTargetPlatform == TargetPlatform.android) ...[
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: AuthStyles.outlinedButtonStyle,
                    icon: Image.asset(
                      'assets/images/google.png',
                      height: 18,
                    ),
                    label: Text('Continue with Google',
                        style: AuthStyles.buttonTextStyle),
                  ),
                  const SizedBox(height: 16),

                  // Continue without login button below Google sign-in
                  TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue without login',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Only show Apple sign-in on iOS
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithApple,
                    style: AuthStyles.outlinedButtonStyle,
                    icon: Image.asset(
                      'assets/images/apple.png',
                      height: 20,
                    ),
                    label: Text('Continue with Apple',
                        style: AuthStyles.buttonTextStyle),
                  ),
                  const SizedBox(height: 16),

                  // Continue without login button below Apple sign-in
                  TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue without login',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: RichText(
                    text: TextSpan(
                      style: AuthStyles.subtitleStyle,
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign Up',
                          style: AuthStyles.linkStyle,
                        ),
                      ],
                    ),
                  ),
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
                const SizedBox(height: 24),
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
