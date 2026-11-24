import 'package:flutter/material.dart';

import '../../models/candidat.dart';
import '../../models/resultat.dart';
import '../../services/database_service.dart';
import '../../utils/validateurs.dart';

/// US3 : informations personnelles et historique des résultats.
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key, required this.candidat});
  final Candidat candidat;
  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _db = DatabaseService.instance;
  final _form = GlobalKey<FormState>();
  final _adresse = TextEditingController();
  Candidat? _candidat;
  Motivation? _motivation;
  List<Resultat> _resultats = [];
  bool _chargement = true;
  bool _sauvegarde = false;
  String? _erreur;
  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final id = widget.candidat.id!;
      final c = await _db.getCandidat(id);
      if (c == null) throw StateError('Candidat introuvable');
      final resultats = await _db.getResultatsCandidat(id);
      if (!mounted) return;
      setState(() {
        _candidat = c;
        _adresse.text = c.adresse;
        _motivation = c.motivation;
        _resultats = resultats;
      });
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Chargement impossible.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _enregistrer() async {
    if (_sauvegarde || !_form.currentState!.validate()) return;
    setState(() => _sauvegarde = true);
    try {
      await _db.updateProfil(
        id: widget.candidat.id!,
        adresse: _adresse.text.trim(),
        motivation: _motivation!,
      );
      if (!mounted) return;
      _message('Profil enregistré.');
    } catch (_) {
      if (mounted) _message('Impossible de sauvegarder le profil.');
    } finally {
      if (mounted) setState(() => _sauvegarde = false);
    }
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  void dispose() {
    _adresse.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _contenu(),
    );
  }

  Widget _contenu() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: TextButton(
          onPressed: _charger,
          child: Text('$_erreur Réessayer'),
        ),
      );
    }
    final c = _candidat!;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Nom : ${c.nom}'),
          Text('Prénom : ${c.prenom}'),
          Text('Email : ${c.email}'),
          Text('Âge : ${c.age}'),
          const SizedBox(height: 20),
          TextFormField(
            controller: _adresse,
            enabled: !_sauvegarde,
            decoration: const InputDecoration(labelText: 'Adresse postale'),
            validator: validerAdresse,
          ),
          DropdownButtonFormField<Motivation>(
            initialValue: _motivation,
            decoration: const InputDecoration(labelText: 'Motivation'),
            items: [
              for (final m in Motivation.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: _sauvegarde
                ? null
                : (m) {
                    setState(() => _motivation = m);
                  },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sauvegarde ? null : _enregistrer,
            child: const Text('Enregistrer'),
          ),
          const Divider(height: 32),
          Text('Mes scores', style: Theme.of(context).textTheme.titleLarge),
          if (_resultats.isEmpty) const Text('Aucun test passé.'),
          for (final r in _resultats)
            ListTile(
              title: Text(r.discipline),
              subtitle: Text(_date(r.date)),
              trailing: Text('${r.score}/${r.total}'),
            ),
        ],
      ),
    );
  }
}
