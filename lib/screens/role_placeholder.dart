// role_placeholder.dart — shown for roles whose phone screens aren't built yet.
import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

const _roleLabels = {
  'manager': 'Manager',
  'office': 'Office',
  'driver': 'Delivery driver',
  'client': 'Client',
};

class RolePlaceholder extends StatelessWidget {
  final String role;
  const RolePlaceholder({required this.role, super.key});

  @override
  Widget build(BuildContext context) {
    final label = _roleLabels[role] ?? role;
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => appState.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 60, color: kMuted),
              const SizedBox(height: 16),
              Text('The $label app is coming soon.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: kInk)),
              const SizedBox(height: 8),
              const Text('The warehouse worker screens are ready first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
