import '../utils/annee_scolaire.dart' as annee_scolaire;

/// Résultat d'un candidat à un test (une ligne par discipline passée).
class Resultat {
  final int? id;
  final int candidatId;
  final String discipline;
  final int score;
  final int total;

  /// Début du test.
  final DateTime date;

  /// false tant que le candidat n'a pas fini (ou abandonné) le test.
  final bool termine;

  /// Heure après laquelle un test non terminé est considéré comme
  /// interrompu (appli fermée, téléphone éteint…) et compté tel quel.
  final DateTime dateLimite;

  Resultat({
    this.id,
    required this.candidatId,
    required this.discipline,
    required this.score,
    required this.total,
    required this.date,
    this.termine = true,
    DateTime? dateLimite,
  }) : dateLimite = dateLimite ?? date;

  /// Année scolaire du test (et non de l'inscription du candidat) :
  /// c'est elle qui sert aux filtres et aux statistiques (US6, US7).
  String get anneeScolaire => annee_scolaire.anneeScolaire(date);

  /// Test en train d'être passé en ce moment.
  bool get enCours => !termine && DateTime.now().isBefore(dateLimite);

  Map<String, dynamic> toMap() => {
        'id': id,
        'candidat_id': candidatId,
        'discipline': discipline,
        'score': score,
        'total': total,
        'date': date.toIso8601String(),
        'annee_scolaire': anneeScolaire,
        'termine': termine ? 1 : 0,
        'date_limite': dateLimite.toIso8601String(),
      };

  factory Resultat.fromMap(Map<String, dynamic> map) => Resultat(
        id: map['id'] as int?,
        candidatId: map['candidat_id'] as int,
        discipline: map['discipline'] as String,
        score: map['score'] as int,
        total: map['total'] as int,
        date: DateTime.parse(map['date'] as String),
        termine: (map['termine'] as int? ?? 1) == 1,
        dateLimite: map['date_limite'] == null
            ? null
            : DateTime.parse(map['date_limite'] as String),
      );
}
