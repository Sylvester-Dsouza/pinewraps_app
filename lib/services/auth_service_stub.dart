// This is a stub implementation for non-iOS platforms
// It provides empty implementations of the Apple Sign-In functionality

// Mock class to avoid importing the actual package
class SignInWithApple {
  static Future<AppleIDCredential> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    String? nonce,
    WebAuthenticationOptions? webAuthenticationOptions,
  }) async {
    throw UnimplementedError('Apple Sign In is only available on iOS');
  }
}

class AppleIDCredential {
  final String? identityToken;
  final String? givenName;
  final String? familyName;

  AppleIDCredential({this.identityToken, this.givenName, this.familyName});
}

class AppleIDAuthorizationScopes {
  static const email = AppleIDAuthorizationScopes._('email');
  static const fullName = AppleIDAuthorizationScopes._('fullName');

  final String value;
  const AppleIDAuthorizationScopes._(this.value);
}

class WebAuthenticationOptions {
  final String clientId;
  final Uri redirectUri;

  WebAuthenticationOptions({
    required this.clientId,
    required this.redirectUri,
  });
}

class SignInWithAppleException implements Exception {
  final String message;
  SignInWithAppleException(this.message);

  @override
  String toString() => 'SignInWithAppleException: $message';
}
