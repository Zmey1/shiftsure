import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/placeholder_body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShiftSure')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: BackendStatusCard(api: api),
          ),
          const Expanded(
            child: PlaceholderBody(
              icon: Icons.home_outlined,
              title: 'Home',
              plannedPr: 8,
            ),
          ),
        ],
      ),
    );
  }
}
