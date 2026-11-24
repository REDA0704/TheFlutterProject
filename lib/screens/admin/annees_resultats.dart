import '../../services/database_service.dart';
import '../../utils/annee_scolaire.dart';

/// Années disponibles dans la base, plus l'année scolaire actuelle.
Future<List<String>> chargerAnneesResultats() async {
  final candidats = await DatabaseService.instance.rechercherCandidats();
  final annees = {
    anneeScolaireActuelle(),
    for (final c in candidats) c.anneeScolaire,
  }.toList();
  annees.sort((a, b) => b.compareTo(a));
  return annees;
}
