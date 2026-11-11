import 'package:flutter/material.dart';

import '../profile/worker_profile.dart';
import 'profile_form.dart';

/// First-run profile setup, shown by the profile gate until the backend has a
/// profile for the signed-in rider.
class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key, required this.onSubmit, this.onSignOut});

  /// Saves the profile; throws `ApiException` on failure.
  final Future<void> Function(ProfileInput input) onSubmit;

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: onSignOut,
            ),
        ],
      ),
      body: ProfileFormBody(
        children: [
          Text(
            'Tell us a little about how you deliver. You can change this '
            'later.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ProfileForm(submitLabel: 'Save profile', onSubmit: onSubmit),
        ],
      ),
    );
  }
}
