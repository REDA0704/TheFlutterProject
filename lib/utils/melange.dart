import 'dart:math';

import '../models/question.dart';

/// Prépare un test (US2) : l'ordre des questions ET l'ordre des réponses
/// changent pour chaque candidat. Deux candidats ne voient donc pas
/// « la bonne réponse est la B » au même endroit.
///
/// Les indices des bonnes réponses sont recalculés après le mélange.
/// [aleatoire] permet d'avoir un mélange reproductible dans les tests.
List<Question> preparerTest(List<Question> questions, [Random? aleatoire]) {
  final r = aleatoire ?? Random();
  final melangees = [for (final q in questions) _melangerOptions(q, r)];
  melangees.shuffle(r);
  return melangees;
}

Question _melangerOptions(Question q, Random r) {
  // ordre[i] = position d'origine de l'option affichée en i
  final ordre = List<int>.generate(q.options.length, (i) => i)..shuffle(r);
  return Question(
    id: q.id,
    discipline: q.discipline,
    enonce: q.enonce,
    type: q.type,
    options: [for (final i in ordre) q.options[i]],
    bonnesReponses: [
      for (var nouvelle = 0; nouvelle < ordre.length; nouvelle++)
        if (q.bonnesReponses.contains(ordre[nouvelle])) nouvelle,
    ],
    tempsLimite: q.tempsLimite,
  );
}
