import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Bloqueador da revisão final, a outra metade: quando a mesa some do stream
/// mas o motivo foi `encerrarSessao` (reversível — a mesa continua de pé),
/// `_tratarMesaSumida` precisa manter a entrada em "mesas conhecidas" e
/// avisar "A sessão foi encerrada.", não destruir a entrada como se fosse
/// `apagarMesa`.
///
/// O `MesaFake` não tem um jeito de simular, pela API pública, um
/// `permission-denied` transitório num listener já aberto sem que a mesa
/// realmente saia de `mundo.mesas` (é exatamente a folga que o item F da
/// revisão apontou, e corrigir isso de verdade pediria redesenhar como o
/// `MundoFake` entrega eventos por uid — fora do que foi pedido aqui). Este
/// teste reproduz o efeito observável — o stream entrega um `null` sem que a
/// mesa tenha sumido de verdade — mexendo direto em `mundo.mesas`, os mesmos
/// campos públicos que outros testes deste arquivo já usam
/// (`mesa_fake_test.dart` acessa `mundo.galeria`, por exemplo).
///
/// Mora sozinho no arquivo pelo mesmo motivo dos outros `mesa_aba_*_test.dart`:
/// grava no Hive de dentro do fake-async.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late MesaFake kaue;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba-sessao-encerrada');
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
      'sessão encerrada por fora mantém a mesa conhecida e avisa "sessão encerrada"',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: kaue))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sombras'), findsOneWidget);

    // simula o stream perdendo a mesa (o `permission-denied` que
    // `encerrarSessao` provoca de verdade quando o registro de membro some)
    // SEM que a mesa tenha sumido de verdade — ela volta antes de
    // `_tratarMesaSumida` chegar a chamar `entrarPorId`.
    final mesaViva = mestre.mundo.mesas[mesaId]!;
    mestre.mundo.mesas.remove(mesaId);
    mestre.mundo.notificar(mesaId);
    mestre.mundo.mesas[mesaId] = mesaViva;

    // `entrarPorId` acha a mesa de pé (readmite kaue como membro) — só uma
    // escrita no Hive depois disso (`MesaStore.limpar`, dentro de
    // `_voltarParaOffline`; sem `MesaStore.esquecer`, porque a mesa não foi
    // apagada).
    await t.pump();
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('A sessão foi encerrada.'), findsOneWidget);
    expect(MesaStore.atual, isNull);
    // a mesa CONTINUA na lista de mesas conhecidas — reversível
    expect(MesaStore.conhecidas().any((m) => m.mesaId == mesaId), isTrue);
    expect(find.text('Sombras'), findsOneWidget);
  });
}
