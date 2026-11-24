import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/models/candidat.dart';
import 'package:the_flutter_project/models/resultat.dart';
import 'package:the_flutter_project/services/database_service.dart';
import 'package:the_flutter_project/utils/disciplines.dart';

/// Tests de la base : comptes (admin et candidat), questions de départ,
/// migrations, passage unique et statut des tests (US1, US2, US4, US7).
void main() {
  final db = DatabaseService.instance;
  late Directory dossier;

  Candidat candidat({String nom = 'DUPONT', String email = 'jean@example.test'}) =>
      Candidat(
        nom: nom,
        prenom: 'Jean',
        email: email,
        age: 20,
        adresse: '1 rue de Paris',
        motivation: Motivation.reorientation,
        anneeScolaire: '2026-2027',
      );

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

  group('Admin (US4)', () {
    test('le mot de passe est haché, jamais stocké en clair', () async {
      final admin = (await (await db.database).query('admins')).single;
      expect(admin['mot_de_passe'], isNot('admin123'));
      expect((admin['sel'] as String).isNotEmpty, isTrue);

      expect(await db.verifierAdmin('admin', 'admin123'), isTrue);
      expect(await db.verifierAdmin('admin', 'mauvais'), isFalse);
      expect(await db.verifierAdmin('inconnu', 'admin123'), isFalse);
    });

    test('changement du mot de passe', () async {
      expect(
        await db.changerMotDePasseAdmin(
          login: 'admin',
          ancien: 'faux',
          nouveau: 'Nouveau2026',
        ),
        isFalse,
      );
      expect(
        await db.changerMotDePasseAdmin(
          login: 'admin',
          ancien: 'admin123',
          nouveau: 'Nouveau2026',
        ),
        isTrue,
      );
      expect(await db.verifierAdmin('admin', 'admin123'), isFalse);
      expect(await db.verifierAdmin('admin', 'Nouveau2026'), isTrue);
    });
  });

  group('Candidats (US1)', () {
    test('connexion par email + mot de passe haché', () async {
      await db.insertCandidat(candidat(), motDePasse: 'secret123');
      final ligne = (await (await db.database).query('candidats')).single;
      expect(ligne['mot_de_passe'], isNot('secret123'));

      expect(await db.connecterCandidat('jean@example.test', 'secret123'),
          isNotNull);
      expect(await db.connecterCandidat('jean@example.test', 'faux'), isNull);
      expect(await db.connecterCandidat('autre@example.test', 'secret123'),
          isNull);
    });

    test('un seul compte par email, même avec un nom différent', () async {
      await db.insertCandidat(candidat(), motDePasse: 'secret123');
      expect(await db.emailExiste('jean@example.test'), isTrue);
      expect(
        () => db.insertCandidat(candidat(nom: 'DUPOND'), motDePasse: 'x1234567'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  test('Une installation neuve contient des questions dans chaque discipline',
      () async {
    for (final d in disciplines) {
      expect(await db.getQuestionsParDiscipline(d), isNotEmpty, reason: d);
    }
  });

  test('Migration v1 → v3 : données conservées et complétées', () async {
    // Base créée comme par la toute première version
    final chemin = join(dossier.path, 'flutter_eval.db');
    final v1 = await openDatabase(chemin, version: 1, onCreate: (b, _) async {
      await b.execute('CREATE TABLE candidats (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, nom TEXT NOT NULL, prenom TEXT NOT NULL, '
          'email TEXT NOT NULL, age INTEGER NOT NULL, adresse TEXT NOT NULL, '
          'motivation TEXT NOT NULL, annee_scolaire TEXT NOT NULL, '
          'UNIQUE (nom, email))');
      await b.execute('CREATE TABLE questions (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, discipline TEXT, enonce TEXT, type TEXT, '
          'options TEXT, bonnes_reponses TEXT, temps_limite INTEGER)');
      await b.execute('CREATE TABLE resultats (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, candidat_id INTEGER NOT NULL, discipline TEXT, '
          'score INTEGER, total INTEGER, date TEXT, '
          'UNIQUE (candidat_id, discipline))');
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
      // Inscrit en juin 2026 (2025-2026), test passé en octobre 2026
      final id = await b.insert('candidats', {
        'nom': 'ANCIEN',
        'prenom': 'Paul',
        'email': 'paul@example.test',
        'age': 30,
        'adresse': '2 rue Vieille',
        'motivation': 'reorientation',
        'annee_scolaire': '2025-2026',
      });
      await b.insert('resultats', {
        'candidat_id': id,
        'discipline': 'Java',
        'score': 4,
        'total': 5,
        'date': DateTime(2026, 10, 3).toIso8601String(),
      });
    });
    await v1.close();

    // Admin : mot de passe haché
    expect(await db.verifierAdmin('admin', 'admin123'), isTrue);
    final admin = (await (await db.database).query('admins')).single;
    expect(admin['mot_de_passe'], isNot('admin123'));

    // Questions : Java déjà remplie n'est pas écrasée, Algo est complétée
    final java = await db.getQuestionsParDiscipline('Java');
    expect(java.single.enonce, 'Question de l\'admin');
    expect(await db.getQuestionsParDiscipline('Algo'), isNotEmpty);

    // Résultat : année du test, considéré comme terminé
    final r = (await db.getResultatsCandidat(1)).single;
    expect(r.anneeScolaire, '2026-2027');
    expect(r.termine, isTrue);
    expect(await db.anneesAvecResultats(), ['2026-2027']);

    // Ancien candidat sans mot de passe : il doit en définir un
    expect(
      () => db.connecterCandidat('paul@example.test', 'nouveau123'),
      throwsA(isA<CompteSansMotDePasse>()),
    );
    expect(
      await db.definirMotDePasseCandidat(
        email: 'paul@example.test',
        nom: 'MAUVAIS',
        motDePasse: 'nouveau123',
      ),
      isNull,
    );
    expect(
      await db.definirMotDePasseCandidat(
        email: 'paul@example.test',
        nom: 'ANCIEN',
        motDePasse: 'nouveau123',
      ),
      isNotNull,
    );
    expect(await db.connecterCandidat('paul@example.test', 'nouveau123'),
        isNotNull);
  });

  group('Passage d\'un test (US2)', () {
    test('la tentative est enregistrée dès le début, une seule fois', () async {
      final id = await db.insertCandidat(candidat(), motDePasse: 'secret123');

      final resultatId = await db.demarrerTest(
        candidatId: id,
        discipline: 'Java',
        totalQuestions: 5,
        dureeMax: const Duration(minutes: 3),
      );
      expect(resultatId, isNotNull);
      // Le candidat quitte le test : il ne peut pas le recommencer
      expect(await db.aDejaPasseTest(id, 'Java'), isTrue);
      expect(
        await db.demarrerTest(
          candidatId: id,
          discipline: 'Java',
          totalQuestions: 5,
          dureeMax: const Duration(minutes: 3),
        ),
        isNull,
      );

      await db.majScore(resultatId!, 3);
      var r = (await db.getResultatsCandidat(id)).single;
      expect(r.score, 3);
      expect(r.enCours, isTrue);

      await db.terminerTest(resultatId, 4);
      r = (await db.getResultatsCandidat(id)).single;
      expect(r.score, 4);
      expect(r.termine, isTrue);
      expect(r.enCours, isFalse);
    });

    test('un test en cours ne compte pas dans les statistiques (US7)',
        () async {
      final annee = Resultat(
        candidatId: 0,
        discipline: '',
        score: 0,
        total: 0,
        date: DateTime.now(),
      ).anneeScolaire;
      final id = await db.insertCandidat(candidat(), motDePasse: 'secret123');
      await db.demarrerTest(
        candidatId: id,
        discipline: 'Java',
        totalQuestions: 5,
        dureeMax: const Duration(minutes: 3),
      );
      expect(await db.tauxReussiteParDiscipline(annee: annee), isEmpty);
      expect(await db.nombreEtudiantsEvalues(annee), 0);

      // Test interrompu (appli fermée) : compté une fois l'heure limite passée
      final autre = await db.insertCandidat(
        candidat(nom: 'MARTIN', email: 'martin@example.test'),
        motDePasse: 'secret123',
      );
      final hier = DateTime.now().subtract(const Duration(days: 1));
      await db.insertResultat(Resultat(
        candidatId: autre,
        discipline: 'Algo',
        score: 1,
        total: 5,
        date: hier,
        termine: false,
        dateLimite: hier.add(const Duration(minutes: 5)),
      ));
      final anneeHier = anneeDe(hier);
      expect(
        await db.tauxReussiteParDiscipline(annee: anneeHier),
        {'Algo': 0.0},
      );
    });
  });
}

String anneeDe(DateTime d) => Resultat(
      candidatId: 0,
      discipline: '',
      score: 0,
      total: 0,
      date: d,
    ).anneeScolaire;
