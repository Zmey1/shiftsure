import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../profile/profile_validators.dart';
import '../profile/worker_profile.dart';

/// Shared name / phone / city / platform form for profile setup and editing.
/// Validates before submitting and ignores taps while a save is in flight.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
  });

  final String submitLabel;

  /// Prefills the fields when editing.
  final WorkerProfile? initial;

  /// Throws [ApiException] to show a message under the form.
  final Future<void> Function(ProfileInput input) onSubmit;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _city = TextEditingController(text: widget.initial?.city);
  late DeliveryPlatform? _platform = widget.initial?.platform;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        ProfileInput(
          name: normalizeText(_name.text),
          phone: normalizePhone(_phone.text),
          city: normalizeText(_city.text),
          platform: _platform!,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _messageFor(ApiException e) {
    if (e.code == 'validation_failed') {
      return 'Some details were not accepted. Check them and try again.';
    }
    if (e.kind == ApiErrorKind.http) {
      return 'Could not save your profile (${e.statusCode}). Try again.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('profile-name'),
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: validateName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('profile-phone'),
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '10-digit mobile number',
            ),
            validator: validatePhone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('profile-city'),
            controller: _city,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'City'),
            validator: validateCity,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeliveryPlatform>(
            key: const Key('profile-platform'),
            initialValue: _platform,
            decoration: const InputDecoration(labelText: 'Delivery platform'),
            items: [
              for (final p in DeliveryPlatform.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: _busy ? null : (p) => setState(() => _platform = p),
            validator: (p) => p == null ? 'Choose your platform.' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// Centered, width-limited scrolling body used by the profile screens.
class ProfileFormBody extends StatelessWidget {
  const ProfileFormBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
