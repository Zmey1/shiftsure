import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import '../widgets/backend_status_card.dart';
import 'profile_screen.dart';
import 'select_store_screen.dart';

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

  Future<void> _chooseStore(BuildContext context) async {
    final updated = await Navigator.of(context).push<WorkerProfile>(
      MaterialPageRoute(
        builder: (_) => SelectStoreScreen(profile: profile, profiles: profiles),
      ),
    );
    if (updated != null) onProfileChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = profile.darkStore;
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
                  if (store != null) ...[
                    const SizedBox(height: 4),
                    Text('${store.name} · Zone: ${store.zoneName}'),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openProfile(context),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('View profile'),
                      ),
                      if (store == null)
                        FilledButton.icon(
                          onPressed: () => _chooseStore(context),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Choose your dark store'),
                        ),
                    ],
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
