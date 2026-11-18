import 'package:flutter_test/flutter_test.dart';
import 'package:the_flutter_project/utils/annee_scolaire.dart';
import 'package:the_flutter_project/utils/validateurs.dart';

void main() {
  group('validerNom', () {
    test('refuse un champ vide', () {
      expect(validerNom(''), isNotNull);
      expect(validerNom('   '), isNotNull);
      expect(validerNom(null), isNotNull);
    });
    test('refuse les chiffres', () => expect(validerNom('Dupont2'), isNotNull));
    test('accepte accents, tirets et apostrophes', () {
      expect(validerNom('Hélène'), isNull);
      expect(validerNom('Jean-Pierre'), isNull);
      expect(validerNom("N'Diaye"), isNull);
    });
  });

  group('validerEmail', () {
    test('accepte un email correct', () {
      expect(validerEmail('jean.dupont@mail.com'), isNull);
    });
    test('refuse un email incorrect', () {
      expect(validerEmail('jean.dupont'), isNotNull);
      expect(validerEmail('jean@'), isNotNull);
      expect(validerEmail(''), isNotNull);
    });
  });

  group('validerAge', () {
    test('refuse ce qui n\'est pas un nombre', () {
      expect(validerAge('vingt'), isNotNull);
    });
    test('refuse hors limites', () {
      expect(validerAge('${ageMin - 1}'), isNotNull);
      expect(validerAge('${ageMax + 1}'), isNotNull);
    });
    test('accepte un âge correct', () => expect(validerAge('25'), isNull));
  });

  test('validerAdresse refuse une adresse vide ou trop courte', () {
    expect(validerAdresse(''), isNotNull);
    expect(validerAdresse('abc'), isNotNull);
    expect(validerAdresse('12 rue de la Paix, Paris'), isNull);
  });

  test('normalisation pour la contrainte Nom + Email', () {
    expect(normaliserNom('  dupont '), 'DUPONT');
    expect(normaliserPrenom('jean'), 'Jean');
    expect(normaliserEmail(' Jean.Dupont@Mail.COM '), 'jean.dupont@mail.com');
  });

  group('anneeScolaire', () {
    test('septembre à décembre', () {
      expect(anneeScolaire(DateTime(2025, 9, 1)), '2025-2026');
      expect(anneeScolaire(DateTime(2025, 12, 31)), '2025-2026');
    });
    test('janvier à août', () {
      expect(anneeScolaire(DateTime(2026, 1, 1)), '2025-2026');
      expect(anneeScolaire(DateTime(2026, 8, 31)), '2025-2026');
    });
  });
}
