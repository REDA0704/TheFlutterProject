import 'dart:convert';

import '../models/question.dart';

/// US5 – Règles d'une question valide et import / export JSON.
///
/// Format JSON attendu (voir docs/exemple_questions.json) :
/// ```json
/// {
///   "discipline": "Java",
///   "questions": [
///     {
///       "enonce": "Quel mot-clé crée un objet ?",
///       "type": "radio",
///       "options": ["new", "create", "make"],
///       "bonnes_reponses": [0],
///       "temps_limite": 30
///     }
///   ]
/// }
/// ```
/// `bonnes_reponses` contient les positions (à partir de 0) des bonnes
/// réponses dans `options`. Une simple liste de questions (sans l'objet
/// englobant) est aussi acceptée.

const int nbOptionsMin = 2;
const int nbOptionsMax = 6;
const int tempsLimiteMin = 5; // secondes
const int tempsLimiteMax = 600; // 10 minutes

/// Vérifie qu'une question respecte les règles de l'US5.
/// Renvoie null si elle est valide, sinon le message d'erreur.
String? erreurQuestion({
  required String enonce,
  required TypeQuestion type,
  required List<String> options,
  required List<int> bonnesReponses,
  required int tempsLimite,
}) {
  if (enonce.trim().isEmpty) return 'L\'énoncé est obligatoire.';

  if (options.length < nbOptionsMin) {
    return 'Il faut au moins $nbOptionsMin réponses possibles.';
  }
  if (options.length > nbOptionsMax) {
    return 'Il faut au maximum $nbOptionsMax réponses possibles.';
  }
  if (options.any((o) => o.trim().isEmpty)) {
    return 'Une réponse possible est vide.';
  }
  final sansDoublon = options.map((o) => o.trim().toLowerCase()).toSet();
  if (sansDoublon.length != options.length) {
    return 'Deux réponses possibles sont identiques.';
  }

  if (bonnesReponses.isEmpty) {
    return 'Indiquez au moins une bonne réponse.';
  }
  if (bonnesReponses.any((i) => i < 0 || i >= options.length)) {
    return 'Une bonne réponse ne correspond à aucune option.';
  }
  if (bonnesReponses.toSet().length != bonnesReponses.length) {
    return 'Une bonne réponse est indiquée deux fois.';
  }
  if (type == TypeQuestion.radio && bonnesReponses.length != 1) {
    return 'Une question à choix unique doit avoir exactement 1 bonne réponse.';
  }

  if (tempsLimite < tempsLimiteMin || tempsLimite > tempsLimiteMax) {
    return 'Le temps limite doit être entre $tempsLimiteMin '
        'et $tempsLimiteMax secondes.';
  }
  return null;
}

/// Lit un contenu JSON et renvoie les questions de la [discipline] choisie.
///
/// Lève une [FormatException] avec un message clair si le JSON est mal
/// formé ou si une question n'est pas valide : dans ce cas rien n'est
/// importé (tout ou rien).
List<Question> parserQuestionsJson(String contenu, String discipline) {
  final Object? racine;
  try {
    racine = jsonDecode(contenu);
  } on FormatException {
    throw const FormatException('Le texte n\'est pas un JSON valide.');
  }

  final List<dynamic> liste;
  if (racine is List) {
    liste = racine;
  } else if (racine is Map<String, dynamic>) {
    final d = racine['discipline'];
    if (d != null && d != discipline) {
      throw FormatException(
        'Ce fichier concerne la discipline « $d », '
        'pas « $discipline ».',
      );
    }
    final qs = racine['questions'];
    if (qs is! List) {
      throw const FormatException('La clé "questions" (liste) est manquante.');
    }
    liste = qs;
  } else {
    throw const FormatException('Format JSON non reconnu.');
  }

  if (liste.isEmpty) {
    throw const FormatException('Le fichier ne contient aucune question.');
  }

  final questions = <Question>[];
  for (var i = 0; i < liste.length; i++) {
    final numero = i + 1;
    final item = liste[i];
    if (item is! Map<String, dynamic>) {
      throw FormatException('Question $numero : format incorrect.');
    }

    try {
      final enonce = item['enonce'] as String? ?? '';
      final type = TypeQuestion.values.byName(item['type'] as String);
      final options = List<String>.from(item['options'] as List);
      final bonnes = List<int>.from(item['bonnes_reponses'] as List);
      final temps = item['temps_limite'] as int;

      final erreur = erreurQuestion(
        enonce: enonce,
        type: type,
        options: options,
        bonnesReponses: bonnes,
        tempsLimite: temps,
      );
      if (erreur != null) throw FormatException(erreur);

      questions.add(Question(
        discipline: discipline,
        enonce: enonce.trim(),
        type: type,
        options: options.map((o) => o.trim()).toList(),
        bonnesReponses: bonnes..sort(),
        tempsLimite: temps,
      ));
    } on FormatException catch (e) {
      throw FormatException('Question $numero : ${e.message}');
    } catch (_) {
      // Clé manquante, mauvais type (ex : "temps_limite": "30"), type inconnu…
      throw FormatException(
        'Question $numero : champ manquant ou incorrect '
        '(enonce, type "radio"/"checkbox", options, bonnes_reponses, '
        'temps_limite en nombre).',
      );
    }
  }
  return questions;
}

/// Transforme les questions d'une discipline en JSON (même format que
/// l'import) : pratique pour sauvegarder ou modifier une catégorie entière.
String questionsVersJson(String discipline, List<Question> questions) {
  const encodeur = JsonEncoder.withIndent('  ');
  return encodeur.convert({
    'discipline': discipline,
    'questions': [
      for (final q in questions)
        {
          'enonce': q.enonce,
          'type': q.type.name,
          'options': q.options,
          'bonnes_reponses': q.bonnesReponses,
          'temps_limite': q.tempsLimite,
        },
    ],
  });
}
