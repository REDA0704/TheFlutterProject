enum Motivation {
  poursuiteEtudes('Poursuite d\'études'),
  reorientation('Réorientation'),
  reconversionPro('Reconversion');

  final String label;
  const Motivation(this.label);
}

class Candidat {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final int age;
  final String adresse;
  final Motivation motivation;
  final String anneeScolaire; // ex : "2025-2026", sert aux filtres du tableau de bord

  Candidat({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.age,
    required this.adresse,
    required this.motivation,
    required this.anneeScolaire,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'age': age,
        'adresse': adresse,
        'motivation': motivation.name,
        'annee_scolaire': anneeScolaire,
      };

  factory Candidat.fromMap(Map<String, dynamic> map) => Candidat(
        id: map['id'] as int?,
        nom: map['nom'] as String,
        prenom: map['prenom'] as String,
        email: map['email'] as String,
        age: map['age'] as int,
        adresse: map['adresse'] as String,
        motivation: Motivation.values.byName(map['motivation'] as String),
        anneeScolaire: map['annee_scolaire'] as String,
      );
}