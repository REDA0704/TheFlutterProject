import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/candidat.dart';
import '../models/question.dart';
import '../models/resultat.dart';
import '../utils/annee_scolaire.dart';
import '../utils/disciplines.dart';
import '../utils/securite.dart';
import 'questions_depart.dart';

/// Levée quand un compte candidat créé avant l'ajout des mots de passe
/// (base v2) se connecte : il doit d'abord définir son mot de passe.
class CompteSansMotDePasse implements Exception {
  const CompteSansMotDePasse();
}

/// Accès à la base SQLite locale.
///
/// Les règles importantes sont garanties par la base elle-même :
/// - UNIQUE (email) sur candidats : un seul compte par adresse email ;
/// - UNIQUE (candidat_id, discipline) sur resultats : un seul passage
///   par test ;
/// - import JSON dans une transaction : tout ou rien.
class DatabaseService {
  // Singleton : une seule instance partagée par toute l'appli
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  // Un test est "réussi" à partir de 50 % de bonnes réponses
  static const double seuilReussite = 0.5;

  // Version du schéma : à augmenter à chaque changement de structure.
  // v2 : mot de passe admin haché + sel, questions de départ.
  // v3 : mot de passe candidat, email unique, année scolaire et statut
  //      (terminé / en cours) sur chaque résultat.
  static const int versionBase = 3;

  // Compte administrateur créé au premier lancement (US4).
  // Ce mot de passe doit être changé à la première connexion.
  static const String adminLoginParDefaut = 'admin';
  static const String adminMotDePasseParDefaut = 'admin123';

  // Marge ajoutée à la durée maximale d'un test avant de le considérer
  // comme interrompu.
  static const Duration margeFinTest = Duration(minutes: 2);

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

  // ───────────── CRÉATION ET MIGRATIONS ─────────────

  // Appelée une seule fois, à la toute première création de la base
  Future<void> _creerTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE candidats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        age INTEGER NOT NULL,
        adresse TEXT NOT NULL,
        motivation TEXT NOT NULL,
        annee_scolaire TEXT NOT NULL, -- année de l'inscription
        mot_de_passe TEXT NOT NULL DEFAULT '', -- hash SHA-256 (sel + mdp)
        sel TEXT NOT NULL DEFAULT '',
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
        annee_scolaire TEXT NOT NULL, -- année du test
        termine INTEGER NOT NULL DEFAULT 0,
        date_limite TEXT NOT NULL,
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

