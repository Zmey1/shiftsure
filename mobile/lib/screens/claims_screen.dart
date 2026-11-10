import 'package:flutter/material.dart';

import '../widgets/placeholder_body.dart';

class ClaimsScreen extends StatelessWidget {
  const ClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claims')),
      body: const PlaceholderBody(
        icon: Icons.assignment_outlined,
        title: 'Claims',
        plannedPr: 14,
      ),
    );
  }
}
