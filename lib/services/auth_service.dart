import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  Future<Map<String, dynamic>> signInWithEmailPassword(String email, String password) async {
    try {
      // First authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Force a reload of the user to ensure we have the latest data
      await userCredential.user?.reload();
      
      // Get the current user
      final user = _auth.currentUser;
      if (user == null) {
        throw ApiException(
          message: 'Authentication failed - no user found',
          statusCode: 401,
        );
      }

      // Get a fresh ID token
      final token = await user.getIdToken(true);
      if (token == null) {
        throw ApiException(
          message: 'Failed to get authentication token',
          statusCode: 401,
        );
      }
      
      // Then sync with backend using the token
      final customerData = await _apiService.login(
        email: email,
        token: token,
      );
      
      // Notify listeners of auth state change
      notifyListeners();
      
      // Register device token for push notifications
      print('Starting FCM token registration after sign-in...');
      await _notificationService.registerDeviceTokenAsync(email: email);
      
      return customerData;
    } catch (e) {
      print('Login Error: $e');
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Authentication failed',
          statusCode: 401,
        );
      }
      rethrow;
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
      // First create Firebase account
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update the user's display name first
      await userCredential.user?.updateDisplayName('$firstName $lastName');

      // Force a reload of the user to ensure we have the latest data
      await userCredential.user?.reload();

      // Get the current user after reload
      final user = _auth.currentUser;
      if (user == null) {
        throw ApiException(
          message: 'Failed to create user account',
          statusCode: 401,
        );
      }

      // Get a fresh ID token
      final token = await user.getIdToken(true);
      if (token == null) {
        throw ApiException(
          message: 'Failed to get authentication token',
          statusCode: 401,
        );
      }
      
      try {
        // Then register with backend using the token
        final customerData = await _apiService.register(
          email: email,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          token: token,
        );
        
        // Register device token for push notifications before signing out
        print('Starting FCM token registration after registration...');
        await _notificationService.registerDeviceTokenAsync(email: email);
        
        // Sign out after successful registration
        await signOut();
        
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
      await userCredential?.user?.delete();
      
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

  // Sign out
  Future<void> signOut() async {
    try {
      print('Signing out...');
      
      // Clear FCM token from backend
      try {
        final user = _auth.currentUser;
        if (user != null && user.email != null) {
          print('Unregistering FCM token for ${user.email}');
          await _notificationService.unregisterDeviceToken();
        }
      } catch (e) {
        print('Error unregistering FCM token: $e');
        // Continue with sign out even if clearing token fails
      }
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Clear cart
      _cartService.clearCart();
      
      // Clear cached token
      await _apiService.clearCachedFirebaseToken();
      
      // Notify listeners
      notifyListeners();
      
      print('Sign out complete');
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
