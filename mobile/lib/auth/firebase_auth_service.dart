import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// [AuthService] backed by Firebase Authentication.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static AuthUser? _map(User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _run(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(
        () =>
            _auth.signInWithEmailAndPassword(email: email, password: password),
      );

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> getIdToken() async => _auth.currentUser?.getIdToken();

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}

/// Maps a Firebase Auth error code to a readable message. Wrong password and
/// unknown email share one message so the app does not reveal which accounts
/// exist.
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'weak-password':
      return 'Choose a stronger password (at least 6 characters).';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Could not reach the sign-in service. Check your connection.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
