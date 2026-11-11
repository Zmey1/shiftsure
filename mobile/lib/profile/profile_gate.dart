import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../navigation/app_shell.dart';
import '../screens/profile_setup_screen.dart';
import 'profile_api.dart';
import 'worker_profile.dart';

/// Shown for a signed-in user. Asks the backend for the rider's profile and
/// shows profile setup until one exists, then the app shell.
///
/// The backend is asked every time this gate is created (each sign-in or app
/// start), so interrupted onboarding resumes at setup and later logins go
/// straight to the shell. Create it with a key per uid so a different user
/// never sees a previous user's state.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.profiles, this.onSignOut});

  final ProfileApi profiles;
  final VoidCallback? onSignOut;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

enum _Status { loading, error, missing, ready }

class _ProfileGateState extends State<ProfileGate> {
  _Status _status = _Status.loading;
  WorkerProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = _Status.loading;
      _error = null;
    });
    try {
      final profile = await widget.profiles.fetchMine();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _status = profile == null ? _Status.missing : _Status.ready;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = e.kind == ApiErrorKind.http
            ? 'Could not load your profile (${e.statusCode}).'
            : e.message;
      });
    } catch (_) {
      // e.g. the token provider failed; never leave the spinner up.
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = 'Could not load your profile.';
      });
    }
  }

  Future<void> _create(ProfileInput input) async {
    final profile = await widget.profiles.create(input);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _status = _Status.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _Status.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Status.error:
        return _LoadError(
          message: _error!,
          onRetry: _load,
          onSignOut: widget.onSignOut,
        );
      case _Status.missing:
        return ProfileSetupScreen(
          onSubmit: _create,
          onSignOut: widget.onSignOut,
        );
      case _Status.ready:
        return AppShell(
          api: widget.profiles.api,
          profiles: widget.profiles,
          profile: _profile!,
          onProfileChanged: (p) => setState(() => _profile = p),
          onSignOut: widget.onSignOut,
        );
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
                if (onSignOut != null)
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
