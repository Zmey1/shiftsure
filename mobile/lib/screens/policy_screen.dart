import 'package:flutter/material.dart';

import '../widgets/placeholder_body.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policy')),
      body: const PlaceholderBody(
        icon: Icons.shield_outlined,
        title: 'Policy',
        plannedPr: 11,
      ),
    );
  }
}
