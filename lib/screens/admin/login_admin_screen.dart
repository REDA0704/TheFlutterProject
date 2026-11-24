import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../utils/limiteur_tentatives.dart';
import 'changer_mot_de_passe_screen.dart';
import 'dashboard_admin_screen.dart';

/// US4 – Connexion avec le compte administrateur pré-existant.
///
/// - 5 mots de passe faux de suite : connexion bloquée 30 secondes.
/// - Mot de passe par défaut : changement obligatoire avant d'entrer.
class LoginAdminScreen extends StatefulWidget {
  const LoginAdminScreen({super.key});

  static final limiteur = LimiteurTentatives();

  @override
  State<LoginAdminScreen> createState() => _LoginAdminScreenState();
}

class _LoginAdminScreenState extends State<LoginAdminScreen> {
  final _loginController = TextEditingController();
  final _motDePasseController = TextEditingController();
  String? _erreur;
  bool _chargement = false;

  @override
  void dispose() {
    _loginController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final login = _loginController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (login.isEmpty || motDePasse.isEmpty) {
      setState(() => _erreur = 'Veuillez remplir tous les champs.');
      return;
    }

    final limiteur = LoginAdminScreen.limiteur;
    final bloque = limiteur.tempsRestant(login);
    if (bloque != null) {
      setState(() => _erreur = LimiteurTentatives.message(bloque));
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final ok = await DatabaseService.instance.verifierAdmin(login, motDePasse);

    // Si l'écran a été fermé pendant l'attente, on ne fait rien
    if (!mounted) return;

    if (ok) {
      limiteur.succes(login);
      final parDefaut = motDePasse == DatabaseService.adminMotDePasseParDefaut;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => parDefaut
              ? ChangerMotDePasseScreen(login: login, obligatoire: true)
              : DashboardAdminScreen(login: login),
        ),
      );
    } else {
      limiteur.echec(login);
      setState(() {
        _chargement = false;
        _erreur = 'Identifiant ou mot de passe incorrect.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion administrateur')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _motDePasseController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _seConnecter(),
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erreur!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _chargement ? null : _seConnecter,
                    child: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}