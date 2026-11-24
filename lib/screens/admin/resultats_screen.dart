import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/resultat.dart';
import '../../services/database_service.dart';
import 'annees_resultats.dart';

/// US6 : tableau de bord des résultats récents des candidats.
///
/// - affiche les derniers tests passés (le plus récent en premier)
/// - recherche d'un candidat par nom ou prénom
/// - filtre par année scolaire (ou toutes les années)
class ResultatsScreen extends StatefulWidget {
  const ResultatsScreen({super.key});

  /// Nombre maximum de résultats affichés.
  static const int limite = 50;

  @override
  State<ResultatsScreen> createState() => _ResultatsScreenState();
}

class _ResultatsScreenState extends State<ResultatsScreen> {
  final _db = DatabaseService.instance;
  final _recherche = TextEditingController();
  Timer? _attente;

  String? _annee; // null = toutes les années
  late Future<List<String>> _annees;
  late Future<List<Map<String, dynamic>>> _resultats;

  @override
  void initState() {
    super.initState();
    _annees = chargerAnneesResultats();
    _resultats = _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _charger() => _db.getResultatsRecents(
        limite: ResultatsScreen.limite,
        texte: _recherche.text.trim(),
        annee: _annee,
      );

  void _recharger() => setState(() => _resultats = _charger());

  // On attend que l'admin arrête de taper avant d'interroger la base
  void _rechercheModifiee(String _) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 300), _recharger);
  }

  static String _date(String iso) {
    final d = DateTime.parse(iso);
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)}/${d.year} '
        '${deux(d.hour)}:${deux(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _recharger,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _recherche,
              decoration: InputDecoration(
                labelText: 'Rechercher un candidat (nom, prénom ou les deux)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _recherche.clear();
                    _recharger();
                  },
                ),
              ),
              onChanged: _rechercheModifiee,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<List<String>>(
              future: _annees,
              builder: (context, snap) {
                final annees = snap.data ?? const <String>[];
                return DropdownButtonFormField<String?>(
                  initialValue: _annee,
                  decoration: const InputDecoration(
                    labelText: 'Année scolaire',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes les années'),
                    ),
                    for (final a in annees)
                      DropdownMenuItem<String?>(value: a, child: Text(a)),
                  ],
                  onChanged: (a) {
                    _annee = a;
                    _recharger();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _liste()),
        ],
      ),
    );
  }

  Widget _liste() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resultats,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: TextButton(
              onPressed: _recharger,
              child: const Text('Erreur de chargement. Réessayer'),
            ),
          );
        }
        final lignes = snap.data!;
        if (lignes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun résultat ne correspond à ces critères.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: lignes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _tuile(lignes[i]),
        );
      },
    );
  }

  Widget _tuile(Map<String, dynamic> r) {
    final score = r['score'] as int;
    final total = r['total'] as int;
    final taux = total == 0 ? 0.0 : score / total;
    final reussi = taux >= DatabaseService.seuilReussite;
    final enCours = Resultat.fromMap(r).enCours;
    final couleur = enCours
        ? Colors.orange.shade800
        : (reussi ? Colors.green.shade700 : Colors.red.shade700);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: couleur,
        foregroundColor: Colors.white,
        child: Icon(
          enCours
              ? Icons.hourglass_top
              : (reussi ? Icons.check : Icons.close),
        ),
      ),
      title: Text('${r['nom']} ${r['prenom']}'),
      subtitle: Text(
        '${r['discipline']} · ${_date(r['date'] as String)} · '
        '${r['annee_scolaire']}${enCours ? ' · test en cours' : ''}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$score/$total',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${(taux * 100).toStringAsFixed(0)} %',
            style: TextStyle(color: couleur),
          ),
        ],
      ),
    );
  }
}
