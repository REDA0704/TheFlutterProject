import 'package:flutter_test/flutter_test.dart';

import 'package:the_flutter_project/main.dart';

void main() {
  testWidgets('L\'accueil mène à la connexion candidat', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.tap(find.text('Espace candidat'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Pas encore de compte ? S\'inscrire'), findsOneWidget);
  });

  testWidgets('Inscription : erreurs si les champs sont vides', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Espace candidat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pas encore de compte ? S\'inscrire'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    expect(find.text('L\'email est obligatoire.'), findsOneWidget);
    expect(find.text('La motivation est obligatoire.'), findsOneWidget);
    expect(find.text('Veuillez corriger les champs en rouge.'), findsOneWidget);
  });
}
