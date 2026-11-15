import 'package:flutter/material.dart';

import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import 'edit_profile_screen.dart';
import 'select_store_screen.dart';

/// Read-only view of the rider's saved profile, with Edit and dark-store
/// actions.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.profiles,
    required this.onChanged,
  });

  final WorkerProfile profile;
  final ProfileApi profiles;

  /// Called with the saved profile after a successful edit.
  final ValueChanged<WorkerProfile> onChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late WorkerProfile _profile = widget.profile;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<WorkerProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(profile: _profile, profiles: widget.profiles),
      ),
    );
    if (updated == null || !mounted) return;
    final cleared = _profile.darkStore != null && updated.darkStore == null;
    _apply(updated);
    if (cleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your dark store no longer matches ${updated.platform.label} in ${updated.city}, so '
            'it was removed. Choose a new one.',
          ),
        ),
      );
    }
  }

  Future<void> _chooseStore() async {
    final updated = await Navigator.of(context).push<WorkerProfile>(
      MaterialPageRoute(
        builder: (_) =>
            SelectStoreScreen(profile: _profile, profiles: widget.profiles),
      ),
    );
    if (updated == null || !mounted) return;
    _apply(updated);
  }

  void _apply(WorkerProfile updated) {
    setState(() => _profile = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final store = _profile.darkStore;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        children: [
          _Detail(
            icon: Icons.person_outline,
            label: 'Full name',
            value: _profile.name,
          ),
          _Detail(
            icon: Icons.phone_outlined,
            label: 'Phone number',
            value: _profile.phone,
          ),
          _Detail(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: _profile.city,
          ),
          _Detail(
            icon: Icons.storefront_outlined,
            label: 'Delivery platform',
            value: _profile.platform.label,
          ),
          ListTile(
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: const Text('Dark store'),
            subtitle: Text(
              store == null
                  ? 'Not selected'
                  : '${store.name} · Zone: ${store.zoneName}',
            ),
            trailing: TextButton(
              onPressed: _chooseStore,
              child: Text(store == null ? 'Choose' : 'Change'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
