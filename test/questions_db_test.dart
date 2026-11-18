import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/models/question.dart';
import 'package:the_flutter_project/services/database_service.dart';

/// Tests US5 sur une vraie base SQLite (version ordinateur via sqflite_ffi).
void main() {
  final db = DatabaseService.instance;

  Question q(String enonce, {String discipline = 'Java'}) => Question(
        discipline: discipline,
        enonce: enonce,
        type: TypeQuestion.radio,
        options: ['A', 'B'],
        bonnesReponses: [0],
        tempsLimite: 30,
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // On repart d'une base vide à chaque lancement des tests
    await deleteDatabase(join(await getDatabasesPath(), 'flutter_eval.db'));
  });

  test('ajouter, modifier puis supprimer une question', () async {
    final id = await db.insertQuestion(q('Première'));
    var liste = await db.getQuestionsParDiscipline('Java');
    expect(liste.single.enonce, 'Première');

    final modifiee = Question(
      id: id,
      discipline: 'Java',
      enonce: 'Modifiée',
      type: TypeQuestion.checkbox,
      options: ['A', 'B', 'C'],
      bonnesReponses: [0, 2],
      tempsLimite: 45,
    );
    await db.updateQuestion(modifiee);
    liste = await db.getQuestionsParDiscipline('Java');
    expect(liste.single.enonce, 'Modifiée');
    expect(liste.single.type, TypeQuestion.checkbox);
    expect(liste.single.bonnesReponses, [0, 2]);

    await db.deleteQuestion(id);
    expect(await db.getQuestionsParDiscipline('Java'), isEmpty);
  });

  test('import JSON : remplace une seule discipline', () async {
    await db.insertQuestion(q('Ancienne Java'));
    await db.insertQuestion(q('Algo à garder', discipline: 'Algo'));

    await db.remplacerQuestionsDiscipline('Java', [q('Nouvelle 1'), q('Nouvelle 2')]);

    final java = await db.getQuestionsParDiscipline('Java');
    expect(java.map((e) => e.enonce), ['Nouvelle 1', 'Nouvelle 2']);
    final algo = await db.getQuestionsParDiscipline('Algo');
    expect(algo.single.enonce, 'Algo à garder');
  });
}
