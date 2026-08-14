import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Mora sozinho num arquivo: `_voltarPara` grava no Hive de dentro do
/// fake-async, e a escrita pendente trava o `setUp` de qualquer teste que
/// venha depois no mesmo processo — mesmo motivo de `mesa_aba_jogador_test.dart`.
/// Combinar este teste com os outros de `mesa_aba_conhecidas_test.dart` num
/// só arquivo (testado durante o desenvolvimento) deixou a suíte instável
/// nesta imagem Docker — vários widgets `MesaAba` com Timer de presença
/// ativo, criados e descartados em sequência no mesmo processo, chegaram a
/// travar o `flutter test` por minutos. Isolado, roda em menos de um segundo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-conhecidas-voltar');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    // já esteve nesta mesa, mas não está dentro dela agora. `meuNome` é o
    // nome que a pessoa usa NESTA mesa — de propósito diferente do nome da
    // mesa ('Sombras'), para o teste abaixo não passar por acidente.
    await MesaStore.lembrar(MesaConhecida(
        mesaId: mesaId,
        nome: 'Sombras',
        papel: PapelMesa.mestre,
        chave: chave,
        meuNome: 'Gabriel'));
  });

  testWidgets('tocar na mesa conhecida volta para dentro dela', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.text('Sombras'));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // dentro da mesa: o botão de criar/entrar (tela "fora de mesa") some, e
    // "quem está na mesa" mostra o mestre — exatamente o que _voltarPara
    // promete, e o teste que teria pego o mestre sendo rebaixado a jogador
    // ao voltar (achado da revisão: `entrarPorId` decidia o papel pelo
    // registro antigo, que `encerrarSessao` apaga por completo)
    expect(find.text('Criar mesa'), findsNothing);
    expect(find.text('mestre'), findsOneWidget);
    expect(MesaStore.atual, isNotNull);
    expect(MesaStore.atual!.papel, PapelMesa.mestre);

    // "quem está na mesa" mostra o nome que a pessoa usa aqui
    // (MesaConhecida.meuNome), não o nome da mesa — achado da revisão:
    // _voltarPara mandava `m.nome` (o da MESA) como se fosse o da pessoa, e
    // quem voltava pela lista aparecia renomeado com o nome da própria mesa
    expect(find.text('Gabriel'), findsOneWidget);
  });
}
