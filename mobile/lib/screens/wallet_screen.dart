import 'package:flutter/material.dart';

import '../widgets/placeholder_body.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: const PlaceholderBody(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Wallet',
        plannedPr: 14,
      ),
    );
  }
}
