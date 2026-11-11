/// The signed-in rider as the UI needs to see them.
class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// A sign-in or registration failure with a message safe to show the rider.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Email/password authentication. The real implementation is
/// `FirebaseAuthService`; widget tests use a fake.
///
/// Nothing here sets roles or custom claims: those are assigned server-side.
abstract class AuthService {
  /// The signed-in user now, or null.
  AuthUser? get currentUser;

  /// Emits on sign-in and sign-out. Firebase restores a persisted session
  /// shortly after startup.
  Stream<AuthUser?> authStateChanges();

  /// Throws [AuthFailure] on failure.
  Future<void> signUp({required String email, required String password});

  /// Throws [AuthFailure] on failure.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// A valid Firebase ID token, or null when signed out. Usable as
  /// `ApiClient.tokenProvider`.
  ///
  /// The SDK caches the token for up to an hour. Pass [forceRefresh] after
  /// the backend changes this user's custom claims (e.g. assigns the rider
  /// role) so the next request carries them.
  Future<String?> getIdToken({bool forceRefresh = false});
}
