import 'package:flutter_test/flutter_test.dart';
import 'package:the_flutter_project/screens/candidat/passer_test_screen.dart';

void main() {
  test('Correction : une réponse unique', () {
    expect(reponseCorrecte({0}, [0]), isTrue);
    expect(reponseCorrecte({1}, [0]), isFalse);
  });
  test('Correction : réponses multiples exactes', () {
    expect(reponseCorrecte({2, 0}, [0, 2]), isTrue);
    expect(reponseCorrecte({0}, [0, 2]), isFalse);
    expect(reponseCorrecte({0, 1, 2}, [0, 2]), isFalse);
    expect(reponseCorrecte(<int>{}, [0]), isFalse);
  });
}
