import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import '../screens/claims_screen.dart';
import '../screens/home_screen.dart';
import '../screens/policy_screen.dart';
import '../screens/wallet_screen.dart';

/// Bottom-navigation shell for the four top-level sections.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.api,
    required this.profiles,
    required this.profile,
    required this.onProfileChanged,
    this.onSignOut,
  });

  final ApiClient api;
  final ProfileApi profiles;
  final WorkerProfile profile;
  final ValueChanged<WorkerProfile> onProfileChanged;
  final VoidCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's state when switching.
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            api: widget.api,
            profiles: widget.profiles,
            profile: widget.profile,
            onProfileChanged: widget.onProfileChanged,
            onSignOut: widget.onSignOut,
          ),
          const PolicyScreen(),
          const ClaimsScreen(),
          const WalletScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Policy',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
        ],
      ),
    );
  }
}
