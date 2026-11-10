import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email.';
  if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address.';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter your password.';
  if (value.length < 6) return 'Use at least 6 characters.';
  return null;
}

/// Shared email/password form for the login and registration screens.
class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.switchLabel,
    required this.onSwitch,
    this.confirmPassword = false,
  });

  final String title;
  final String submitLabel;
  final bool confirmPassword;

  /// Throws [AuthFailure] to show a message under the form.
  final Future<void> Function(String email, String password) onSubmit;

  final String switchLabel;
  final VoidCallback onSwitch;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_email.text.trim(), _password.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: validatePassword,
                    ),
                    if (widget.confirmPassword) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('confirm'),
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (v) =>
                            v == _password.text ? null : 'Passwords differ.',
                      ),
                    ],
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
                    TextButton(
                      onPressed: _busy ? null : widget.onSwitch,
                      child: Text(widget.switchLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
