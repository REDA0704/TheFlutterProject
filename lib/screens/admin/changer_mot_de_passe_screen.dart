import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../utils/validateurs.dart';
import 'dashboard_admin_screen.dart';

/// US4 – Changement du mot de passe administrateur.
///
/// [obligatoire] : première connexion avec le mot de passe par défaut
/// (`admin123`, connu de tous). L'admin doit le changer avant d'accéder
/// à l'espace d'administration.
class ChangerMotDePasseScreen extends StatefulWidget {
  const ChangerMotDePasseScreen({
    super.key,
    required this.login,
    this.obligatoire = false,
  });

  final String login;
  final bool obligatoire;

  @override
  State<ChangerMotDePasseScreen> createState() =>
      _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState extends State<ChangerMotDePasseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  String? _erreur;
  bool _chargement = false;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);

    final ok = await DatabaseService.instance.changerMotDePasseAdmin(
      login: widget.login,
      ancien: _ancien.text,
      nouveau: _nouveau.text,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _chargement = false;
        _erreur = 'Mot de passe actuel incorrect.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe modifié.')),
    );
    if (widget.obligatoire) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardAdminScreen(login: widget.login),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const espace = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.obligatoire) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Vous utilisez le mot de passe par défaut. Pour '
                          'protéger les données des candidats, choisissez '
                          'un nouveau mot de passe.',
                        ),
                      ),
                    ),
                    espace,
                  ],
                  TextFormField(
                    controller: _ancien,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Saisissez le mot de passe actuel.'
                        : null,
                  ),
                  espace,
                  TextFormField(
                    controller: _nouveau,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      helperText: '8 caractères minimum, une lettre et un chiffre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final erreur = validerMotDePasse(v);
                      if (erreur != null) return erreur;
                      if (v == DatabaseService.adminMotDePasseParDefaut ||
                          v == _ancien.text) {
                        return 'Choisissez un mot de passe différent.';
                      }
                      return null;
                    },
                  ),
                  espace,
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => validerConfirmation(v, _nouveau.text),
                    onFieldSubmitted: (_) => _valider(),
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
                    onPressed: _chargement ? null : _valider,
                    child: const Text('Enregistrer'),
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
