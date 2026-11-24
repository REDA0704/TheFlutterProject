import 'package:flutter/material.dart';

import '../../models/candidat.dart';
import '../../models/resultat.dart';
import '../../services/database_service.dart';
import '../../utils/disciplines.dart';
import 'passer_test_screen.dart';

/// US2 : liste des disciplines, avec le score des tests déjà passés.
class ListeTestsScreen extends StatefulWidget {
  const ListeTestsScreen({super.key, required this.candidat});
  final Candidat candidat;
  @override
  State<ListeTestsScreen> createState() => _ListeTestsScreenState();
}

class _ListeTestsScreenState extends State<ListeTestsScreen> {
  final _db = DatabaseService.instance;
  late Future<List<Resultat>> _resultats;
  bool _ouverture = false;
  @override
  void initState() {
    super.initState();
    _resultats = _db.getResultatsCandidat(widget.candidat.id!);
  }

  void _recharger() {
    setState(() {
      _resultats = _db.getResultatsCandidat(widget.candidat.id!);
    });
  }

  Future<void> _commencer(String discipline) async {
    if (_ouverture) return;
    setState(() => _ouverture = true);
    try {
      final id = widget.candidat.id!;
      if (await _db.aDejaPasseTest(id, discipline)) {
        if (!mounted) return;
        _message('Ce test a déjà été passé.');
        return;
      }
      final questions = await _db.getQuestionsParDiscipline(discipline);
      if (!mounted) return;
      if (questions.isEmpty) {
        _message('Aucune question disponible pour cette discipline.');
        return;
      }
      if (!await _confirmerDebut(discipline, questions.length)) return;

      // La tentative est enregistrée dès maintenant : quitter le test
      // ne permettra pas de le recommencer (1 seul passage, US2).
      final resultatId = await _db.demarrerTest(
        candidatId: id,
        discipline: discipline,
        totalQuestions: questions.length,
      );
      if (!mounted) return;
      if (resultatId == null) {
        _message('Ce test a déjà été passé.');
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PasserTestScreen(
            resultatId: resultatId,
            discipline: discipline,
            questions: questions,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _message('Impossible de charger le test.');
    } finally {
      if (mounted) {
        setState(() => _ouverture = false);
        _recharger();
      }
    }
  }

  Future<bool> _confirmerDebut(String discipline, int nbQuestions) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commencer le test $discipline ?'),
        content: Text(
          '$nbQuestions question(s), chacune avec un temps limité.\n\n'
          'Ce test ne peut être passé qu\'une seule fois : si vous le '
          'quittez avant la fin, les questions restantes seront comptées '
          'comme fausses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes tests')),
      body: FutureBuilder<List<Resultat>>(
        future: _resultats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _recharger,
                child: const Text('Erreur. Réessayer'),
              ),
            );
          }
          final scores = {for (final r in snapshot.data!) r.discipline: r};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final d in disciplines)
                Card(
                  child: ListTile(
                    title: Text(d),
                    subtitle: Text(
                      scores[d] == null
                          ? 'Disponible'
                          : 'Déjà passé – score '
                                '${scores[d]!.score}/${scores[d]!.total}',
                    ),
                    trailing: ElevatedButton(
                      onPressed: _ouverture || scores[d] != null
                          ? null
                          : () => _commencer(d),
                      child: const Text('Commencer'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
