import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'auth_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return AuthForm(
      title: 'Create account',
      submitLabel: 'Create account',
      confirmPassword: true,
      onSubmit: (email, password) async {
        // Capture before the await; the gate replaces this route on success.
        final navigator = Navigator.of(context);
        await auth.signUp(email: email, password: password);
        // Signing up also signs in; return to the root so the gate can show
        // the rider app.
        navigator.popUntil((route) => route.isFirst);
      },
      switchLabel: 'I already have an account',
      onSwitch: () => Navigator.of(context).pop(),
    );
  }
}
