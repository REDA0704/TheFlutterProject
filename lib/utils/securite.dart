import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe (compte administrateur, US4).
///
/// Un mot de passe n'est jamais stocké en clair : on enregistre
/// SHA-256(sel + mot de passe) et le sel. Le sel est aléatoire et propre
/// à chaque compte : deux comptes avec le même mot de passe n'ont donc
/// pas le même hash.

/// Génère un sel aléatoire (16 octets, encodés en base64).
String genererSel() {
  final aleatoire = Random.secure();
  final octets = List<int>.generate(16, (_) => aleatoire.nextInt(256));
  return base64Url.encode(octets);
}

/// Calcule le hash SHA-256 du mot de passe avec son sel (en hexadécimal).
String hacherMotDePasse(String motDePasse, String sel) {
  return sha256.convert(utf8.encode('$sel$motDePasse')).toString();
}

/// Vérifie un mot de passe saisi par rapport au hash enregistré.
bool verifierMotDePasse(String saisi, String sel, String hashAttendu) {
  return hacherMotDePasse(saisi, sel) == hashAttendu;
}
