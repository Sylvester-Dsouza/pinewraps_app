import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  String generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Starts the Apple Sign In authentication flow
  Future<UserCredential?> signInWithApple() async {
    try {
      // To prevent replay attacks with the credential returned from Apple, we
      // include a nonce in the credential request. When signing in with
      // Firebase, the nonce in the id token returned by Apple, is expected to
      // match the sha256 hash of `rawNonce`.
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint('Apple Sign In successful: ${appleCredential.email}');

      // Create an OAuthCredential from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in the user with Firebase.
      final authResult = await _auth.signInWithCredential(oauthCredential);
      
      // Update the user's display name if it's null (first time sign in)
      final User? user = authResult.user;
      if (user != null && 
          (user.displayName == null || user.displayName!.isEmpty) && 
          (appleCredential.givenName != null || appleCredential.familyName != null)) {
        await user.updateDisplayName(
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim()
        );
      }

      return authResult;
    } catch (error) {
      debugPrint('Error during Apple Sign In: $error');
      return null;
    }
  }
}
