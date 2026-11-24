import '../models/question.dart';

/// Questions insérées au premier lancement de l'application.
///
/// Sans elles, un candidat qui s'inscrit sur une installation neuve ne
/// pourrait passer aucun test. L'administrateur peut ensuite les modifier,
/// les supprimer ou remplacer toute une discipline par un import JSON (US5).
List<Question> questionsDeDepart() => [
      // ───────────── Java ─────────────
      _q('Java', 'Quel mot-clé permet de créer un nouvel objet en Java ?',
          TypeQuestion.radio, ['new', 'create', 'make', 'object'], [0], 30),
      _q('Java', 'Lesquels sont des types primitifs en Java ?',
          TypeQuestion.checkbox, ['int', 'String', 'boolean', 'Integer'],
          [0, 2], 45),
      _q('Java', 'Quelle méthode est le point d\'entrée d\'un programme Java ?',
          TypeQuestion.radio, ['start()', 'main()', 'run()', 'init()'], [1], 20),
      _q('Java', 'Quels mots-clés concernent l\'héritage ?',
          TypeQuestion.checkbox, ['extends', 'implements', 'import', 'package'],
          [0, 1], 40),
      _q('Java', 'Quelle collection n\'accepte pas de doublons ?',
          TypeQuestion.radio, ['ArrayList', 'LinkedList', 'HashSet', 'Vector'],
          [2], 30),

      // ───────────── Algo ─────────────
      _q('Algo', 'Quelle est la complexité d\'une recherche dichotomique ?',
          TypeQuestion.radio, ['O(n)', 'O(log n)', 'O(n²)', 'O(1)'], [1], 30),
      _q('Algo', 'Quelles structures suivent le principe LIFO ou FIFO ?',
          TypeQuestion.checkbox, ['Pile', 'File', 'Arbre binaire', 'Graphe'],
          [0, 1], 40),
      _q('Algo', 'Combien de fois s\'exécute « pour i de 1 à 10 » ?',
          TypeQuestion.radio, ['9', '10', '11', 'Ça dépend'], [1], 20),
      _q('Algo', 'Quels algorithmes sont des algorithmes de tri ?',
          TypeQuestion.checkbox,
          ['Tri à bulles', 'Tri fusion', 'Dijkstra', 'Tri rapide'],
          [0, 1, 3], 45),
      _q('Algo', 'Une fonction qui s\'appelle elle-même est dite…',
          TypeQuestion.radio, ['Itérative', 'Récursive', 'Statique', 'Pure'],
          [1], 20),

      // ───────────── HTML/CSS ─────────────
      _q('HTML/CSS', 'Quelle balise crée un lien hypertexte ?',
          TypeQuestion.radio, ['<link>', '<a>', '<href>', '<url>'], [1], 20),
      _q('HTML/CSS', 'Quelles propriétés CSS concernent la boîte (box model) ?',
          TypeQuestion.checkbox, ['margin', 'padding', 'color', 'border'],
          [0, 1, 3], 45),
      _q('HTML/CSS', 'Quel sélecteur CSS cible un élément par son id ?',
          TypeQuestion.radio, ['.menu', '#menu', 'menu', '*menu'], [1], 20),
      _q('HTML/CSS', 'Quelles balises sont des balises sémantiques HTML5 ?',
          TypeQuestion.checkbox, ['<header>', '<div>', '<nav>', '<span>'],
          [0, 2], 40),
      _q('HTML/CSS', 'Quelle valeur de display active Flexbox ?',
          TypeQuestion.radio, ['block', 'grid', 'flex', 'inline'], [2], 20),
    ];

Question _q(
  String discipline,
  String enonce,
  TypeQuestion type,
  List<String> options,
  List<int> bonnes,
  int temps,
) =>
    Question(
      discipline: discipline,
      enonce: enonce,
      type: type,
      options: options,
      bonnesReponses: bonnes,
      tempsLimite: temps,
    );
