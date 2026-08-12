import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/widgets/dots.dart';

void main() {
  test('fileira de até 5 mantém a bolinha grande', () {
    expect(LinhaBolinhas.tamanhoDe(5), 20);
    expect(LinhaBolinhas.espacoDe(5), 2);
  });

  test('fileira de 10 encolhe a bolinha para caber no celular', () {
    expect(LinhaBolinhas.tamanhoDe(10), 14);
    expect(LinhaBolinhas.espacoDe(10), 1);
    // largura total = max * (tamanho + 2 * espaco)
    final larg10 =
        10 * (LinhaBolinhas.tamanhoDe(10) + 2 * LinhaBolinhas.espacoDe(10));
    final larg5 =
        5 * (LinhaBolinhas.tamanhoDe(5) + 2 * LinhaBolinhas.espacoDe(5));
    expect(larg10, lessThan(larg5 * 1.4));
  });

  testWidgets('desenha uma bolinha por ponto do teto', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LinhaBolinhas(valor: 7, max: 10, onChanged: (_) {}),
      ),
    ));
    expect(find.byType(Container), findsNWidgets(10));
  });
}
