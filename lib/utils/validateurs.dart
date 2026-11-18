/// Fonctions de validation des formulaires (US1 et US5).
///
/// Chaque fonction renvoie `null` si la valeur est correcte,
/// sinon le message d'erreur à afficher sous le champ.
/// Elles s'utilisent directement dans `TextFormField(validator: ...)`.
library;

final RegExp _regexEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$');

// Lettres (accents compris), espaces, tirets et apostrophes
final RegExp _regexNom = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");

const int ageMin = 15;
const int ageMax = 99;

String? validerObligatoire(String? valeur, {String champ = 'Ce champ'}) {
  if (valeur == null || valeur.trim().isEmpty) {
    return '$champ est obligatoire.';
  }
  return null;
}

String? validerNom(String? valeur, {String champ = 'Le nom'}) {
  final erreur = validerObligatoire(valeur, champ: champ);
  if (erreur != null) return erreur;
  final v = valeur!.trim();
  if (v.length < 2) return '$champ doit contenir au moins 2 caractères.';
  if (!_regexNom.hasMatch(v)) {
    return '$champ ne doit contenir que des lettres.';
  }
  return null;
}

String? validerEmail(String? valeur) {
  final erreur = validerObligatoire(valeur, champ: 'L\'email');
  if (erreur != null) return erreur;
  if (!_regexEmail.hasMatch(valeur!.trim())) {
    return 'Adresse email invalide (ex : prenom.nom@mail.com).';
  }
  return null;
}

String? validerAge(String? valeur) {
  final erreur = validerObligatoire(valeur, champ: 'L\'âge');
  if (erreur != null) return erreur;
  final age = int.tryParse(valeur!.trim());
  if (age == null) return 'L\'âge doit être un nombre.';
  if (age < ageMin || age > ageMax) {
    return 'L\'âge doit être compris entre $ageMin et $ageMax ans.';
  }
  return null;
}

String? validerAdresse(String? valeur) {
  final erreur = validerObligatoire(valeur, champ: 'L\'adresse postale');
  if (erreur != null) return erreur;
  if (valeur!.trim().length < 5) return 'Adresse postale trop courte.';
  return null;
}

/// Met les données au même format avant de les enregistrer ou de les comparer.
/// Ainsi « dupont » et « DUPONT » sont bien considérés comme le même nom
/// et la contrainte UNIQUE (nom, email) fonctionne correctement.
String normaliserNom(String nom) => nom.trim().toUpperCase();
String normaliserPrenom(String prenom) {
  final p = prenom.trim();
  if (p.isEmpty) return p;
  return p[0].toUpperCase() + p.substring(1);
}

String normaliserEmail(String email) => email.trim().toLowerCase();
