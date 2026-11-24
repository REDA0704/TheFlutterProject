import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/question.dart';
import '../../models/resultat.dart';
import '../../services/database_service.dart';

/// Vérifie que tous les bons choix, et seulement eux, sont cochés.
bool reponseCorrecte(Set<int> choix, List<int> bonnes) {
  return bonnes.isNotEmpty &&
      choix.length == bonnes.length &&
      choix.containsAll(bonnes);
}

/// US2 : questions chronométrées, correction et sauvegarde.
class PasserTestScreen extends StatefulWidget {
  const PasserTestScreen({
    super.key,
    required this.candidatId,
    required this.discipline,
    required this.questions,
  });
  final int candidatId;
  final String discipline;
  final List<Question> questions;
  @override
  State<PasserTestScreen> createState() => _PasserTestScreenState();
}

class _PasserTestScreenState extends State<PasserTestScreen> {
  int _index = 0;
  int _score = 0;
  int _secondes = 0;
  final Set<int> _choix = {};
  Timer? _timer;
  late DateTime _finQuestion;
  bool _termine = false;
  bool _sauvegarde = false;
  bool _enregistre = false;
  String? _erreur;
  Question get _question => widget.questions[_index];
  @override
  void initState() {
    super.initState();
    _demarrerChrono();
  }

  void _demarrerChrono() {
    _timer?.cancel();
    _secondes = _question.tempsLimite;
    _finQuestion = DateTime.now().add(Duration(seconds: _secondes));
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _termine) return;
      final ms = _finQuestion.difference(DateTime.now()).inMilliseconds;
      if (ms <= 0) {
        _valider(expire: true);
      } else {
        final reste = (ms / 1000).ceil();
        if (reste != _secondes) setState(() => _secondes = reste);
      }
    });
  }

  void _valider({bool expire = false, int? indexAttendu}) {
    if (_termine || (indexAttendu != null && indexAttendu != _index)) {
      return;
    }
    _timer?.cancel();
    final aTemps = !expire && DateTime.now().isBefore(_finQuestion);
    final correct = aTemps && reponseCorrecte(_choix, _question.bonnesReponses);
    setState(() {
      if (correct) _score++;
      if (_index == widget.questions.length - 1) {
        _termine = true;
      } else {
        _index++;
        _choix.clear();
        _demarrerChrono();
      }
    });
    if (_termine) _enregistrer();
  }

  Future<void> _enregistrer() async {
    if (_sauvegarde || _enregistre) return;
    setState(() {
      _sauvegarde = true;
      _erreur = null;
    });
    final db = DatabaseService.instance;
    try {
      await db.insertResultat(
        Resultat(
          candidatId: widget.candidatId,
          discipline: widget.discipline,
          score: _score,
          total: widget.questions.length,
          date: DateTime.now(),
        ),
      );
      if (mounted) setState(() => _enregistre = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = 'Enregistrement impossible. Réessayez.');
      try {
        final existe = await db.aDejaPasseTest(
          widget.candidatId,
          widget.discipline,
        );
        if (mounted && existe) {
          setState(
            () => _erreur = 'Un résultat existe déjà. Retournez à Mes tests.',
          );
        }
      } catch (_) {
        // Le message initial reste affiché si la base est indisponible.
      }
    } finally {
      if (mounted) setState(() => _sauvegarde = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sauvegarde,
      child: Scaffold(
        appBar: AppBar(title: Text('Test ${widget.discipline}')),
        body: _termine ? _resultat() : _questionBody(),
      ),
    );
  }

  Widget _questionBody() {
    final q = _question;
    final index = _index;
    final total = widget.questions.length;
    final options = q.type == TypeQuestion.radio
        ? RadioGroup<int>(
            key: ValueKey(index),
            groupValue: _choix.isEmpty ? null : _choix.first,
            onChanged: (v) => setState(() {
              if (_index != index || _termine) return;
              _choix.clear();
              if (v != null) _choix.add(v);
            }),
            child: Column(
              children: [
                for (var i = 0; i < q.options.length; i++)
                  RadioListTile<int>(value: i, title: Text(q.options[i])),
              ],
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < q.options.length; i++)
                CheckboxListTile(
                  title: Text(q.options[i]),
                  value: _choix.contains(i),
                  onChanged: (v) => setState(() {
                    if (_index != index || _termine) return;
                    if (v == true) {
                      _choix.add(i);
                    } else {
                      _choix.remove(i);
                    }
                  }),
                ),
            ],
          );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Question ${_index + 1}/$total'),
        LinearProgressIndicator(value: (_index + 1) / total),
        const SizedBox(height: 16),
        Text(
          'Temps restant : $_secondes s',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(q.enonce, style: Theme.of(context).textTheme.titleLarge),
        options,
        FilledButton(
          onPressed: _choix.isEmpty
              ? null
              : () => _valider(indexAttendu: index),
          child: const Text('Valider la réponse'),
        ),
      ],
    );
  }

  Widget _resultat() {
    final total = widget.questions.length;
    final taux = _score / total;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Résultat du test'),
        Text(
          '$_score/$total (${(taux * 100).toStringAsFixed(0)} %)',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          taux >= DatabaseService.seuilReussite ? 'Test réussi' : 'Test échoué',
        ),
        if (_sauvegarde) const LinearProgressIndicator(),
        if (_enregistre) const Text('Résultat enregistré.'),
        if (_erreur != null) Text(_erreur!),
        if (!_enregistre && !_sauvegarde)
          TextButton(onPressed: _enregistrer, child: const Text('Réessayer')),
        FilledButton(
          onPressed: _sauvegarde ? null : () => Navigator.pop(context),
          child: const Text('Retour à mes tests'),
        ),
      ],
    );
  }
}
