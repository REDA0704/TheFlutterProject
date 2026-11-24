import 'package:flutter/material.dart';

import '../../models/candidat.dart';
import '../../models/resultat.dart';
import '../../services/database_service.dart';
import '../../utils/disciplines.dart';
import 'passer_test_screen.dart';

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
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PasserTestScreen(
            candidatId: id,
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
                          : 'Déjà passé - score '
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
