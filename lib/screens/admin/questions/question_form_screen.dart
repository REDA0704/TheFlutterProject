import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/question.dart';
import '../../../services/database_service.dart';
import '../../../services/question_json.dart';

/// US5 – Formulaire de création ou de modification d'une question.
///
/// - [question] null  : création d'une nouvelle question
/// - [question] donné : modification de cette question
///
/// Renvoie `true` (via Navigator.pop) si la question a été enregistrée.
class QuestionFormScreen extends StatefulWidget {
  final String discipline;
  final Question? question;

  const QuestionFormScreen({
    super.key,
    required this.discipline,
    this.question,
  });

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _enonceController;
  late final TextEditingController _tempsController;

  // Une ligne par réponse possible : son texte + est-ce une bonne réponse ?
  final List<TextEditingController> _options = [];
  final Set<int> _bonnes = {};

  late TypeQuestion _type;
  String? _erreur;
  bool _enregistrement = false;

  bool get _modification => widget.question != null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _enonceController = TextEditingController(text: q?.enonce ?? '');
    _tempsController =
        TextEditingController(text: '${q?.tempsLimite ?? 30}');
    _type = q?.type ?? TypeQuestion.radio;

    if (q != null) {
      for (final o in q.options) {
        _options.add(TextEditingController(text: o));
      }
      _bonnes.addAll(q.bonnesReponses);
    } else {
      // Nouvelle question : 2 réponses vides pour commencer
      _options.addAll([TextEditingController(), TextEditingController()]);
    }
  }

  @override
  void dispose() {
    _enonceController.dispose();
    _tempsController.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _changerType(TypeQuestion type) {
    setState(() {
      _type = type;
      // En choix unique on ne garde que la première bonne réponse cochée
      if (type == TypeQuestion.radio && _bonnes.length > 1) {
        final premiere = _bonnes.reduce((a, b) => a < b ? a : b);
        _bonnes
          ..clear()
          ..add(premiere);
      }
    });
  }

  void _basculerBonneReponse(int index) {
    setState(() {
      if (_type == TypeQuestion.radio) {
        _bonnes
          ..clear()
          ..add(index);
      } else if (!_bonnes.remove(index)) {
        _bonnes.add(index);
      }
    });
  }

  void _ajouterOption() {
    setState(() => _options.add(TextEditingController()));
  }

  void _supprimerOption(int index) {
    setState(() {
      _options.removeAt(index).dispose();
      // Les réponses après celle supprimée remontent d'un cran
      final decalees = _bonnes
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toSet();
      _bonnes
        ..clear()
        ..addAll(decalees);
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;

    final options = _options.map((c) => c.text.trim()).toList();
    final bonnes = _bonnes.toList()..sort();
    final temps = int.parse(_tempsController.text.trim());

    final erreur = erreurQuestion(
      enonce: _enonceController.text,
      type: _type,
      options: options,
      bonnesReponses: bonnes,
      tempsLimite: temps,
    );
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }

    setState(() => _enregistrement = true);

    final question = Question(
      id: widget.question?.id,
      discipline: widget.discipline,
      enonce: _enonceController.text.trim(),
      type: _type,
      options: options,
      bonnesReponses: bonnes,
      tempsLimite: temps,
    );

    final db = DatabaseService.instance;
    if (_modification) {
      await db.updateQuestion(question);
    } else {
      await db.insertQuestion(question);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modification
              ? 'Modifier la question'
              : 'Nouvelle question – ${widget.discipline}',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _enonceController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Énoncé de la question *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'L\'énoncé est obligatoire.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<TypeQuestion>(
                    segments: const [
                      ButtonSegment(
                        value: TypeQuestion.radio,
                        icon: Icon(Icons.radio_button_checked),
                        label: Text('Choix unique'),
                      ),
                      ButtonSegment(
                        value: TypeQuestion.checkbox,
                        icon: Icon(Icons.check_box),
                        label: Text('Choix multiples'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => _changerType(s.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tempsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Temps limite (secondes) *',
                      prefixIcon: Icon(Icons.timer),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = int.tryParse(v?.trim() ?? '');
                      if (t == null) return 'Le temps limite est obligatoire.';
                      if (t < tempsLimiteMin || t > tempsLimiteMax) {
                        return 'Entre $tempsLimiteMin et $tempsLimiteMax secondes.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Réponses possibles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _type == TypeQuestion.radio
                        ? 'Sélectionnez LA bonne réponse.'
                        : 'Cochez TOUTES les bonnes réponses.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _options.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Bonne réponse',
                            color: _bonnes.contains(i) ? Colors.green : null,
                            icon: Icon(_iconeBonneReponse(i)),
                            onPressed: () => _basculerBonneReponse(i),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _options[i],
                              decoration: InputDecoration(
                                labelText: 'Réponse ${i + 1}',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Réponse vide.'
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Supprimer cette réponse',
                            icon: const Icon(Icons.close),
                            onPressed: _options.length > nbOptionsMin
                                ? () => _supprimerOption(i)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une réponse'),
                      onPressed: _options.length < nbOptionsMax
                          ? _ajouterOption
                          : null,
                    ),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 8),
                    Text(_erreur!, style: TextStyle(color: couleurs.error)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                    onPressed: _enregistrement ? null : _enregistrer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconeBonneReponse(int i) {
    final cochee = _bonnes.contains(i);
    if (_type == TypeQuestion.radio) {
      return cochee ? Icons.radio_button_checked : Icons.radio_button_unchecked;
    }
    return cochee ? Icons.check_box : Icons.check_box_outline_blank;
  }
}
