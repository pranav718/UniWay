import 'package:google_sign_in/google_sign_in.dart';

import '../constants/api_constants.dart';

/// Thrown when Google Sign-In cannot produce an ID token for a reason the user could act on
/// (misconfigured build) or note (transient failure). User cancellations are not errors.
class GoogleSignInUnavailable implements Exception {
  final String message;

  const GoogleSignInUnavailable(this.message);

  @override
  String toString() => message;
}

/// Source of an ID token minted for the UniWay server OAuth client.
abstract class GoogleIdentityProvider {
  /// Returns the ID token, or null when the user closed the Google sheet. Throws
  /// [GoogleSignInUnavailable] when the build is misconfigured or the flow fails.
  Future<String?> getIdToken();

  Future<void> signOut();
}

/// Thin wrapper over the google_sign_in v7 API:
/// `initialize()` exactly once, then `authenticate()` and read `account.authentication.idToken`.
class GoogleSignInService implements GoogleIdentityProvider {
  static final GoogleSignInService _shared = GoogleSignInService._();

  factory GoogleSignInService() => _shared;

  GoogleSignInService._() : _signIn = GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  /// Call once at app startup so the first interactive sign-in is not slowed by
  /// configuration loading. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const clientId = ApiConstants.googleServerClientId;
    // serverClientId is what the ID token's aud must match for the backend check to pass.
    await _signIn.initialize(serverClientId: clientId.isEmpty ? null : clientId);
    _initialized = true;
  }

  @override
  Future<String?> getIdToken() async {
    await ensureInitialized();

    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        // authenticate() succeeded but no audience-scoped token was issued.
        throw const GoogleSignInUnavailable(
          'Google did not issue a sign-in token. Check the server client ID in docs/auth-setup.md.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          // The user closed the Google sheet or the flow was paused — not an error.
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const GoogleSignInUnavailable(
            'Google Sign-In is not configured for this build. See docs/auth-setup.md.',
          );
        default:
          throw const GoogleSignInUnavailable('Google sign-in failed. Please try again.');
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _signIn.signOut();
  }
}
