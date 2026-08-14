import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Bloqueador da revisão final: quando a mesa some do stream porque o mestre
/// apagou (não porque só encerrou a sessão), o app precisa dizer a verdade —
/// "Esta mesa foi apagada." — e tirar a entrada morta da lista de mesas
/// conhecidas. Antes da correção, o app sempre dizia "A sessão foi
/// encerrada." (porque a mesa ainda estava em `conhecidas()`) e deixava uma
/// entrada morta na lista, que dava `MesaNaoEncontrada` ao tocar.
///
/// Mora sozinho no arquivo: grava no Hive de dentro do fake-async (mesmo
/// motivo dos outros `mesa_aba_*_test.dart`), e a escrita pendente trava o
/// `setUp` de qualquer teste que venha depois no mesmo processo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late MesaFake kaue;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba-apagada');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    // kaue já está dentro da mesa (membro de verdade no mundo compartilhado)
    // e o aparelho dele já lembra dela — exatamente o estado de quem está
    // com a tela aberta quando o mestre apaga a mesa por fora.
    kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    await MesaStore.entrar(EstadoMesa(
      mesaId: mesaId,
      nome: 'Sombras',
      uid: 'u-kaue',
      papel: PapelMesa.jogador,
    ));
    await MesaStore.lembrar(MesaConhecida(
      mesaId: mesaId,
      nome: 'Sombras',
      papel: PapelMesa.jogador,
      meuNome: 'Kaue',
    ));
  });

  testWidgets('mesa apagada por fora esquece a mesa e avisa que foi apagada',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: kaue))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // dentro da mesa: o stream de observarMesa já está assinado
    expect(find.text('Sombras'), findsOneWidget);

    // o mestre apaga a mesa por fora — kaue nem sabe ainda
    await mestre.apagarMesa(mesaId);

    // o stream entrega o `null` da exclusão; `_tratarMesaSumida` chama
    // `entrarPorId` (acha `MesaNaoEncontrada`, a mesa é mesmo apagada) e só
    // então esquece a mesa e volta para a tela offline — duas escritas no
    // Hive em sequência (`esquecer` e `limpar`), cada uma pedindo sua
    // própria volta ao loop de verdade.
    await t.pump();
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Esta mesa foi apagada.'), findsOneWidget);
    expect(MesaStore.atual, isNull);
    expect(MesaStore.conhecidas().any((m) => m.mesaId == mesaId), isFalse);
    // sem entrada morta: a lista de "mesas conhecidas" some junto
    expect(find.text('Sombras'), findsNothing);
  });
}
