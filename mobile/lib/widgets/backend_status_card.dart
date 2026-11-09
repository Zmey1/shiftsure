import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Development diagnostic, not a rider feature: checks `GET /health` once on
/// load and again only when the user taps Retry. No polling.
class BackendStatusCard extends StatefulWidget {
  const BackendStatusCard({super.key, required this.api});

  final ApiClient api;

  @override
  State<BackendStatusCard> createState() => _BackendStatusCardState();
}

class _BackendStatusCardState extends State<BackendStatusCard> {
  late Future<Map<String, dynamic>> _health = widget.api.getJson('/health');

  void _retry() {
    setState(() {
      _health = widget.api.getJson('/health');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _health,
          builder: (context, snapshot) {
            final theme = Theme.of(context);
            final String status;
            final Widget icon;
            if (snapshot.connectionState != ConnectionState.done) {
              status = 'Checking…';
              icon = const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            } else if (snapshot.hasError) {
              final error = snapshot.error;
              status = error is ApiException
                  ? error.message
                  : 'Unexpected error.';
              icon = Icon(Icons.error_outline, color: theme.colorScheme.error);
            } else {
              status = 'Backend reachable';
              icon = const Icon(Icons.check_circle_outline);
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend connection (dev diagnostic)',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(status),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.done)
                  TextButton(onPressed: _retry, child: const Text('Retry')),
              ],
            );
          },
        ),
      ),
    );
  }
}
