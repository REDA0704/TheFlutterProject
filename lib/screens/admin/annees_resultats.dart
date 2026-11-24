import '../../services/database_service.dart';
import '../../utils/annee_scolaire.dart';

/// Années scolaires où des tests ont été passés, plus l'année actuelle,
/// de la plus récente à la plus ancienne (filtres US6 et US7).
Future<List<String>> chargerAnneesResultats() async {
  final annees = {
    anneeScolaireActuelle(),
    ...await DatabaseService.instance.anneesAvecResultats(),
  }.toList();
  annees.sort((a, b) => b.compareTo(a));
  return annees;
}
