import 'package:the_flutter_project/models/candidat.dart';
import 'package:the_flutter_project/models/resultat.dart';
import 'package:the_flutter_project/services/database_service.dart';

/// Données fictives réservées aux tests et à l'émulateur de démonstration.
Future<void> insererDemoResultats() async {
  final db = DatabaseService.instance;
  final ids = <String, int>{};
  Future<void> ajouter(
    String nom,
    String prenom,
    String annee,
    String discipline,
    int score,
    DateTime date,
  ) async {
    final email = '${nom.toLowerCase()}@example.test';
    final id =
        ids[nom] ??
        await db.insertCandidat(
          Candidat(
            nom: nom,
            prenom: prenom,
            email: email,
            age: 20,
            adresse: '10 rue Démo',
            motivation: Motivation.poursuiteEtudes,
            anneeScolaire: annee,
          ),
          motDePasse: 'demo1234',
        );
    ids[nom] = id;
    if (!await db.aDejaPasseTest(id, discipline)) {
      await db.insertResultat(
        Resultat(
          candidatId: id,
          discipline: discipline,
          score: score,
          total: 10,
          date: date,
        ),
      );
    }
  }

  await ajouter(
    'DEMOALPHA',
    'Lucas',
    '2026-2027',
    'Java',
    8,
    DateTime(2026, 11, 24),
  );
  await ajouter(
    'DEMOALPHA',
    'Lucas',
    '2026-2027',
    'Algo',
    3,
    DateTime(2026, 11, 23),
  );
  await ajouter(
    'DEMOBETA',
    'Sarah',
    '2026-2027',
    'Java',
    5,
    DateTime(2026, 11, 22),
  );
  await ajouter(
    'DEMOGAMMA',
    'Emma',
    '2026-2027',
    'HTML/CSS',
    9,
    DateTime(2026, 11, 21),
  );
  await ajouter(
    'DEMODELTA',
    'Adam',
    '2025-2026',
    'Java',
    4,
    DateTime(2026, 6, 15),
  );
  await ajouter(
    'DEMOEPSILON',
    'Lina',
    '2025-2026',
    'Algo',
    7,
    DateTime(2026, 6, 10),
  );
}
