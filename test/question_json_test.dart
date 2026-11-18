import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_flutter_project/models/question.dart';
import 'package:the_flutter_project/services/question_json.dart';

void main() {
  group('erreurQuestion', () {
    String? verifier({
      String enonce = 'Question ?',
      TypeQuestion type = TypeQuestion.radio,
      List<String> options = const ['A', 'B'],
      List<int> bonnes = const [0],
      int temps = 30,
    }) =>
        erreurQuestion(
          enonce: enonce,
          type: type,
          options: options,
          bonnesReponses: bonnes,
          tempsLimite: temps,
        );

    test('question valide', () => expect(verifier(), isNull));
    test('énoncé vide', () => expect(verifier(enonce: '  '), isNotNull));
    test('moins de 2 options', () => expect(verifier(options: ['A']), isNotNull));
    test('option vide', () => expect(verifier(options: ['A', ' ']), isNotNull));
    test('options en double', () {
      expect(verifier(options: ['Oui', 'oui']), isNotNull);
    });
    test('aucune bonne réponse', () => expect(verifier(bonnes: []), isNotNull));
    test('bonne réponse hors limites', () {
      expect(verifier(bonnes: [5]), isNotNull);
    });
    test('choix unique avec 2 bonnes réponses refusé', () {
      expect(verifier(bonnes: [0, 1]), isNotNull);
    });
    test('choix multiples avec 2 bonnes réponses accepté', () {
      expect(verifier(type: TypeQuestion.checkbox, bonnes: [0, 1]), isNull);
    });
    test('temps limite hors bornes', () {
      expect(verifier(temps: tempsLimiteMin - 1), isNotNull);
      expect(verifier(temps: tempsLimiteMax + 1), isNotNull);
    });
  });

  group('parserQuestionsJson', () {
    test('lit le fichier d\'exemple du dossier docs', () {
      final contenu = File('docs/exemple_questions.json').readAsStringSync();
      final questions = parserQuestionsJson(contenu, 'Java');
      expect(questions, hasLength(5));
      expect(questions.first.type, TypeQuestion.radio);
      expect(questions[1].bonnesReponses, [0, 2]);
      expect(questions.every((q) => q.discipline == 'Java'), isTrue);
    });

    test('accepte une simple liste de questions', () {
      const json = '[{"enonce":"Q","type":"checkbox","options":["a","b"],'
          '"bonnes_reponses":[1,0],"temps_limite":10}]';
      final q = parserQuestionsJson(json, 'Algo').single;
      expect(q.discipline, 'Algo');
      expect(q.bonnesReponses, [0, 1]); // triées
    });

    test('refuse un JSON mal formé', () {
      expect(
        () => parserQuestionsJson('{pas du json', 'Java'),
        throwsFormatException,
      );
    });

    test('refuse une autre discipline', () {
      const json = '{"discipline":"Algo","questions":[]}';
      expect(() => parserQuestionsJson(json, 'Java'), throwsFormatException);
    });

    test('refuse une liste vide', () {
      expect(() => parserQuestionsJson('[]', 'Java'), throwsFormatException);
    });

    test('indique le numéro de la question fautive', () {
      const json = '[{"enonce":"Q1","type":"radio","options":["a","b"],'
          '"bonnes_reponses":[0],"temps_limite":10},'
          '{"enonce":"Q2","type":"radio","options":["a","b"],'
          '"bonnes_reponses":[0,1],"temps_limite":10}]';
      expect(
        () => parserQuestionsJson(json, 'Java'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          startsWith('Question 2'),
        )),
      );
    });

    test('refuse un champ de mauvais type', () {
      const json = '[{"enonce":"Q","type":"radio","options":["a","b"],'
          '"bonnes_reponses":[0],"temps_limite":"30"}]';
      expect(() => parserQuestionsJson(json, 'Java'), throwsFormatException);
    });

    test('refuse un type inconnu', () {
      const json = '[{"enonce":"Q","type":"texte","options":["a","b"],'
          '"bonnes_reponses":[0],"temps_limite":30}]';
      expect(() => parserQuestionsJson(json, 'Java'), throwsFormatException);
    });
  });

  test('export puis import redonne les mêmes questions', () {
    final avant = [
      Question(
        discipline: 'HTML/CSS',
        enonce: 'Balise de titre ?',
        type: TypeQuestion.radio,
        options: ['<h1>', '<p>'],
        bonnesReponses: [0],
        tempsLimite: 15,
      ),
    ];
    final apres = parserQuestionsJson(
      questionsVersJson('HTML/CSS', avant),
      'HTML/CSS',
    );
    expect(apres.single.enonce, avant.single.enonce);
    expect(apres.single.options, avant.single.options);
    expect(apres.single.bonnesReponses, avant.single.bonnesReponses);
    expect(apres.single.tempsLimite, avant.single.tempsLimite);
  });
}
