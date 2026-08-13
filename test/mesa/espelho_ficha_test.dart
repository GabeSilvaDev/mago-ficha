import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/espelho_ficha.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/models/ficha.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  /// Mesa criada dentro do tempo falso: sem isso o `then` nunca roda.
  (MesaFake, String) mesaFake(FakeAsync async) {
    final servico = MesaFake('u-kaue');
    servico.entrarAnonimo();
    late String mesaId;
    servico.criarMesa('Sombras', 'Kaue').then((m) => mesaId = m.id);
    async.flushMicrotasks();
    return (servico, mesaId);
  }

  test('rajada de toques vira uma escrita só', () {
    fakeAsync((async) {
      final (servico, mesaId) = mesaFake(async);

      final espelho = EspelhoFicha(servico);
      final f = Ficha.criar();
      f.data['nome'] = 'Cotoia';
      espelho.ligar(mesaId, f.id);

      // dez toques em menos de dois segundos
      for (var i = 0; i < 10; i++) {
        f.setEsfera('forces', i % 5);
        espelho.aoSalvar(f);
        async.elapse(const Duration(milliseconds: 100));
      }
      // ainda não enviou: a janela não fechou
      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));

      async.elapse(const Duration(seconds: 3));
      final publicada = servico.mundo.fichas[mesaId]!['u-kaue']!;
      expect(publicada.ficha['nome'], 'Cotoia');
      // o valor que foi para a nuvem é o ÚLTIMO, não o primeiro
      expect((publicada.ficha['esferas'] as Map)['forces'], 4);
    });
  });

  test('desligado não envia nada', () {
    fakeAsync((async) {
      final (servico, mesaId) = mesaFake(async);

      final espelho = EspelhoFicha(servico);
      final f = Ficha.criar();
      espelho.ligar(mesaId, f.id);
      espelho.desligar();

      espelho.aoSalvar(f);
      async.elapse(const Duration(seconds: 5));

      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));
    });
  });

  test('só espelha a ficha publicada, não as outras', () {
    fakeAsync((async) {
      final (servico, mesaId) = mesaFake(async);

      final espelho = EspelhoFicha(servico);
      final publicada = Ficha.criar();
      final outra = Ficha.criar();
      outra.data['nome'] = 'Outra';
      espelho.ligar(mesaId, publicada.id);

      espelho.aoSalvar(outra);
      async.elapse(const Duration(seconds: 5));

      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));
    });
  });
}
