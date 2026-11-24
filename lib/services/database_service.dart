import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/candidat.dart';
import '../models/question.dart';
import '../models/resultat.dart';
import '../utils/disciplines.dart';
import '../utils/securite.dart';
import 'questions_depart.dart';

class DatabaseService {
  // Singleton : une seule instance partagée par toute l'appli
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  // Un test est "réussi" à partir de 50 % de bonnes réponses
  static const double seuilReussite = 0.5;

  // Version du schéma : à augmenter à chaque changement de structure.
  // v2 : mot de passe admin haché + sel, questions de départ.
  static const int versionBase = 2;

  // Compte administrateur créé au premier lancement (US4)
  static const String adminLoginParDefaut = 'admin';
  static const String adminMotDePasseParDefaut = 'admin123';

  Database? _db;

  // Ouvre la base au premier appel, puis réutilise la même connexion
  Future<Database> get database async => _db ??= await _ouvrir();

  Future<Database> _ouvrir() async {
    final chemin = join(await getDatabasesPath(), 'flutter_eval.db');
    return openDatabase(
      chemin,
      version: versionBase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _creerTables,
      onUpgrade: _migrer,
    );
  }

  /// Ferme la base (utile dans les tests pour repartir de zéro).
  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  /// Met à jour une base créée par une ancienne version de l'appli,
  /// sans perdre les candidats ni les résultats déjà enregistrés.
  Future<void> _migrer(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      // Le mot de passe admin était stocké en clair : on le hache.
      await db.execute(
        "ALTER TABLE admins ADD COLUMN sel TEXT NOT NULL DEFAULT ''",
      );
      final admins = await db.query('admins');
      for (final a in admins) {
        final sel = genererSel();
        await db.update(
          'admins',
          {
            'sel': sel,
            'mot_de_passe': hacherMotDePasse(a['mot_de_passe'] as String, sel),
          },
          where: 'id = ?',
          whereArgs: [a['id']],
        );
      }
      await _insererQuestionsDeDepart(db, seulementSiVide: true);
    }
  }

  /// Insère les questions de départ dans chaque discipline.
  /// Avec [seulementSiVide], une discipline qui a déjà des questions
  /// (créées par l'admin) n'est pas touchée.
  Future<void> _insererQuestionsDeDepart(
    DatabaseExecutor db, {
    bool seulementSiVide = false,
  }) async {
    final depart = questionsDeDepart();
    for (final d in disciplines) {
      if (seulementSiVide) {
        final n = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM questions WHERE discipline = ?',
          [d],
        ));
        if ((n ?? 0) > 0) continue;
      }
      for (final q in depart.where((q) => q.discipline == d)) {
        await db.insert('questions', q.toMap());
      }
    }
  }

  // Appelée une seule fois, à la toute première création de la base
  Future<void> _creerTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE candidats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL,
        age INTEGER NOT NULL,
        adresse TEXT NOT NULL,
        motivation TEXT NOT NULL,
        annee_scolaire TEXT NOT NULL,
        UNIQUE (nom, email)
      )
    ''');

    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        discipline TEXT NOT NULL,
        enonce TEXT NOT NULL,
        type TEXT NOT NULL,
        options TEXT NOT NULL,
        bonnes_reponses TEXT NOT NULL,
        temps_limite INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE resultats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidat_id INTEGER NOT NULL,
        discipline TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        date TEXT NOT NULL,
        UNIQUE (candidat_id, discipline),
        FOREIGN KEY (candidat_id) REFERENCES candidats (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT NOT NULL UNIQUE,
        mot_de_passe TEXT NOT NULL, -- hash SHA-256 (sel + mot de passe)
        sel TEXT NOT NULL
      )
    ''');

    // Compte admin pré-existant (US4), mot de passe stocké haché
    final sel = genererSel();
    await db.insert('admins', {
      'login': adminLoginParDefaut,
      'mot_de_passe': hacherMotDePasse(adminMotDePasseParDefaut, sel),
      'sel': sel,
    });

    // Questions de départ : un candidat peut passer un test dès l'installation
    await _insererQuestionsDeDepart(db);
  }

  // ───────────── ADMIN (US4) ─────────────

  Future<bool> verifierAdmin(String login, String motDePasse) async {
    final db = await database;
    final lignes = await db.query(
      'admins',
      where: 'login = ?',
      whereArgs: [login],
    );
    if (lignes.isEmpty) return false;
    final admin = lignes.first;
    return verifierMotDePasse(
      motDePasse,
      admin['sel'] as String,
      admin['mot_de_passe'] as String,
    );
  }

  // ───────────── CANDIDATS (US1, US3) ─────────────

  /// Renvoie l'id créé. Lève une DatabaseException si (nom, email) existe déjà.
  Future<int> insertCandidat(Candidat candidat) async {
    final db = await database;
    return db.insert('candidats', candidat.toMap());
  }

  /// Connexion d'un candidat (US1) avec le couple Nom + Email,
  /// qui identifie un compte de façon unique.
  /// Les valeurs doivent déjà être normalisées (voir utils/validateurs.dart).
  /// Renvoie null si aucun compte ne correspond.
  Future<Candidat?> connecterCandidat(String nom, String email) async {
    final db = await database;
    final lignes = await db.query(
      'candidats',
      where: 'nom = ? AND email = ?',
      whereArgs: [nom, email],
    );
    return lignes.isEmpty ? null : Candidat.fromMap(lignes.first);
  }

  Future<Candidat?> getCandidat(int id) async {
    final db = await database;
    final lignes = await db.query('candidats', where: 'id = ?', whereArgs: [id]);
    return lignes.isEmpty ? null : Candidat.fromMap(lignes.first);
  }

  /// US3 : le candidat ne peut modifier que son adresse et sa motivation.
  /// Nom, prénom, email et âge restent ceux de l'inscription.
  Future<void> updateProfil({
    required int id,
    required String adresse,
    required Motivation motivation,
  }) async {
    final db = await database;
    final nombre = await db.update(
      'candidats',
      {'adresse': adresse, 'motivation': motivation.name},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (nombre != 1) throw StateError('Candidat introuvable');
  }

  Future<void> updateCandidat(Candidat candidat) async {
    final db = await database;
    await db.update(
      'candidats',
      candidat.toMap(),
      where: 'id = ?',
      whereArgs: [candidat.id],
    );
  }

  /// Recherche par nom/prénom (US6), filtre optionnel par année scolaire.
  Future<List<Candidat>> rechercherCandidats({
    String? texte,
    String? annee,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object>[];
    if (texte != null && texte.isNotEmpty) {
      conditions.add('(nom LIKE ? OR prenom LIKE ?)');
      args..add('%$texte%')..add('%$texte%');
    }
    if (annee != null) {
      conditions.add('annee_scolaire = ?');
      args.add(annee);
    }
    final lignes = await db.query(
      'candidats',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nom, prenom',
    );
    return lignes.map(Candidat.fromMap).toList();
  }

  // ───────────── QUESTIONS (US2, US5) ─────────────

  Future<int> insertQuestion(Question question) async {
    final db = await database;
    return db.insert('questions', question.toMap());
  }

  Future<void> updateQuestion(Question question) async {
    final db = await database;
    await db.update(
      'questions',
      question.toMap(),
      where: 'id = ?',
      whereArgs: [question.id],
    );
  }

  Future<void> deleteQuestion(int id) async {
    final db = await database;
    await db.delete('questions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Question>> getQuestionsParDiscipline(String discipline) async {
    final db = await database;
    final lignes = await db.query(
      'questions',
      where: 'discipline = ?',
      whereArgs: [discipline],
      orderBy: 'id',
    );
    return lignes.map(Question.fromMap).toList();
  }

  /// Réinitialise une catégorie complète (ex : import JSON, US5).
  /// Tout est supprimé puis réinséré dans une transaction :
  /// si une insertion échoue, rien n'est modifié.
  Future<void> remplacerQuestionsDiscipline(
    String discipline,
    List<Question> questions,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'questions',
        where: 'discipline = ?',
        whereArgs: [discipline],
      );
      for (final q in questions) {
        await txn.insert('questions', q.toMap());
      }
    });
  }

  // ───────────── RÉSULTATS (US2, US3, US6) ─────────────

  Future<int> insertResultat(Resultat resultat) async {
    final db = await database;
    return db.insert('resultats', resultat.toMap());
  }

  /// Démarre un test (US2) : la tentative est enregistrée DÈS LE DÉBUT,
  /// avec un score de 0. Ainsi, quitter le test en cours de route, fermer
  /// l'application ou couper le téléphone ne permet pas de le repasser :
  /// la contrainte UNIQUE (candidat_id, discipline) l'interdit.
  ///
  /// Renvoie l'id du résultat, ou null si le test a déjà été passé.
  Future<int?> demarrerTest({
    required int candidatId,
    required String discipline,
    required int totalQuestions,
  }) async {
    final db = await database;
    try {
      return await db.insert('resultats', {
        'candidat_id': candidatId,
        'discipline': discipline,
        'score': 0,
        'total': totalQuestions,
        'date': DateTime.now().toIso8601String(),
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return null;
      rethrow;
    }
  }

  /// Enregistre le score après chaque question répondue (US2).
  Future<void> majScore(int resultatId, int score) async {
    final db = await database;
    await db.update(
      'resultats',
      {'score': score},
      where: 'id = ?',
      whereArgs: [resultatId],
    );
  }

  /// Un test ne peut être passé qu'une fois (US2).
  Future<bool> aDejaPasseTest(int candidatId, String discipline) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM resultats WHERE candidat_id = ? AND discipline = ?',
      [candidatId, discipline],
    );
    return (Sqflite.firstIntValue(res) ?? 0) > 0;
  }

  Future<List<Resultat>> getResultatsCandidat(int candidatId) async {
    final db = await database;
    final lignes = await db.query(
      'resultats',
      where: 'candidat_id = ?',
      whereArgs: [candidatId],
      orderBy: 'date DESC',
    );
    return lignes.map(Resultat.fromMap).toList();
  }

  /// Derniers résultats avec nom/prénom du candidat (tableau de bord, US6).
  /// Chaque ligne contient : id, discipline, score, total, date, nom, prenom, annee_scolaire.
  Future<List<Map<String, dynamic>>> getResultatsRecents({
    int limite = 20,
    String? texte,
    String? annee,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object>[];
    if (texte != null && texte.isNotEmpty) {
      conditions.add('(c.nom LIKE ? OR c.prenom LIKE ?)');
      args..add('%$texte%')..add('%$texte%');
    }
    if (annee != null) {
      conditions.add('c.annee_scolaire = ?');
      args.add(annee);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT r.*, c.nom, c.prenom, c.annee_scolaire
      FROM resultats r
      JOIN candidats c ON c.id = r.candidat_id
      $where
      ORDER BY r.date DESC
      LIMIT ?
    ''', [...args, limite]);
  }

  // ───────────── STATISTIQUES (US7) ─────────────

  /// Pourcentage de réussite par discipline, ex : {'Java': 62.5, 'Algo': 40.0}
  Future<Map<String, double>> tauxReussiteParDiscipline({String? annee}) async {
    final db = await database;
    final lignes = await db.rawQuery('''
      SELECT r.discipline,
             AVG(CASE WHEN r.score * 1.0 / r.total >= ? THEN 1.0 ELSE 0.0 END) * 100 AS taux
      FROM resultats r
      JOIN candidats c ON c.id = r.candidat_id
      WHERE r.total > 0 ${annee != null ? 'AND c.annee_scolaire = ?' : ''}
      GROUP BY r.discipline
    ''', [seuilReussite, ?annee]);
    return {
      for (final l in lignes)
        l['discipline'] as String: (l['taux'] as num).toDouble(),
    };
  }

  /// Taux de réussite de tous les tests pour une année donnée.
  Future<double> tauxReussiteGlobal(String annee) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT AVG(CASE WHEN r.score * 1.0 / r.total >= ? THEN 1.0 ELSE 0.0 END) * 100 AS taux
      FROM resultats r
      JOIN candidats c ON c.id = r.candidat_id
      WHERE r.total > 0 AND c.annee_scolaire = ?
    ''', [seuilReussite, annee]);
    final taux = res.first['taux'];
    return taux == null ? 0.0 : (taux as num).toDouble();
  }
}