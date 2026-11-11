import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import '../widgets/backend_status_card.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
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

  /// Shows a sign-out button in the app bar when set.
  final VoidCallback? onSignOut;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          profile: profile,
          profiles: profiles,
          onChanged: onProfileChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShiftSure'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => _openProfile(context),
          ),
          if (onSignOut != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: onSignOut,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${profile.name}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('${profile.platform.label} · ${profile.city}'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openProfile(context),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('View profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BackendStatusCard(api: api),
        ],
      ),
    );
  }
}
