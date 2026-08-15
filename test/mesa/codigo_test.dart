import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/codigo.dart';

void main() {
  test('formato MAGO-XXXX', () {
    for (var i = 0; i < 50; i++) {
      final c = CodigoMesa.gerar();
      expect(RegExp(r'^MAGO-[A-Z0-9]{4}$').hasMatch(c), isTrue, reason: c);
    }
  });

  test('alfabeto não tem caractere ambíguo (o código é ditado em voz alta)',
      () {
    for (final proibido in ['O', '0', 'I', '1', 'L', 'S', '5']) {
      expect(CodigoMesa.alfabeto, isNot(contains(proibido)));
    }
  });

  test('alfabeto não repete caractere', () {
    expect(CodigoMesa.alfabeto.split('').toSet().length,
        CodigoMesa.alfabeto.length);
  });

  test('normalizar aceita o que a pessoa digita de verdade', () {
    expect(CodigoMesa.normalizar('mago-4k7p'), 'MAGO-4K7P');
    expect(CodigoMesa.normalizar(' MAGO 4K7P '), 'MAGO-4K7P');
    expect(CodigoMesa.normalizar('4k7p'), 'MAGO-4K7P'); // só a parte variável
    expect(CodigoMesa.normalizar('MAGO4K7P'), 'MAGO-4K7P');
  });

  test('valido rejeita o que não dá para existir', () {
    expect(CodigoMesa.valido(CodigoMesa.gerar()), isTrue);
    expect(CodigoMesa.valido('MAGO-4K7'), isFalse); // curto
    expect(CodigoMesa.valido('MAGO-4K7PP'), isFalse); // longo
    expect(CodigoMesa.valido('MAGO-4K7O'), isFalse); // letra fora do alfabeto
    expect(CodigoMesa.valido(''), isFalse);
  });

  test('gera códigos diferentes', () {
    final vistos = {for (var i = 0; i < 200; i++) CodigoMesa.gerar()};
    expect(vistos.length, greaterThan(190)); // colisão é rara, não impossível
  });
}
