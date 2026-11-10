import 'package:flutter_test/flutter_test.dart';
import 'package:shiftsure_rider/auth/firebase_auth_service.dart';

void main() {
  test('wrong password and unknown email give the same message', () {
    final m = authErrorMessage('invalid-credential');
    expect(authErrorMessage('wrong-password'), m);
    expect(authErrorMessage('user-not-found'), m);
  });

  test('known codes are readable, unknown codes fall back', () {
    expect(
      authErrorMessage('email-already-in-use'),
      contains('already exists'),
    );
    expect(authErrorMessage('weak-password'), contains('stronger'));
    expect(authErrorMessage('network-request-failed'), contains('connection'));
    expect(authErrorMessage('something-new'), contains('try again'));
  });
}
