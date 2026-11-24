import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/question.dart';
import '../../services/database_service.dart';

/// Vérifie que tous les bons choix, et seulement eux, sont cochés.
bool reponseCorrecte(Set<int> choix, List<int> bonnes) {
  return bonnes.isNotEmpty &&
      choix.length == bonnes.length &&
      choix.containsAll(bonnes);
}

/// US2 : questions chronométrées, correction et sauvegarde.
///
/// La tentative a déjà été créée en base (score 0) avant d'ouvrir cet écran
/// (voir [DatabaseService.demarrerTest]). Le score est enregistré après
/// chaque bonne réponse, et le test est marqué terminé à la fin ou en cas
/// d'abandon. Si l'appli est fermée, le test est compté tel quel une fois
/// son heure limite passée.
class PasserTestScreen extends StatefulWidget {
  const PasserTestScreen({
    super.key,
    required this.resultatId,
    required this.discipline,
    required this.questions,
  });

  final int resultatId;
  final String discipline;
  final List<Question> questions;

  @override
  State<PasserTestScreen> createState() => _PasserTestScreenState();
}

class _PasserTestScreenState extends State<PasserTestScreen> {
  final _db = DatabaseService.instance;
  int _index = 0;
  int _score = 0;
  int _secondes = 0;
  final Set<int> _choix = {};
  Timer? _timer;
  late DateTime _finQuestion;
  bool _termine = false;

  // Sauvegarde du score en cours (la dernière doit réussir avant de partir)
  Future<void> _sauvegardeEnCours = Future.value();
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
    // On compare à l'heure réelle : le chrono reste juste même si
    // l'appli est mise en arrière-plan.
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

  /// Corrige la question affichée puis passe à la suivante.
  /// Temps écoulé = question comptée fausse.
  void _valider({bool expire = false, int? indexAttendu}) {
    if (_termine || (indexAttendu != null && indexAttendu != _index)) return;
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
    if (_termine) {
      _sauvegarder(fin: true);
    } else if (correct) {
      _sauvegarder();
    }

    if (expire && !_termine && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Temps écoulé : question comptée fausse.'),
          duration: Duration(seconds: 2),
        ));
    }
  }

  /// Enregistre le score. Avec [fin], le test est marqué terminé.
  void _sauvegarder({bool fin = false}) {
    final score = _score;
    _sauvegardeEnCours = _sauvegardeEnCours.then((_) async {
      try {
        if (fin) {
          await _db.terminerTest(widget.resultatId, score);
        } else {
          await _db.majScore(widget.resultatId, score);
        }
        if (mounted && _erreur != null) setState(() => _erreur = null);
      } catch (_) {
        if (mounted) {
          setState(() => _erreur = 'Enregistrement du score impossible.');
        }
      }
    });
  }

  /// Bouton retour pendant le test : on prévient que le test sera
  /// définitivement compté avec les réponses déjà données.
  Future<void> _demanderAbandon() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner le test ?'),
        content: Text(
          'Votre score actuel ($_score/${widget.questions.length}) sera '
          'enregistré et vous ne pourrez pas repasser ce test.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer le test'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _timer?.cancel();
    _termine = true;
    _sauvegarder(fin: true);
    await _sauvegardeEnCours;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _termine,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _demanderAbandon();
      },
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
    final couleurs = Theme.of(context).colorScheme;
    final urgent = _secondes <= 5;

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
                  controlAffinity: ListTileControlAffinity.leading,
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
        Row(
          children: [
            Expanded(child: Text('Question ${_index + 1}/$total')),
            Icon(Icons.timer, color: urgent ? couleurs.error : null),
            const SizedBox(width: 4),
            Text(
              '$_secondes s',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: urgent ? couleurs.error : null,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (_index + 1) / total),
        const SizedBox(height: 24),
        Text(q.enonce, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          q.type == TypeQuestion.radio
              ? 'Une seule bonne réponse.'
              : 'Plusieurs réponses possibles : cochez toutes les bonnes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        options,
        if (_erreur != null)
          Text(_erreur!, style: TextStyle(color: couleurs.error)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _choix.isEmpty ? null : () => _valider(indexAttendu: index),
          child: Text(
            index == total - 1 ? 'Valider et terminer' : 'Valider la réponse',
          ),
        ),
      ],
    );
  }

  Widget _resultat() {
    final total = widget.questions.length;
    final taux = _score / total;
    final reussi = taux >= DatabaseService.seuilReussite;
    return FutureBuilder<void>(
      future: _sauvegardeEnCours,
      builder: (context, snap) {
        final enCours = snap.connectionState != ConnectionState.done;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              reussi ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 64,
              color: reussi ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              '$_score/$total (${(taux * 100).toStringAsFixed(0)} %)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              reussi ? 'Test réussi' : 'Test échoué',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (enCours) const LinearProgressIndicator(),
            if (!enCours && _erreur == null)
              const Text(
                'Résultat enregistré dans votre profil.',
                textAlign: TextAlign.center,
              ),
            if (_erreur != null) ...[
              Text(_erreur!, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => setState(() => _sauvegarder(fin: true)),
                child: const Text('Réessayer'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: enCours ? null : () => Navigator.pop(context),
              child: const Text('Retour à mes tests'),
            ),
          ],
        );
      },
    );
  }
}
