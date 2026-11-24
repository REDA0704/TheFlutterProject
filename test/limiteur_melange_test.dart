import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_flutter_project/models/question.dart';
import 'package:the_flutter_project/screens/candidat/passer_test_screen.dart';
import 'package:the_flutter_project/utils/limiteur_tentatives.dart';
import 'package:the_flutter_project/utils/melange.dart';

void main() {
  group('LimiteurTentatives', () {
    test('bloque après 5 échecs puis débloque après 30 s', () {
      var maintenant = DateTime(2026, 11, 24, 10);
      final l = LimiteurTentatives(horloge: () => maintenant);

      for (var i = 0; i < 4; i++) {
        l.echec('admin');
      }
      expect(l.tempsRestant('admin'), isNull);
      l.echec('admin');
      expect(l.tempsRestant('admin'), const Duration(seconds: 30));
      // Un autre identifiant n'est pas bloqué
      expect(l.tempsRestant('autre'), isNull);

      maintenant = maintenant.add(const Duration(seconds: 31));
      expect(l.tempsRestant('admin'), isNull);
    });

    test('une connexion réussie remet le compteur à zéro', () {
      final l = LimiteurTentatives();
      for (var i = 0; i < 4; i++) {
        l.echec('admin');
      }
      l.succes('admin');
      l.echec('admin');
      expect(l.tempsRestant('admin'), isNull);
    });
  });

  group('preparerTest (mélange)', () {
    final questions = [
      for (var n = 0; n < 6; n++)
        Question(
          id: n,
          discipline: 'Java',
          enonce: 'Q$n',
          type: TypeQuestion.checkbox,
          options: ['bonne A', 'fausse B', 'bonne C', 'fausse D'],
          bonnesReponses: [0, 2],
          tempsLimite: 30,
        ),
    ];

    test('les bonnes réponses suivent les options mélangées', () {
      final melangees = preparerTest(questions, Random(42));
      expect(melangees.length, questions.length);
      for (final q in melangees) {
        expect(q.options.toSet(), questions.first.options.toSet());
        final bonnes = {for (final i in q.bonnesReponses) q.options[i]};
        expect(bonnes, {'bonne A', 'bonne C'});
        expect(reponseCorrecte(q.bonnesReponses.toSet(), q.bonnesReponses),
            isTrue);
      }
      // Toutes les questions sont présentes, une seule fois
      expect(melangees.map((q) => q.id).toSet(), {0, 1, 2, 3, 4, 5});
    });

    test('l\'ordre change d\'un candidat à l\'autre', () {
      final a = preparerTest(questions, Random(1)).map((q) => q.id).toList();
      final b = preparerTest(questions, Random(2)).map((q) => q.id).toList();
      expect(a, isNot(b));
    });
  });
}
