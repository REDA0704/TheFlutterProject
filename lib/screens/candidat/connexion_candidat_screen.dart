import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../utils/validateurs.dart';
import 'espace_candidat_screen.dart';
import 'inscription_screen.dart';

/// US1 – Connexion d'un candidat déjà inscrit.
///
/// Le compte est retrouvé grâce au couple Nom + Email,
/// qui est unique dans la base.
class ConnexionCandidatScreen extends StatefulWidget {
  const ConnexionCandidatScreen({super.key});

  @override
  State<ConnexionCandidatScreen> createState() =>
      _ConnexionCandidatScreenState();
}

class _ConnexionCandidatScreenState extends State<ConnexionCandidatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  String? _erreur;
  bool _chargement = false;

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _chargement = true);

    final candidat = await DatabaseService.instance.connecterCandidat(
      normaliserNom(_nomController.text),
      normaliserEmail(_emailController.text),
    );

    if (!mounted) return;

    if (candidat == null) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucun compte ne correspond à ce nom et cet email.';
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => EspaceCandidatScreen(candidat: candidat)),
    );
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
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => validerObligatoire(v, champ: 'Le nom'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validerEmail,
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
