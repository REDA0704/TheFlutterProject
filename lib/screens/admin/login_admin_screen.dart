import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import 'dashboard_admin_screen.dart';

class LoginAdminScreen extends StatefulWidget {
  const LoginAdminScreen({super.key});

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

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final ok = await DatabaseService.instance.verifierAdmin(login, motDePasse);

    // Si l'écran a été fermé pendant l'attente, on ne fait rien
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardAdminScreen()),
      );
    } else {
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