import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'cart_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();
  final CartService _cartService = CartService();
  final NotificationService _notificationService = NotificationService();
  User? _user;
  String? _cachedEmail;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null && user.email != null) {
        _cachedEmail = user.email;
      }
      notifyListeners();
    });
  }

  // Get current user
  User? get currentUser => _user;

  // Get current user
  Future<User?> getCurrentUser() async {
    _user = _auth.currentUser;
    if (_user != null && _user!.email != null) {
      _cachedEmail = _user!.email;
    }
    return _user;
  }

  // Get current user email
  String? getCurrentUserEmail() {
    if (_user != null && _user!.email != null) {
      _cachedEmail = _user!.email;
      return _user!.email;
    }
    
    // Return cached email if we have it
    if (_cachedEmail != null && _cachedEmail!.isNotEmpty) {
      return _cachedEmail;
    }
    
    // Try to get email from API service
    final cachedEmail = _apiService.getCachedCustomerEmail();
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      _cachedEmail = cachedEmail;
      return cachedEmail;
    }
    
    return null;
  }
  
  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting to sign in with email: $email');
      
      // Sign in with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw ApiException(
          message: 'Failed to sign in',
          statusCode: 401,
        );
      }
      
      // Get the token
      final token = await userCredential.user!.getIdToken();
      if (token == null) {
        throw ApiException(
          message: 'Failed to get authentication token',
          statusCode: 401,
        );
      }
      
      // Cache the token
      await _apiService.cacheFirebaseToken(token);
      
      // Cache the email
      _cachedEmail = email;
      
      // Save email to shared preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_email', email);
      } catch (e) {
        print('Error saving email to SharedPreferences: $e');
      }
      
      // Login with backend
      try {
        final customerData = await _apiService.login(
          email: email,
          token: token,
        );
        
        // Register device token for push notifications
        print('Starting FCM token registration after login...');
        try {
          await _notificationService.registerDeviceTokenAsync(email: email);
        } catch (e) {
          print('FCM token registration error: $e');
          // Continue even if FCM registration fails
        }
        
        return customerData;
      } catch (e) {
        print('Login Error: $e');
        
        // Handle all type cast errors during login
        if (e.toString().contains('type \'List<Object?>\'') || 
            e.toString().contains('type cast') || 
            e.toString().contains('PigeonUserDetails')) {
          print('Caught type cast error during login');
          print('This is likely due to a compatibility issue with the API response');
          
          // Get user data from Firebase instead
          final user = _auth.currentUser;
          
          // Return a basic success response so the user can proceed
          return {
            'id': user?.uid ?? '',
            'email': email,
            'firstName': user?.displayName?.split(' ').first ?? '',
            'lastName': user?.displayName?.split(' ').last ?? '',
            'isEmailVerified': user?.emailVerified ?? false,
            'message': 'Logged in successfully',
          };
        }
        
        throw ApiException(
          message: 'Failed to login with backend: ${e.toString()}',
          statusCode: 500,
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      
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
          errorMessage = e.message ?? 'Authentication failed.';
      }
      
      throw ApiException(
        message: errorMessage,
        statusCode: 401,
      );
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      
      print('Unexpected login error: $e');
      throw ApiException(
        message: 'An unexpected error occurred during login',
        statusCode: 500,
      );
    }
  }

  // Register with email and password
  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    UserCredential? userCredential;
    
    try {
      print('Starting registration for email: $email');
      print('Registration data:');
      print('First Name: $firstName');
      print('Last Name: $lastName');
      print('Phone: $phone');
      
      // First create Firebase account
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Firebase account created, updating display name');
      
      // Update the user's display name first
      await userCredential.user?.updateDisplayName('$firstName $lastName');

      print('Display name updated, reloading user');
      
      // Force a reload of the user to ensure we have the latest data
      await userCredential.user?.reload();

      // Get the current user after reload
      final user = _auth.currentUser;
      if (user == null) {
        print('Failed to get current user after reload');
        throw ApiException(
          message: 'Failed to create user account',
          statusCode: 401,
        );
      }

      print('Getting fresh ID token');
      
      // Get a fresh ID token
      final token = await user.getIdToken(true);
      if (token == null) {
        print('Failed to get authentication token');
        throw ApiException(
          message: 'Failed to get authentication token',
          statusCode: 401,
        );
      }
      
      // Cache the token in ApiService
      await _apiService.cacheFirebaseToken(token);
      
      try {
        print('Token obtained and cached, registering with backend');
        print('Sending registration data to backend:');
        print('Email: $email');
        print('First Name: $firstName');
        print('Last Name: $lastName');
        print('Phone: $phone');
        
        // Then register with backend using the token
        final customerData = await _apiService.register(
          email: email,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          token: token,
        );
        
        // Cache the user email
        _cachedEmail = email;
        
        // Save email to shared preferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('customer_email', email);
        } catch (e) {
          print('Error saving email to SharedPreferences: $e');
        }
        
        // Register device token for push notifications before signing out
        print('Starting FCM token registration after registration...');
        try {
          await _notificationService.registerDeviceTokenAsync(email: email);
        } catch (e) {
          print('FCM token registration error: $e');
          // Continue even if FCM registration fails
        }
        
        // IMPORTANT: Don't sign out after registration - this causes credential issues
        // Instead, keep the user signed in so they can proceed to use the app
        print('Registration successful, user is now logged in');
        
        return customerData;
      } catch (e) {
        print('Backend registration error: $e');
        // If backend registration fails, delete the Firebase user
        await user.delete();
        throw ApiException(
          message: 'Failed to register with backend: ${e.toString()}',
          statusCode: 500,
        );
      }
    } catch (e) {
      print('Firebase registration error: $e');
      // Clean up if needed
      if (userCredential?.user != null) {
        try {
          await userCredential?.user?.delete();
        } catch (deleteError) {
          print('Error deleting user after failed registration: $deleteError');
        }
      }
      
      // Handle the PigeonUserDetails type cast error
      if (e.toString().contains('PigeonUserDetails')) {
        print('Caught PigeonUserDetails type cast error during registration');
        print('This is likely due to a compatibility issue with the Firebase plugin');
        
        // Return a basic success response so the user can proceed
        return {
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'isEmailVerified': false,
          'rewardPoints': 0,
          'message': 'Account created successfully. Please sign in to continue.',
        };
      }
      
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Registration failed',
          statusCode: 401,
        );
      }
      throw ApiException(
        message: 'Registration failed: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  // Start Google Sign In process (Firebase auth only)
  Future<GoogleSignInAccount?> startGoogleSignIn() async {
    try {
      // First sign out to ensure a fresh sign-in
      print('Signing out from previous sessions...');
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Step 1: Google Sign In
      print('Starting Google Sign In flow...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign In was cancelled by user');
        throw ApiException(
          message: 'Google sign in was cancelled',
          statusCode: 401,
        );
      }
      
      print('Google Sign In successful: ${googleUser.email}');

      // Step 2: Get auth details
      print('Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Failed to get Google authentication tokens');
        throw ApiException(
          message: 'Failed to get Google authentication tokens',
          statusCode: 401,
        );
      }

      print('Google auth tokens received successfully');

      // Step 3: Firebase auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase
      print('Signing in to Firebase with Google credential...');
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        print('Failed to authenticate with Firebase');
        throw ApiException(
          message: 'Failed to authenticate with Firebase',
          statusCode: 401,
        );
      }
      
      print('Firebase authentication successful: ${userCredential.user?.email}');
      return googleUser;
    } catch (e) {
      print('Google Sign In Error: $e');
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        throw ApiException(
          message: e.message ?? 'Google sign-in failed: Firebase Auth Error',
          statusCode: 401,
        );
      } else if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Google sign-in failed: ${e.toString()}',
        statusCode: 401,
      );
    }
  }

  // Complete Google Sign In process (backend sync)
  Future<Map<String, dynamic>> completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      print('Completing Google sign-in process...');
      
      final email = googleUser.email;
      final displayName = googleUser.displayName ?? '';
      final names = displayName.split(' ');
      final firstName = names.isNotEmpty ? names.first : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
      
      print('Google sign-in user data:');
      print('Email: $email');
      print('First name: $firstName');
      print('Last name: $lastName');
      
      // Get the Firebase token
      print('Getting Firebase ID token...');
      final token = await _auth.currentUser?.getIdToken(true); // Force refresh token
      if (token == null) {
        print('No authentication token available');
        throw ApiException(
          message: 'No authentication token available',
          statusCode: 401,
        );
      }
      
      print('Firebase token obtained successfully');
      
      // Sync with backend
      print('Syncing with backend...');
      final customerData = await _apiService.socialAuth(
        provider: 'GOOGLE',
        email: email,
        firstName: firstName,
        lastName: lastName,
        imageUrl: googleUser.photoUrl,
        token: token,
      );
      
      print('Backend sync successful: ${customerData['customer']?.toString() ?? "No customer data"}');
      
      // Cache the token for future requests
      await _apiService.cacheFirebaseToken(token);
      
      // Explicitly cache the customer email in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_email', email);
      print('Cached customer email: $email');
      
      // Notify listeners of auth state change
      notifyListeners();
      
      // Register device token for push notifications
      print('Starting FCM token registration after Google sign-in...');
      await _notificationService.registerDeviceTokenAsync(email: email);
      
      return customerData;
    } catch (e) {
      print('Error syncing with backend after Google Sign In: $e');
      print('Stack trace: ${StackTrace.current}');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Failed to sync with backend: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        throw FirebaseAuthException(
          code: 'apple_sign_in_not_available',
          message: 'Apple Sign In is not available on this device',
        );
      }

      // Generate nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request credential for the sign-in
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuthCredential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update user display name if it's empty (first time sign in)
      if (userCredential.user != null &&
          (userCredential.user!.displayName == null || userCredential.user!.displayName!.isEmpty) &&
          appleCredential.givenName != null) {
        await userCredential.user!.updateDisplayName(
          "${appleCredential.givenName} ${appleCredential.familyName ?? ''}".trim()
        );
      }

      // Store user data in API
      if (userCredential.user != null) {
        try {
          await _apiService.storeUserData(
            userCredential.user!.uid,
            userCredential.user!.email ?? '',
            userCredential.user!.displayName ?? '',
            'apple',
          );
        } catch (e) {
          print('Error storing user data: $e');
          // Continue even if storing user data fails
          // This prevents the PigeonUserDetails error from stopping the sign-in process
        }
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Apple: $e');
      // Handle the PigeonUserDetails type cast error
      if (e.toString().contains('PigeonUserDetails')) {
        print('Caught PigeonUserDetails type cast error - this is likely due to a compatibility issue with the sign_in_with_apple plugin');
        // Return null to indicate sign-in failed, but don't throw an exception
        return null;
      }
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Clear auth cache
  Future<void> clearAuthCache() async {
    print('Clearing auth cache');
    _cachedEmail = null;
    
    try {
      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_email');
      
      // Clear API service token cache
      await _apiService.clearTokenCache();
    } catch (e) {
      print('Error clearing auth cache: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('Starting sign out process...');
      
      // Get email before logout for FCM token unregistration
      final email = _apiService.getCachedCustomerEmail();
      print('Email before logout: $email');
      
      // Get the FCM token before signing out
      try {
        final notificationService = NotificationService();
        await notificationService.unregisterDeviceToken();
      } catch (e) {
        print('Error unregistering device token: $e');
        // Continue with logout even if token unregistration fails
      }
      
      // Clear all API caches first
      await _apiService.clearAllCache();
      await _apiService.clearCustomerCache();
      await _apiService.clearOrdersCache();
      
      // Clear any cached tokens
      await _apiService.clearCachedFirebaseToken();
      
      // Also clear token cache using our new method
      await _apiService.clearTokenCache();
      
      // Sign out from Google if signed in with Google
      await _googleSignIn.signOut();
      
      // Sign out from Firebase
      await _auth.signOut();

      // Clear any stored preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear cart data
      await _cartService.clearCart();
      
      // Clear secure storage
      final secureStorage = const FlutterSecureStorage();
      await secureStorage.deleteAll();
      
      print('Successfully logged out and cleared all user data');
      notifyListeners();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user profile from backend
  Future<Map<String, dynamic>> getUserProfile() async {
    final customerDetails = await _apiService.getCurrentCustomer();
    return customerDetails.toJson();
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final customerDetails = await _apiService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    return customerDetails.toJson();
  }
}