    if (ancienne < 3) {
      // Candidats : mot de passe (vide = à définir à la prochaine connexion)
      await db.execute(
        "ALTER TABLE candidats ADD COLUMN mot_de_passe TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE candidats ADD COLUMN sel TEXT NOT NULL DEFAULT ''",
      );
      // Email unique. Si d'anciens doublons existent, l'index ne peut pas
      // être créé : on garde alors les données telles quelles (l'écran
      // d'inscription vérifie aussi l'email).
      try {
        await db.execute(
          'CREATE UNIQUE INDEX idx_candidats_email ON candidats (email)',
        );
      } on DatabaseException {
        // anciens doublons : contrainte non appliquée sur cette base
      }

      // Résultats : année scolaire du test + statut. Les anciens résultats
      // sont considérés comme terminés.
      await db.execute(
        "ALTER TABLE resultats ADD COLUMN annee_scolaire TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE resultats ADD COLUMN termine INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE resultats ADD COLUMN date_limite TEXT NOT NULL DEFAULT ''",
      );
      final resultats = await db.query('resultats', columns: ['id', 'date']);
      for (final r in resultats) {
        final date = r['date'] as String;
        await db.update(
          'resultats',
          {
            'annee_scolaire': anneeScolaire(DateTime.parse(date)),
            'date_limite': date,
          },
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
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

  /// Change le mot de passe d'un admin après vérification de l'ancien.
  /// Un nouveau sel est généré. Renvoie false si l'ancien est faux.
  Future<bool> changerMotDePasseAdmin({
    required String login,
    required String ancien,
    required String nouveau,
  }) async {
    if (!await verifierAdmin(login, ancien)) return false;
    final db = await database;
    final sel = genererSel();
    await db.update(
      'admins',
      {'mot_de_passe': hacherMotDePasse(nouveau, sel), 'sel': sel},
      where: 'login = ?',
      whereArgs: [login],
    );
    return true;
  }

  // ───────────── CANDIDATS (US1, US3) ─────────────

  /// Crée le compte et renvoie son id. Le mot de passe est stocké haché.
  /// Lève une DatabaseException (contrainte UNIQUE) si l'email existe déjà.
  Future<int> insertCandidat(
    Candidat candidat, {
    required String motDePasse,
  }) async {
    final db = await database;
    final sel = genererSel();
    return db.insert('candidats', {
      ...candidat.toMap(),
      'mot_de_passe': hacherMotDePasse(motDePasse, sel),
      'sel': sel,
    });
  }

  /// Vrai si un compte utilise déjà cet email (valeur normalisée).
  Future<bool> emailExiste(String email) async {
    final db = await database;
    final n = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM candidats WHERE email = ?',
      [email],
    ));
    return (n ?? 0) > 0;
  }

  /// Connexion d'un candidat (US1) avec son email et son mot de passe.
  /// Renvoie null si l'email est inconnu ou le mot de passe faux.
  /// Lève [CompteSansMotDePasse] pour un ancien compte sans mot de passe.
  Future<Candidat?> connecterCandidat(String email, String motDePasse) async {
    final db = await database;
    final lignes = await db.query(
      'candidats',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (lignes.isEmpty) return null;
    final ligne = lignes.first;
    final hash = ligne['mot_de_passe'] as String;
    if (hash.isEmpty) throw const CompteSansMotDePasse();
    if (!verifierMotDePasse(motDePasse, ligne['sel'] as String, hash)) {
      return null;
    }
    return Candidat.fromMap(ligne);
  }

  /// Ancien compte sans mot de passe : le candidat prouve son identité
  /// avec le nom saisi à l'inscription, puis choisit son mot de passe.
  /// Renvoie null si le nom ne correspond pas.
  Future<Candidat?> definirMotDePasseCandidat({
    required String email,
    required String nom,
    required String motDePasse,
  }) async {
    final db = await database;
    final lignes = await db.query(
      'candidats',
      where: "email = ? AND nom = ? AND mot_de_passe = ''",
      whereArgs: [email, nom],
    );
    if (lignes.isEmpty) return null;
    final sel = genererSel();
    await db.update(
      'candidats',
      {'mot_de_passe': hacherMotDePasse(motDePasse, sel), 'sel': sel},
      where: 'id = ?',
      whereArgs: [lignes.first['id']],
    );
    return Candidat.fromMap(lignes.first);
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

  /// Condition SQL « test fini » : terminé normalement, ou interrompu
  /// (heure limite dépassée sans fin de test). Paramètre : maintenant.
  static const String _fini = '(r.termine = 1 OR r.date_limite <= ?)';

  static String _maintenant() => DateTime.now().toIso8601String();

  Future<int> insertResultat(Resultat resultat) async {
    final db = await database;
    return db.insert('resultats', resultat.toMap());
  }

  /// Démarre un test (US2) : la tentative est enregistrée DÈS LE DÉBUT,
  /// avec un score de 0. Ainsi, quitter le test en cours de route, fermer
  /// l'application ou couper le téléphone ne permet pas de le repasser :
  /// la contrainte UNIQUE (candidat_id, discipline) l'interdit.
  ///
  /// [dureeMax] est la somme des temps limites des questions : passé ce
  /// délai (plus une marge), un test non terminé est compté tel quel.
  ///
  /// Renvoie l'id du résultat, ou null si le test a déjà été passé.
  Future<int?> demarrerTest({
    required int candidatId,
    required String discipline,
    required int totalQuestions,
    required Duration dureeMax,
  }) async {
    final db = await database;
    final debut = DateTime.now();
    try {
      return await db.insert(
        'resultats',
        Resultat(
          candidatId: candidatId,
          discipline: discipline,
          score: 0,
          total: totalQuestions,
          date: debut,
          termine: false,
          dateLimite: debut.add(dureeMax + margeFinTest),
        ).toMap(),
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return null;
      rethrow;
    }
  }

  /// Enregistre le score après chaque bonne réponse (US2).
  Future<void> majScore(int resultatId, int score) async {
    final db = await database;
    await db.update(
      'resultats',
      {'score': score},
      where: 'id = ?',
      whereArgs: [resultatId],
    );
  }

  /// Fin du test (dernière question ou abandon) : le score devient définitif.
  Future<void> terminerTest(int resultatId, int score) async {
    final db = await database;
    await db.update(
      'resultats',
      {'score': score, 'termine': 1},
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
  ///
  /// [texte] : chaque mot doit se trouver dans le nom ou le prénom.
  /// « lucas demoalpha » trouve donc Lucas DEMOALPHA.
  /// [annee] : année scolaire du test.
  ///
  /// Chaque ligne contient les colonnes de resultats, plus nom et prenom.
  Future<List<Map<String, dynamic>>> getResultatsRecents({
    int limite = 20,
    String? texte,
    String? annee,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object>[];
    final mots = (texte ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty);
    for (final mot in mots) {
      // % et _ sont des jokers en SQL : on les échappe
      final motifs = '%${mot.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
      conditions.add(r"(c.nom LIKE ? ESCAPE '\' OR c.prenom LIKE ? ESCAPE '\')");
      args..add(motifs)..add(motifs);
    }
    if (annee != null) {
      conditions.add('r.annee_scolaire = ?');
      args.add(annee);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT r.*, c.nom, c.prenom
      FROM resultats r
      JOIN candidats c ON c.id = r.candidat_id
      $where
      ORDER BY r.date DESC
      LIMIT ?
    ''', [...args, limite]);
  }

  /// Années scolaires pour lesquelles au moins un test a été passé,
  /// de la plus récente à la plus ancienne.
  Future<List<String>> anneesAvecResultats() async {
    final db = await database;
    final lignes = await db.rawQuery(
      'SELECT DISTINCT annee_scolaire FROM resultats ORDER BY annee_scolaire DESC',
    );
    return [for (final l in lignes) l['annee_scolaire'] as String];
  }

  // ───────────── STATISTIQUES (US7) ─────────────
  // Seuls les tests finis comptent : un test en cours n'est pas un échec.

  /// Pourcentage de tests réussis par discipline, ex : {'Java': 62.5}.
  Future<Map<String, double>> tauxReussiteParDiscipline({String? annee}) async {
    final db = await database;
    final lignes = await db.rawQuery('''
      SELECT r.discipline,
             AVG(CASE WHEN r.score * 1.0 / r.total >= ? THEN 1.0 ELSE 0.0 END) * 100 AS taux
      FROM resultats r
      WHERE r.total > 0 AND $_fini
        ${annee != null ? 'AND r.annee_scolaire = ?' : ''}
      GROUP BY r.discipline
    ''', [seuilReussite, _maintenant(), ?annee]);
    return {
      for (final l in lignes)
        l['discipline'] as String: (l['taux'] as num).toDouble(),
    };
  }

  /// Taux de réussite de TOUS LES ÉTUDIANTS pour une année (US7).
  ///
  /// Chaque étudiant compte une fois : il est « reçu » si le total de ses
  /// bonnes réponses sur l'ensemble de ses tests atteint le seuil.
  /// (Un étudiant qui a passé 3 tests ne pèse pas 3 fois plus.)
  Future<double> tauxReussiteGlobal(String annee) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT AVG(CASE WHEN bonnes * 1.0 / questions >= ? THEN 1.0 ELSE 0.0 END) * 100 AS taux
      FROM (
        SELECT r.candidat_id, SUM(r.score) AS bonnes, SUM(r.total) AS questions
        FROM resultats r
        WHERE r.total > 0 AND $_fini AND r.annee_scolaire = ?
        GROUP BY r.candidat_id
      )
    ''', [seuilReussite, _maintenant(), annee]);
    final taux = res.first['taux'];
    return taux == null ? 0.0 : (taux as num).toDouble();
  }

  /// Nombre d'étudiants ayant fini au moins un test dans l'année.
  Future<int> nombreEtudiantsEvalues(String annee) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT COUNT(DISTINCT r.candidat_id) FROM resultats r
      WHERE $_fini AND r.annee_scolaire = ?
    ''', [_maintenant(), annee]);
    return Sqflite.firstIntValue(res) ?? 0;
  }
}
