import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/candidat.dart';
import '../../services/database_service.dart';
import '../../utils/annee_scolaire.dart';
import '../../utils/validateurs.dart';
import 'espace_candidat_screen.dart';

/// US1 – Inscription d'un candidat.
///
/// Tous les champs sont obligatoires. Un message d'erreur s'affiche sous
/// chaque champ manquant ou incorrect. Un seul compte est possible
/// par couple Nom + Email (contrainte UNIQUE dans la base).
class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _adresseController = TextEditingController();
  Motivation? _motivation;

  String? _erreur;
  bool _chargement = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _sInscrire() async {
    setState(() => _erreur = null);

    // validate() lance tous les validateurs et affiche les erreurs
    if (!_formKey.currentState!.validate()) {
      setState(() => _erreur = 'Veuillez corriger les champs en rouge.');
      return;
    }

    setState(() => _chargement = true);

    final candidat = Candidat(
      nom: normaliserNom(_nomController.text),
      prenom: normaliserPrenom(_prenomController.text),
      email: normaliserEmail(_emailController.text),
      age: int.parse(_ageController.text.trim()),
      adresse: _adresseController.text.trim(),
      motivation: _motivation!,
      anneeScolaire: anneeScolaireActuelle(),
    );

    try {
      final id = await DatabaseService.instance.insertCandidat(candidat);
      if (!mounted) return;

      final cree = Candidat.fromMap({...candidat.toMap(), 'id': id});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte créé avec succès !')),
      );
      // On remplace l'écran d'inscription : le bouton retour ne doit pas
      // ramener au formulaire une fois le compte créé.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EspaceCandidatScreen(candidat: cree)),
      );
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.isUniqueConstraintError()
            ? 'Un compte existe déjà avec ce nom et cet email. '
                'Utilisez « J\'ai déjà un compte ».'
            : 'Erreur lors de l\'inscription, veuillez réessayer.';
      });
    }
  }

  InputDecoration _decoration(String label, IconData icone) => InputDecoration(
        labelText: '$label *',
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    const espace = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription candidat')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: _decoration('Nom', Icons.person),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => validerNom(v, champ: 'Le nom'),
                  ),
                  espace,
                  TextFormField(
                    controller: _prenomController,
                    decoration: _decoration('Prénom', Icons.person_outline),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => validerNom(v, champ: 'Le prénom'),
                  ),
                  espace,
                  TextFormField(
                    controller: _emailController,
                    decoration: _decoration('Email', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: validerEmail,
                  ),
                  espace,
                  TextFormField(
                    controller: _ageController,
                    decoration: _decoration('Âge', Icons.cake),
                    keyboardType: TextInputType.number,
                    validator: validerAge,
                  ),
                  espace,
                  TextFormField(
                    controller: _adresseController,
                    decoration: _decoration('Adresse postale', Icons.home),
                    maxLines: 2,
                    validator: validerAdresse,
                  ),
                  espace,
                  DropdownButtonFormField<Motivation>(
                    initialValue: _motivation,
                    decoration: _decoration('Motivation', Icons.flag),
                    items: [
                      for (final m in Motivation.values)
                        DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged: (m) => setState(() => _motivation = m),
                    validator: (m) =>
                        m == null ? 'La motivation est obligatoire.' : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* Champs obligatoires',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_erreur != null) ...[
                    espace,
                    Text(
                      _erreur!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _chargement ? null : _sInscrire,
                    child: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Créer mon compte'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
