import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/models/candidat.dart';
import 'package:the_flutter_project/services/database_service.dart';
import 'package:the_flutter_project/utils/disciplines.dart';

/// Tests de la base : compte admin haché, questions de départ,
/// migration depuis la v1 et passage unique d'un test (US2, US4).
void main() {
  final db = DatabaseService.instance;
  late Directory dossier;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('base_');
    await databaseFactory.setDatabasesPath(dossier.path);
  });

  tearDown(() async {
    await db.fermer();
    await dossier.delete(recursive: true);
  });

  test('US4 : le mot de passe admin est haché, jamais stocké en clair',
      () async {
    final admin = (await (await db.database).query('admins')).single;
    expect(admin['mot_de_passe'], isNot('admin123'));
    expect((admin['sel'] as String).isNotEmpty, isTrue);

    expect(await db.verifierAdmin('admin', 'admin123'), isTrue);
    expect(await db.verifierAdmin('admin', 'mauvais'), isFalse);
    expect(await db.verifierAdmin('inconnu', 'admin123'), isFalse);
  });

  test('Une installation neuve contient des questions dans chaque discipline',
      () async {
    for (final d in disciplines) {
      expect(await db.getQuestionsParDiscipline(d), isNotEmpty, reason: d);
    }
  });

  test('Migration v1 → v2 : admin haché, données conservées', () async {
    // Base créée comme par l'ancienne version (mot de passe en clair)
    final chemin = join(dossier.path, 'flutter_eval.db');
    final v1 = await openDatabase(chemin, version: 1, onCreate: (b, _) async {
      await b.execute('CREATE TABLE candidats (id INTEGER PRIMARY KEY, '
          'nom TEXT, prenom TEXT, email TEXT, age INTEGER, adresse TEXT, '
          'motivation TEXT, annee_scolaire TEXT, UNIQUE (nom, email))');
      await b.execute('CREATE TABLE questions (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, discipline TEXT, enonce TEXT, type TEXT, '
          'options TEXT, bonnes_reponses TEXT, temps_limite INTEGER)');
      await b.execute('CREATE TABLE resultats (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, candidat_id INTEGER, discipline TEXT, score INTEGER, '
          'total INTEGER, date TEXT, UNIQUE (candidat_id, discipline))');
      await b.execute('CREATE TABLE admins (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, login TEXT UNIQUE, mot_de_passe TEXT)');
      await b.insert('admins', {'login': 'admin', 'mot_de_passe': 'admin123'});
      await b.insert('questions', {
        'discipline': 'Java',
        'enonce': 'Question de l\'admin',
        'type': 'radio',
        'options': '["A","B"]',
        'bonnes_reponses': '[0]',
        'temps_limite': 30,
      });
    });
    await v1.close();

    expect(await db.verifierAdmin('admin', 'admin123'), isTrue);
    final admin = (await (await db.database).query('admins')).single;
    expect(admin['mot_de_passe'], isNot('admin123'));
    // Java avait déjà une question : elle n'est pas écrasée
    final java = await db.getQuestionsParDiscipline('Java');
    expect(java.single.enonce, 'Question de l\'admin');
    // Algo était vide : questions de départ ajoutées
    expect(await db.getQuestionsParDiscipline('Algo'), isNotEmpty);
  });

  test('US2 : la tentative est enregistrée dès le début, une seule fois',
      () async {
    final id = await db.insertCandidat(Candidat(
      nom: 'DUPONT',
      prenom: 'Jean',
      email: 'jean@example.test',
      age: 20,
      adresse: '1 rue de Paris',
      motivation: Motivation.reorientation,
      anneeScolaire: '2026-2027',
    ));

    final resultatId = await db.demarrerTest(
      candidatId: id,
      discipline: 'Java',
      totalQuestions: 5,
    );
    expect(resultatId, isNotNull);
    // Le candidat quitte le test : il ne peut pas le recommencer
    expect(await db.aDejaPasseTest(id, 'Java'), isTrue);
    expect(
      await db.demarrerTest(candidatId: id, discipline: 'Java', totalQuestions: 5),
      isNull,
    );

    await db.majScore(resultatId!, 3);
    final r = (await db.getResultatsCandidat(id)).single;
    expect(r.score, 3);
    expect(r.total, 5);
  });
}
