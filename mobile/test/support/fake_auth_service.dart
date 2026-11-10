import 'dart:async';

import 'package:shiftsure_rider/auth/auth_service.dart';

/// In-memory [AuthService] for tests. Set [failure] to make the next
/// sign-in/sign-up throw it.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? user}) : _user = user;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthFailure? failure;
  Completer<void>? gate; // when set, sign-in/up wait on it
  final calls = <String>[];

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.multi((sink) {
    // Like Firebase, emit the current state first, then changes.
    sink.add(_user);
    final sub = _controller.stream.listen(sink.add);
    sink.onCancel = sub.cancel;
  });

  Future<void> _auth(String kind, String email) async {
    calls.add('$kind:$email');
    await gate?.future;
    if (failure != null) throw failure!;
    _user = AuthUser(uid: 'uid-1', email: email);
    _controller.add(_user);
  }

  @override
  Future<void> signUp({required String email, required String password}) =>
      _auth('signUp', email);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _auth('signIn', email);

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _user = null;
    _controller.add(null);
  }

  @override
  Future<String?> getIdToken() async => _user == null ? null : 'token-1';
}
