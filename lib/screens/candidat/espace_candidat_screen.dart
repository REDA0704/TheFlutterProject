import 'package:flutter/material.dart';

import '../../models/candidat.dart';
import 'liste_tests_screen.dart';
import 'profil_screen.dart';

class EspaceCandidatScreen extends StatelessWidget {
  final Candidat candidat;

  const EspaceCandidatScreen({super.key, required this.candidat});

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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListeTestsScreen(candidat: candidat),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_circle),
                  label: const Text('Mon profil'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilScreen(candidat: candidat),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
