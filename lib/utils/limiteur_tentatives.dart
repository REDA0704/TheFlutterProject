/// Limite les essais de connexion (admin et candidat).
///
/// Après [maxEchecs] mots de passe faux de suite pour un même identifiant,
/// la connexion est bloquée pendant [dureeBlocage]. Cela empêche d'essayer
/// des milliers de mots de passe à la suite.
class LimiteurTentatives {
  LimiteurTentatives({
    this.maxEchecs = 5,
    this.dureeBlocage = const Duration(seconds: 30),
    DateTime Function()? horloge,
  }) : _maintenant = horloge ?? DateTime.now;

  final int maxEchecs;
  final Duration dureeBlocage;
  final DateTime Function() _maintenant;

  final Map<String, int> _echecs = {};
  final Map<String, DateTime> _bloqueJusqua = {};

  /// Temps d'attente restant pour [cle], ou null si la connexion est permise.
  Duration? tempsRestant(String cle) {
    final fin = _bloqueJusqua[cle];
    if (fin == null) return null;
    final reste = fin.difference(_maintenant());
    if (reste <= Duration.zero) {
      _bloqueJusqua.remove(cle);
      return null;
    }
    return reste;
  }

  /// À appeler après un mot de passe faux.
  void echec(String cle) {
    final n = (_echecs[cle] ?? 0) + 1;
    if (n >= maxEchecs) {
      _echecs.remove(cle);
      _bloqueJusqua[cle] = _maintenant().add(dureeBlocage);
    } else {
      _echecs[cle] = n;
    }
  }

  /// À appeler après une connexion réussie : le compteur repart à zéro.
  void succes(String cle) {
    _echecs.remove(cle);
    _bloqueJusqua.remove(cle);
  }

  /// Message à afficher quand la connexion est bloquée.
  static String message(Duration reste) =>
      'Trop d\'essais incorrects. Réessayez dans ${reste.inSeconds + 1} s.';
}
