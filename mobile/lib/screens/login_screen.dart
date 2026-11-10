import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'auth_form.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return AuthForm(
      title: 'Sign in',
      submitLabel: 'Sign in',
      onSubmit: (email, password) =>
          auth.signIn(email: email, password: password),
      switchLabel: 'Create an account',
      onSwitch: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RegisterScreen(auth: auth)),
      ),
    );
  }
}
