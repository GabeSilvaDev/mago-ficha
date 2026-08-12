import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  test('as nove Esferas trazem lista de especialidades do livro', () {
    expect(GameData.esferas.length, 9);
    for (final e in GameData.esferas) {
      expect(e.especialidades, isNotEmpty,
          reason: 'Esfera ${e.nome} sem especialidades');
    }
    final corresp = GameData.esferaPorChave('correspondence')!;
    expect(corresp.especialidades, contains('Teleportes'));
    final entropia = GameData.esferaPorChave('entropy')!;
    expect(entropia.especialidades, contains('Necromancia'));
  });

  test('tetos: 5 no modo iniciante, 10 no modo livre', () {
    expect(GameData.esferasMaximo, 5);
    expect(GameData.esferasMaximoLivre, 10);
    expect(GameData.areteMaximo, 5);
    expect(GameData.areteMaximoLivre, 10);
    expect(GameData.esferasMax(false), 5);
    expect(GameData.esferasMax(true), 10);
    expect(GameData.areteMax(false), 5);
    expect(GameData.areteMax(true), 10);
  });
}
