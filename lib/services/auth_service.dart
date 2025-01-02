import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();
  final CartService _cartService = CartService();

  // Get current user
  User? get currentUser => _auth.currentUser;

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
      
      // Then sync with backend
      final customerData = await _apiService.login(email: email);
      return customerData;
    } catch (e) {
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
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Step 1: Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw ApiException(
          message: 'Google sign in was cancelled',
          statusCode: 401,
        );
      }

      // Step 2: Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw ApiException(
          message: 'Failed to get Google authentication tokens',
          statusCode: 401,
        );
      }

      // Step 3: Firebase auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        throw ApiException(
          message: 'Failed to authenticate with Firebase',
          statusCode: 401,
        );
      }
      
      return googleUser;
    } catch (e) {
      print('Google Sign In Error: $e');
      if (e is FirebaseAuthException) {
        throw ApiException(
          message: e.message ?? 'Google sign-in failed: Firebase Auth Error',
          statusCode: 401,
        );
      } else if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: e.toString(),
        statusCode: 401,
      );
    }
  }

  // Complete Google Sign In process (backend sync)
  Future<Map<String, dynamic>> completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      // Get the Firebase token
      final token = await _auth.currentUser?.getIdToken(true); // Force refresh token
      if (token == null) {
        throw ApiException(
          message: 'No authentication token available',
          statusCode: 401,
        );
      }

      // Sync with backend
      final customerData = await _apiService.socialAuth(
        provider: 'GOOGLE',
        email: googleUser.email,
        firstName: googleUser.displayName?.split(' ').first ?? '',
        lastName: googleUser.displayName?.split(' ').skip(1).join(' '),
        imageUrl: googleUser.photoUrl,
        token: token, // Pass the token to socialAuth
      );
      
      if (customerData is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Invalid response format from server',
          statusCode: 500,
        );
      }

      print('Customer data from backend: $customerData');
      return customerData;
    } catch (e) {
      print('Error syncing with backend after Google Sign In: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'Failed to sync with backend: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  String _createNonce(int length) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> signInWithApple() async {
    throw ApiException(
      message: 'Apple Sign In is currently disabled',
      statusCode: 501,
    );
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear cart first
      await _cartService.clearCart();
      
      // Clear API cache
      await _apiService.clearAllCache();
      
      // Sign out from Firebase
      await _auth.signOut();
      notifyListeners();
      print('Successfully signed out');
    } catch (e) {
      print('Error during sign out: $e');
      // Continue with sign out even if there's an error clearing cache
      try {
        await _auth.signOut();
      } catch (e) {
        print('Error signing out from Firebase: $e');
      }
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
