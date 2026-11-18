import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_flutter_project/models/question.dart';
import 'package:the_flutter_project/screens/admin/questions/question_form_screen.dart';

Widget _app(Widget ecran) => MaterialApp(home: ecran);

void main() {
  testWidgets('Formulaire vide : erreurs affichées', (tester) async {
    await tester.pumpWidget(_app(const QuestionFormScreen(discipline: 'Java')));

    expect(find.text('Nouvelle question – Java'), findsOneWidget);
    expect(find.text('Réponse 1'), findsOneWidget);
    expect(find.text('Réponse 2'), findsOneWidget);

    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('L\'énoncé est obligatoire.'), findsOneWidget);
    expect(find.text('Réponse vide.'), findsNWidgets(2));
  });

  testWidgets('Sans bonne réponse cochée : message d\'erreur', (tester) async {
    await tester.pumpWidget(_app(const QuestionFormScreen(discipline: 'Java')));

    await tester.enterText(find.widgetWithText(TextFormField, 'Énoncé de la question *'), 'Q ?');
    await tester.enterText(find.widgetWithText(TextFormField, 'Réponse 1'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Réponse 2'), 'B');

    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Indiquez au moins une bonne réponse.'), findsOneWidget);
  });

  testWidgets('Modification : la question existante est pré-remplie',
      (tester) async {
    final q = Question(
      id: 1,
      discipline: 'Algo',
      enonce: 'Complexité de la recherche dichotomique ?',
      type: TypeQuestion.checkbox,
      options: ['O(n)', 'O(log n)', 'O(1)'],
      bonnesReponses: [1],
      tempsLimite: 25,
    );
    await tester.pumpWidget(
      _app(QuestionFormScreen(discipline: 'Algo', question: q)),
    );

    expect(find.text('Modifier la question'), findsOneWidget);
    expect(find.text(q.enonce), findsOneWidget);
    expect(find.text('O(log n)'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Cochez TOUTES les bonnes réponses.'), findsOneWidget);

    // Passage en choix unique
    await tester.tap(find.text('Choix unique'));
    await tester.pumpAndSettle();
    expect(find.text('Sélectionnez LA bonne réponse.'), findsOneWidget);
  });

  testWidgets('Ajout et suppression de réponses', (tester) async {
    await tester.pumpWidget(_app(const QuestionFormScreen(discipline: 'Java')));

    // Avec 2 réponses, on ne peut pas en supprimer
    final supprimer = find.widgetWithIcon(IconButton, Icons.close);
    expect(tester.widget<IconButton>(supprimer.first).onPressed, isNull);

    await tester.ensureVisible(find.text('Ajouter une réponse'));
    await tester.tap(find.text('Ajouter une réponse'));
    await tester.pumpAndSettle();
    expect(find.text('Réponse 3'), findsOneWidget);

    await tester.tap(supprimer.last);
    await tester.pumpAndSettle();
    expect(find.text('Réponse 3'), findsNothing);
  });
}
