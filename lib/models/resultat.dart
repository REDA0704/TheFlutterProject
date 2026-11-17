class Resultat {
  final int? id;
  final int candidatId;
  final String discipline;
  final int score;
  final int total;
  final DateTime date;

  Resultat({
    this.id,
    required this.candidatId,
    required this.discipline,
    required this.score,
    required this.total,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'candidat_id': candidatId,
        'discipline': discipline,
        'score': score,
        'total': total,
        'date': date.toIso8601String(),
      };

  factory Resultat.fromMap(Map<String, dynamic> map) => Resultat(
        id: map['id'] as int?,
        candidatId: map['candidat_id'] as int,
        discipline: map['discipline'] as String,
        score: map['score'] as int,
        total: map['total'] as int,
        date: DateTime.parse(map['date'] as String),
      );
}