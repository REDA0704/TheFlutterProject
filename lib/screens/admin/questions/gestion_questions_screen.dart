import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/question.dart';
import '../../../services/database_service.dart';
import '../../../services/question_json.dart';
import '../../../utils/disciplines.dart';
import 'question_form_screen.dart';

/// US5 – Gestion des questions par l'administrateur.
///
/// Un onglet par discipline. Dans chaque onglet l'admin peut :
/// - ajouter une question (bouton +)
/// - modifier une question (crayon)
/// - supprimer une question (corbeille, avec confirmation)
/// - réinitialiser toute la catégorie à partir d'un JSON (menu en haut)
/// - exporter la catégorie en JSON (menu en haut)
class GestionQuestionsScreen extends StatefulWidget {
  const GestionQuestionsScreen({super.key});

  @override
  State<GestionQuestionsScreen> createState() => _GestionQuestionsScreenState();
}

class _GestionQuestionsScreenState extends State<GestionQuestionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  // Une requête par discipline ; on la relance après chaque modification
  final Map<String, Future<List<Question>>> _questions = {};

  String get _discipline => disciplines[_onglets.index];

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: disciplines.length, vsync: this);
    for (final d in disciplines) {
      _charger(d);
    }
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  void _charger(String discipline) {
    _questions[discipline] =
        DatabaseService.instance.getQuestionsParDiscipline(discipline);
  }

  void _recharger(String discipline) => setState(() => _charger(discipline));

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  // ───────────── Ajouter / modifier / supprimer ─────────────

  Future<void> _ouvrirFormulaire({Question? question}) async {
    final discipline = question?.discipline ?? _discipline;
    final enregistre = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuestionFormScreen(discipline: discipline, question: question),
      ),
    );
    if (enregistre == true) {
      _recharger(discipline);
      _message(question == null ? 'Question ajoutée.' : 'Question modifiée.');
    }
  }

  Future<void> _supprimer(Question question) async {
    final ok = await _confirmer(
      titre: 'Supprimer la question ?',
      texte: '« ${question.enonce} »\n\nCette action est définitive.',
      action: 'Supprimer',
    );
    if (!ok) return;
    await DatabaseService.instance.deleteQuestion(question.id!);
    _recharger(question.discipline);
    _message('Question supprimée.');
  }

  Future<bool> _confirmer({
    required String titre,
    required String texte,
    required String action,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // ───────────── Import / export JSON ─────────────

  Future<void> _importerJson() async {
    final discipline = _discipline;
    final contenu = await showDialog<String>(
      context: context,
      builder: (_) => _ImportJsonDialog(discipline: discipline),
    );
    if (contenu == null || !mounted) return;

    final List<Question> nouvelles;
    try {
      nouvelles = parserQuestionsJson(contenu, discipline);
    } on FormatException catch (e) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import impossible'),
          content: Text('${e.message}\n\nAucune question n\'a été modifiée.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final actuelles = await _questions[discipline]!;
    final ok = await _confirmer(
      titre: 'Réinitialiser « $discipline » ?',
      texte: 'Les ${actuelles.length} question(s) actuelle(s) seront '
          'remplacées par les ${nouvelles.length} question(s) du JSON.',
      action: 'Remplacer',
    );
    if (!ok) return;

    // Suppression + insertion dans une transaction : tout ou rien
    await DatabaseService.instance
        .remplacerQuestionsDiscipline(discipline, nouvelles);
    _recharger(discipline);
    _message('${nouvelles.length} question(s) importée(s) en $discipline.');
  }

  Future<void> _exporterJson() async {
    final discipline = _discipline;
    final questions = await _questions[discipline]!;
    await Clipboard.setData(
      ClipboardData(text: questionsVersJson(discipline, questions)),
    );
    _message('JSON de « $discipline » copié dans le presse-papiers.');
  }

  // ───────────── Affichage ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des questions'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Import / export JSON',
            onSelected: (choix) =>
                choix == 'import' ? _importerJson() : _exporterJson(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Importer un JSON (réinitialiser)'),
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Exporter en JSON'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _onglets,
          tabs: [for (final d in disciplines) Tab(text: d)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        onPressed: () => _ouvrirFormulaire(),
      ),
      body: TabBarView(
        controller: _onglets,
        children: [for (final d in disciplines) _listeQuestions(d)],
      ),
    );
  }

  Widget _listeQuestions(String discipline) {
    return FutureBuilder<List<Question>>(
      future: _questions[discipline],
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur de chargement : ${snap.error}'));
        }
        final questions = snap.data!;
        if (questions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune question pour le moment.\n'
                'Ajoutez-en avec le bouton + ou importez un JSON.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88), // place pour le bouton +
          itemCount: questions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _tuileQuestion(i + 1, questions[i]),
        );
      },
    );
  }

  Widget _tuileQuestion(int numero, Question q) {
    final type =
        q.type == TypeQuestion.radio ? 'Choix unique' : 'Choix multiples';
    return ListTile(
      leading: CircleAvatar(child: Text('$numero')),
      title: Text(q.enonce, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$type · ${q.tempsLimite} s · ${q.options.length} réponses '
        '(${q.bonnesReponses.length} bonne${q.bonnesReponses.length > 1 ? 's' : ''})',
      ),
      onTap: () => _ouvrirFormulaire(question: q),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit),
            onPressed: () => _ouvrirFormulaire(question: q),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _supprimer(q),
          ),
        ],
      ),
    );
  }
}

/// Fenêtre d'import : on colle le JSON ou on choisit un fichier .json.
/// Renvoie le texte JSON, ou null si l'admin annule.
class _ImportJsonDialog extends StatefulWidget {
  final String discipline;

  const _ImportJsonDialog({required this.discipline});

  @override
  State<_ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<_ImportJsonDialog> {
  final _controller = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choisirFichier() async {
    try {
      final fichiers = await FilePicker.pickFiles(
        dialogTitle: 'Choisir un fichier JSON',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (fichiers.isEmpty) return; // annulé
      final octets = await fichiers.first.readAsBytes();
      setState(() {
        _controller.text = utf8.decode(octets);
        _erreur = null;
      });
    } catch (e) {
      setState(() => _erreur = 'Impossible de lire le fichier.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Importer des questions – ${widget.discipline}'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Toutes les questions de cette discipline seront remplacées. '
              'Voir le format dans docs/exemple_questions.json.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir un fichier .json'),
              onPressed: _choisirFichier,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: '… ou collez le JSON ici',
                border: const OutlineInputBorder(),
                errorText: _erreur,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) {
              setState(() => _erreur = 'Aucun JSON à importer.');
              return;
            }
            Navigator.pop(context, _controller.text);
          },
          child: const Text('Importer'),
        ),
      ],
    );
  }
}
