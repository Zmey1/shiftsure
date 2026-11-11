import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../profile/profile_api.dart';
import '../profile/profile_gate.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

/// Shows the login screen when signed out. When signed in, the profile gate
/// decides between profile setup and the rider app.
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
        final user = snapshot.data;
        if (user != null) {
          return ProfileGate(
            // A new uid gets a fresh gate (and a fresh profile fetch).
            key: ValueKey(user.uid),
            profiles: ProfileApi(api: api, auth: auth),
            onSignOut: auth.signOut,
          );
        }
        return LoginScreen(auth: auth);
      },
    );
  }
}
