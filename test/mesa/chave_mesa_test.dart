import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/chave_mesa.dart';

void main() {
  test('gera no formato MAGO-XXXX-XXXX', () {
    final c = ChaveMesa.gerar();
    expect(ChaveMesa.valida(c), isTrue);
    expect(c, startsWith('MAGO-'));
    expect(c.length, 'MAGO-XXXX-XXXX'.length);
  });

  test('duas chaves seguidas não são iguais', () {
    expect(ChaveMesa.gerar(), isNot(ChaveMesa.gerar()));
  });

  test('normalizar aceita o que a pessoa digita', () {
    expect(ChaveMesa.normalizar(' mago-k7qw-3xzp '), 'MAGO-K7QW-3XZP');
    expect(ChaveMesa.normalizar('k7qw3xzp'), 'MAGO-K7QW-3XZP');
    expect(ChaveMesa.normalizar('K7QW-3XZP'), 'MAGO-K7QW-3XZP');
  });

  test('chave curta ou com letra fora do alfabeto é inválida', () {
    expect(ChaveMesa.valida('MAGO-K7QW-3XZ'), isFalse);
    expect(ChaveMesa.valida('MAGO-K7QW-3XZI'), isFalse); // I não está no alfabeto
    expect(ChaveMesa.valida(''), isFalse);
  });
}
