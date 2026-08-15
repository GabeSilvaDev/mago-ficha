import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Bloqueador novo, achado pela re-revisão de `_tratarMesaSumida`: a sonda
/// (`entrarPorId`) grava o registro de membro ANTES de conseguir ler a mesa
/// — é a ordem que a regra de segurança exige. Sem desfazer essa escrita,
/// quem o mestre removeu (`removerMembro`) reaparece sozinho na lista assim
/// que o app dele roda a checagem de "a mesa sumiu": o mestre precisaria
/// remover duas vezes. A correção chama `_servico.sair` depois de um
/// `entrarPorId` bem-sucedido, desfazendo o recadastro.
///
/// O `MesaFake` não tem, pela API pública, um jeito de simular o
/// `permission-denied` transitório que um `removerMembro` provoca de
/// verdade num listener já aberto sem que a mesa saia de `mundo.mesas` —
/// mesma limitação (e mesmo contorno) de `mesa_aba_sessao_encerrada_test.dart`.
///
/// Mora sozinho no arquivo: grava no Hive de dentro do fake-async, mesmo
/// motivo dos outros `mesa_aba_*_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late MesaFake kaue;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba-removido');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

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

  testWidgets(
      'removido pelo mestre não se recadastra sozinho ao rodar a sonda',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: kaue))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sombras'), findsOneWidget);

    // o mestre remove kaue da mesa
    await mestre.removerMembro(mesaId, 'u-kaue');

    // simula o permission-denied que o listener de kaue sofreria de
    // verdade em produção (a mesa nunca sai de `mundo.mesas` — só o
    // registro de membro dele sumiu, o mesmo contorno usado em
    // mesa_aba_sessao_encerrada_test.dart).
    final mesaViva = mestre.mundo.mesas[mesaId]!;
    mestre.mundo.mesas.remove(mesaId);
    mestre.mundo.notificar(mesaId);
    mestre.mundo.mesas[mesaId] = mesaViva;

    await t.pump();
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('A sessão foi encerrada.'), findsOneWidget);

    // o ponto do teste: kaue não pode reaparecer entre os membros só porque
    // a sonda rodou por baixo dos panos
    final membros = await mestre.observarMembros(mesaId).first;
    expect(membros.any((m) => m.uid == 'u-kaue'), isFalse);
  });
}
