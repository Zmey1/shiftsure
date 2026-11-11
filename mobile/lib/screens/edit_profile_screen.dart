import 'package:flutter/material.dart';

import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import 'profile_form.dart';

/// Edits the rider's profile. Pops with the updated [WorkerProfile] on save,
/// or with nothing if the rider backs out.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.profiles,
  });

  final WorkerProfile profile;
  final ProfileApi profiles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ProfileFormBody(
        children: [
          ProfileForm(
            initial: profile,
            submitLabel: 'Save changes',
            onSubmit: (input) async {
              final navigator = Navigator.of(context);
              final changes = input.changesFrom(profile);
              // Nothing changed: no request needed.
              final updated = changes.isEmpty
                  ? profile
                  : await profiles.update(changes);
              navigator.pop(updated);
            },
          ),
        ],
      ),
    );
  }
}
