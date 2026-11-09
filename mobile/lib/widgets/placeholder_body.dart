import 'package:flutter/material.dart';

/// Body for a screen that is not built yet. Makes clear nothing here works.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({
    super.key,
    required this.icon,
    required this.title,
    required this.plannedPr,
  });

  final IconData icon;
  final String title;

  /// Roadmap PR that will implement this screen.
  final int plannedPr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Chip(label: Text('Placeholder · planned for PR #$plannedPr')),
        ],
      ),
    );
  }
}
