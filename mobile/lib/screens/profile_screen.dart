import 'package:flutter/material.dart';

import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';
import 'edit_profile_screen.dart';

/// Read-only view of the rider's saved profile, with an Edit action.
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
    setState(() => _profile = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
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
