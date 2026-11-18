import 'package:flutter/material.dart';

import '../../models/candidat.dart';

/// Page d'arrivée du candidat après inscription ou connexion (US1).
///
/// Elle reçoit le candidat connecté. Les fonctionnalités suivantes
/// seront branchées ici :
/// - US2 (Ichan) : liste des tests à passer
/// - US3 (Ichan) : profil et modification des informations
class EspaceCandidatScreen extends StatelessWidget {
  final Candidat candidat;

  const EspaceCandidatScreen({super.key, required this.candidat});

  void _aVenir(BuildContext context, String fonction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fonction : à venir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bonjour ${candidat.prenom} !',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Année scolaire ${candidat.anneeScolaire}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.quiz),
                  label: const Text('Passer un test'),
                  onPressed: () => _aVenir(context, 'Passer un test'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_circle),
                  label: const Text('Mon profil'),
                  onPressed: () => _aVenir(context, 'Mon profil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
