import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Achado menor da revisão final: `_voltarPara` era o único dos quatro
/// jeitos de entrar numa mesa que não esquecia a entrada quando ela batia
/// com `MesaNaoEncontrada` — tocar numa mesa já apagada (por fora, enquanto
/// o aparelho estava longe dela) deixava a entrada morta na lista para
/// sempre: tocar de novo sempre repetia o mesmo erro.
///
/// Mora sozinho no arquivo: `_voltarPara` grava no Hive de dentro do
/// fake-async, e a escrita pendente trava o `setUp` de qualquer teste que
/// venha depois no mesmo processo — mesmo motivo dos outros
/// `mesa_aba_*_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake kaue;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba-voltar-apagada');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');
    final mesaId = mesa.id;

    kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');
    // sai de novo: fica só como "mesa conhecida" na lista, não dentro dela
    await kaue.sair(mesaId);

    await MesaStore.lembrar(MesaConhecida(
      mesaId: mesaId,
      nome: 'Sombras',
      papel: PapelMesa.jogador,
      meuNome: 'Kaue',
    ));

    // a mesa foi apagada de verdade enquanto o aparelho de kaue estava longe
    await mestre.apagarMesa(mesaId);
  });

  testWidgets('tocar numa mesa conhecida já apagada esquece a entrada morta',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: kaue))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsOneWidget);

    await t.tap(find.text('Sombras'));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Não encontrei essa mesa'), findsOneWidget);
    expect(find.text('Sombras'), findsNothing);
    expect(MesaStore.conhecidas(), isEmpty);
  });
}
