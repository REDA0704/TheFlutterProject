import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/database_service.dart';
import '../../utils/annee_scolaire.dart';
import '../../utils/disciplines.dart';
import 'annees_resultats.dart';

/// US7 : camemberts de réussite par discipline et taux global.
class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});
  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  final _db = DatabaseService.instance;
  String _annee = anneeScolaireActuelle();
  late Future<List<String>> _annees;
  late Future<Map<String, double>> _taux;
  int _nbEtudiants = 0;
  @override
  void initState() {
    super.initState();
    _annees = chargerAnneesResultats();
    _taux = _charger(_annee);
  }

  Future<Map<String, double>> _charger(String annee) async {
    final parDiscipline = await _db.tauxReussiteParDiscipline(annee: annee);
    if (parDiscipline.isEmpty) return {};
    final global = await _db.tauxReussiteGlobal(annee);
    _nbEtudiants = await _db.nombreEtudiantsEvalues(annee);
    return {...parDiscipline, 'Global': global};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Année scolaire'),
          FutureBuilder<List<String>>(
            future: _annees,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(() {
                    _annees = chargerAnneesResultats();
                  }),
                  child: const Text('Années indisponibles. Réessayer'),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return DropdownButton<String>(
                isExpanded: true,
                value: _annee,
                items: [
                  for (final a in snapshot.data!)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (a) {
                  if (a == null) return;
                  setState(() {
                    _annee = a;
                    _taux = _charger(a);
                  });
                },
              );
            },
          ),
          Text(
            'Seuil de réussite : '
            '${(DatabaseService.seuilReussite * 100).toStringAsFixed(0)} %',
          ),
          const Text('Vert : réussi | Rouge : échoué'),
          const Text(
            "Seuls les tests terminés sont comptés. L'année est celle "
            'où le test a été passé.',
          ),
          FutureBuilder<Map<String, double>>(
            future: _taux,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(() {
                    _taux = _charger(_annee);
                  }),
                  child: const Text('Erreur. Réessayer'),
                );
              }
              final taux = snapshot.data!;
              return Column(
                children: [
                  _carte(
                    'Taux général – tous les étudiants',
                    taux['Global'],
                    detail: taux['Global'] == null
                        ? null
                        : '$_nbEtudiants étudiant(s) évalué(s). Un étudiant '
                            "est reçu si l'ensemble de ses tests atteint le "
                            'seuil.',
                  ),
                  for (final d in disciplines) _carte(d, taux[d]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _carte(String titre, double? taux, {String? detail}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: Theme.of(context).textTheme.titleLarge),
            if (taux == null)
              const Text('Aucun résultat pour cette année.')
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 0,
                    sectionsSpace: 0,
                    sections: [
                      if (taux > 0)
                        PieChartSectionData(
                          value: taux,
                          color: Colors.green.shade700,
                          radius: 85,
                          showTitle: false,
                        ),
                      if (taux < 100)
                        PieChartSectionData(
                          value: 100 - taux,
                          color: Colors.red.shade700,
                          radius: 85,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              Text('Réussi : ${taux.toStringAsFixed(1)} %'),
              Text('Échoué : ${(100 - taux).toStringAsFixed(1)} %'),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
