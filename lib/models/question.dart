import 'dart:convert';

enum TypeQuestion { radio, checkbox }

class Question {
  final int? id;
  final String discipline; // "Java", "Algo", "HTML/CSS"
  final String enonce;
  final TypeQuestion type;
  final List<String> options;
  final List<int> bonnesReponses; // indices dans options
  final int tempsLimite; // en secondes

  Question({
    this.id,
    required this.discipline,
    required this.enonce,
    required this.type,
    required this.options,
    required this.bonnesReponses,
    required this.tempsLimite,
  });

  // SQLite ne stocke pas les listes : on les encode en texte JSON
  Map<String, dynamic> toMap() => {
        'id': id,
        'discipline': discipline,
        'enonce': enonce,
        'type': type.name,
        'options': jsonEncode(options),
        'bonnes_reponses': jsonEncode(bonnesReponses),
        'temps_limite': tempsLimite,
      };

  factory Question.fromMap(Map<String, dynamic> map) => Question(
        id: map['id'] as int?,
        discipline: map['discipline'] as String,
        enonce: map['enonce'] as String,
        type: TypeQuestion.values.byName(map['type'] as String),
        options: List<String>.from(jsonDecode(map['options'] as String)),
        bonnesReponses:
            List<int>.from(jsonDecode(map['bonnes_reponses'] as String)),
        tempsLimite: map['temps_limite'] as int,
      );
}