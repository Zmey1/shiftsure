import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../navigation/app_shell.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

/// Shows the rider app when signed in, otherwise the login screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.api});

  final AuthService auth;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: auth.authStateChanges(),
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != null) {
          return AppShell(api: api, onSignOut: auth.signOut);
        }
        return LoginScreen(auth: auth);
      },
    );
  }
}
