import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../profile/dark_store.dart';
import '../profile/profile_api.dart';
import '../profile/worker_profile.dart';

/// Lets the rider pick their dark store from the backend's demo catalog.
///
/// The list comes from the backend, filtered by the saved platform and city;
/// the backend re-validates the choice and resolves the zone. Pops with the
/// updated [WorkerProfile] once a store is saved, or with nothing on back.
class SelectStoreScreen extends StatefulWidget {
  const SelectStoreScreen({
    super.key,
    required this.profile,
    required this.profiles,
  });

  final WorkerProfile profile;
  final ProfileApi profiles;

  @override
  State<SelectStoreScreen> createState() => _SelectStoreScreenState();
}

class _SelectStoreScreenState extends State<SelectStoreScreen> {
  DarkStoreListing? _listing;
  String? _loadError;
  String? _saveError;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _listing = null;
      _loadError = null;
    });
    try {
      final listing = await widget.profiles.fetchStoreOptions();
      if (!mounted) return;
      setState(() => _listing = listing);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _loadError = e.kind == ApiErrorKind.http
            ? 'Could not load dark stores (${e.statusCode}).'
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load dark stores.');
    }
  }

  Future<void> _choose(DarkStoreSummary store) async {
    if (_savingId != null) return;
    setState(() {
      _savingId = store.id;
      _saveError = null;
    });
    try {
      final updated = await widget.profiles.assignDarkStore(store.id);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      final rejected = const {
        'store_not_found',
        'store_unavailable',
        'store_mismatch',
      }.contains(e.code);
      setState(() {
        _savingId = null;
        _saveError = _assignmentError(e, store);
      });
      // The catalog or the profile changed under us: show the current list.
      if (rejected) await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _saveError = 'Could not save your dark store. Try again.';
      });
    }
  }

  String _assignmentError(ApiException e, DarkStoreSummary store) {
    final listing = _listing;
    final platform = (listing?.platform ?? widget.profile.platform).label;
    final city = listing?.city ?? widget.profile.city;
    switch (e.code) {
      case 'store_not_found':
        return '${store.name} is no longer in the catalog. Choose another store.';
      case 'store_unavailable':
        return '${store.name} is not available right now. Choose another store.';
      case 'store_mismatch':
        return '${store.name} does not serve $platform in $city. '
            'Choose another store.';
    }
    return e.kind == ApiErrorKind.http
        ? 'Could not save your dark store (${e.statusCode}).'
        : e.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your dark store')),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadError != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        message: _loadError!,
        action: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    final listing = _listing;
    if (listing == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (listing.stores.isEmpty) {
      return _Message(
        icon: Icons.storefront_outlined,
        message: emptyStoresMessage(listing),
      );
    }
    return ListView(
      children: [
        if (listing.demo) const _DemoBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Stores for ${listing.platform.label} in ${listing.city}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _saveError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        for (final store in listing.stores)
          ListTile(
            key: Key('store-${store.id}'),
            leading: const Icon(Icons.storefront_outlined),
            title: Text(store.name),
            subtitle: Text('Zone: ${store.zoneName}'),
            trailing: _savingId == store.id
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : widget.profile.darkStore?.id == store.id
                ? const Icon(Icons.check)
                : null,
            enabled: _savingId == null,
            onTap: () => _choose(store),
          ),
      ],
    );
  }
}

/// Explains an empty store list using the rider's own platform and city and
/// the cities the catalog does cover.
String emptyStoresMessage(DarkStoreListing listing) {
  final platform = listing.platform.label;
  final cities = listing.availableCities;
  final none =
      'There are no demo dark stores for $platform in ${listing.city}.';
  if (cities.isEmpty) {
    return '$none The demo catalog has no $platform stores in any city. '
        'Edit your profile to change your platform.';
  }
  return '$none Demo $platform stores are available in: ${cities.join(', ')}. '
      'Edit your profile to change your city.';
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.tertiaryContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demonstration data: these stores and zones are fictional and '
              'are not real delivery locations.',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
