import 'dart:async';

import 'package:shiftsure_rider/auth/auth_service.dart';

/// In-memory [AuthService] for tests. Set [failure] to make the next
/// sign-in/sign-up throw it.
class FakeAuthService implements AuthService {
  FakeAuthService({this._user});

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthFailure? failure;

  /// uid given to the next user who signs in or up.
  String nextUid = 'uid-1';
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
    _user = AuthUser(uid: nextUid, email: email);
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

  /// Number of forced refreshes; the token becomes `token-<n+1>` after each.
  int refreshes = 0;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_user == null) return null;
    if (forceRefresh) {
      refreshes++;
      calls.add('refreshToken');
    }
    return 'token-${refreshes + 1}';
  }
}
