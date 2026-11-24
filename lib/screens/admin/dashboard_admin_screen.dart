import 'package:flutter/material.dart';

import 'questions/gestion_questions_screen.dart';
import 'resultats_screen.dart';
import 'statistiques_screen.dart';

/// US4 : page d'accueil de l'administrateur après connexion.
/// Donne accès aux questions (US5), au tableau de bord (US6)
/// et aux statistiques (US7).
class DashboardAdminScreen extends StatelessWidget {
  const DashboardAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace administrateur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            // Retour à l'écran d'accueil
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Connecté en tant qu\'administrateur'),
              const SizedBox(height: 24),
              // US5 – gestion des questions
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Gérer les questions'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GestionQuestionsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text('Tableau de bord'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResultatsScreen()),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.pie_chart),
                label: const Text('Statistiques'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatistiquesScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
