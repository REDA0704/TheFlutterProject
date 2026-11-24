import 'package:flutter/material.dart';

import '../../models/candidat.dart';
import '../../services/database_service.dart';
import '../../utils/limiteur_tentatives.dart';
import '../../utils/validateurs.dart';
import 'espace_candidat_screen.dart';
import 'inscription_screen.dart';

/// US1 – Connexion d'un candidat déjà inscrit, avec son email
/// (unique) et son mot de passe.
///
/// Après 5 mots de passe faux, la connexion est bloquée 30 secondes.
class ConnexionCandidatScreen extends StatefulWidget {
  const ConnexionCandidatScreen({super.key});

  // Partagé entre les ouvertures de l'écran : fermer et rouvrir la page
  // ne remet pas le compteur à zéro.
  static final limiteur = LimiteurTentatives();

  @override
  State<ConnexionCandidatScreen> createState() =>
      _ConnexionCandidatScreenState();
}

class _ConnexionCandidatScreenState extends State<ConnexionCandidatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _motDePasseController = TextEditingController();
  String? _erreur;
  bool _chargement = false;
  bool _masquer = true;

  LimiteurTentatives get _limiteur => ConnexionCandidatScreen.limiteur;

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;

    final email = normaliserEmail(_emailController.text);
    final bloque = _limiteur.tempsRestant(email);
    if (bloque != null) {
      setState(() => _erreur = LimiteurTentatives.message(bloque));
      return;
    }

    setState(() => _chargement = true);
    Candidat? candidat;
    try {
      candidat = await DatabaseService.instance
          .connecterCandidat(email, _motDePasseController.text);
    } on CompteSansMotDePasse {
      if (!mounted) return;
      setState(() => _chargement = false);
      candidat = await _definirMotDePasse(email);
      if (candidat == null) return;
    }

    if (!mounted) return;

    if (candidat == null) {
      _limiteur.echec(email);
      setState(() {
        _chargement = false;
        _erreur = 'Email ou mot de passe incorrect.';
      });
      return;
    }

    _limiteur.succes(email);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => EspaceCandidatScreen(candidat: candidat!)),
    );
  }

  /// Compte créé avant l'ajout des mots de passe : le candidat confirme
  /// son nom, et le mot de passe saisi devient son mot de passe.
  Future<Candidat?> _definirMotDePasse(String email) async {
    final motDePasse = _motDePasseController.text;
    final erreurMdp = validerMotDePasse(motDePasse);
    if (erreurMdp != null) {
      setState(() => _erreur = 'Ce compte n\'a pas encore de mot de passe. '
          'Saisissez-en un nouveau : $erreurMdp');
      return null;
    }

    final nomController = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Définir votre mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Votre compte a été créé avant l\'ajout des mots de passe. '
              'Pour confirmer votre identité, saisissez le nom utilisé '
              'à l\'inscription. Le mot de passe saisi deviendra le vôtre.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nomController.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    nomController.dispose();
    if (nom == null || !mounted) return null;

    final candidat = await DatabaseService.instance.definirMotDePasseCandidat(
      email: email,
      nom: normaliserNom(nom),
      motDePasse: motDePasse,
    );
    if (candidat == null && mounted) {
      _limiteur.echec(email);
      setState(() => _erreur = 'Le nom ne correspond pas à ce compte.');
    }
    return candidat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espace candidat')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Connexion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validerEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _motDePasseController,
                    obscureText: _masquer,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _masquer ? 'Afficher' : 'Masquer',
                        icon: Icon(
                          _masquer ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _masquer = !_masquer),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Le mot de passe est obligatoire.'
                        : null,
                    onFieldSubmitted: (_) => _seConnecter(),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _erreur!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _chargement ? null : _seConnecter,
                    child: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InscriptionScreen(),
                      ),
                    ),
                    child: const Text('Pas encore de compte ? S\'inscrire'),
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
