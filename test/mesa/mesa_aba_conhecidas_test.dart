import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Sozinho no arquivo: entrar grava no Hive de dentro do fake-async.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-conhecidas');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    // já esteve nesta mesa, mas não está dentro dela agora
    await MesaStore.lembrar(MesaConhecida(
        mesaId: mesaId,
        nome: 'Sombras',
        papel: PapelMesa.mestre,
        chave: chave));
  });

  testWidgets('fora de mesa, a mesa conhecida aparece para voltar', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsOneWidget);
    expect(find.text('Criar mesa'), findsOneWidget);
    expect(find.text('Entrar com código'), findsOneWidget);
  });

  // Achado da revisão final: a chave só existe na cabeça de quem anotou e em
  // `MesaConhecida.chave` — esquecer uma mesa em que a pessoa é mestre apaga
  // a chave em silêncio, e o texto antigo ("alguém precisa te passar o
  // código de novo") era falso para o mestre, que voltaria como jogador da
  // própria crônica. Não confirma o diálogo: só mostrar já basta para o
  // teste, e evita a escrita no Hive que `MesaStore.esquecer` faria.
  testWidgets(
      'esquecer mesa em que sou mestre avisa que a mestria some para sempre',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.byTooltip('Esquecer esta mesa'));
    await t.pump();

    expect(find.textContaining('perde a mestria'), findsOneWidget);

    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
  });

  group('apagar mesa: gate do nome', () {
    // Além do que o setUp de fora já prepara (mesa criada e conhecida), este
    // grupo entra na mesa: o gate do nome só aparece com a tela já dentro
    // dela. `MesaStore.entrar` aqui é seguro porque `setUp` roda fora do
    // fake-async — o mesmo motivo pelo qual o setUp de fora já grava.
    setUp(() async {
      await MesaStore.entrar(EstadoMesa(
        mesaId: mesaId,
        nome: 'Sombras',
        uid: 'u-mestre',
        papel: PapelMesa.mestre,
      ));
    });

    testWidgets(
        'só habilita quando o nome digitado bate exatamente com o da mesa',
        (t) async {
      await t.pumpWidget(
          MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.tap(find.byIcon(Icons.more_vert));
      await t.pumpAndSettle();
      await t.tap(find.text('Apagar mesa'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'nome errado');
      await t.pump();
      final desabilitado = t.widget<TextButton>(
          find.widgetWithText(TextButton, 'Apagar mesa'));
      expect(desabilitado.onPressed, isNull);

      await t.enterText(find.byType(TextField), 'Sombras');
      await t.pump();
      final habilitado = t.widget<TextButton>(
          find.widgetWithText(TextButton, 'Apagar mesa'));
      expect(habilitado.onPressed, isNotNull);

      // fecha o diálogo antes do teste terminar: deixá-lo aberto na volta
      // atrapalha o descarte do widget (e o Timer de presença dele) entre
      // testes
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
    });
  });

  // DAQUI PARA BAIXO: testes que gravam no Hive de dentro do fake-async (além
  // do que os setUp já gravam fora dele). A escrita fica pendente e trava o
  // setUp do teste seguinte, então ficam por último, sem ninguém depois.
  testWidgets('esquecer tira a mesa da lista', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.byTooltip('Esquecer esta mesa'));
    await t.pump();
    await t.tap(find.text('Esquecer'));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsNothing);
    expect(MesaStore.conhecidas(), isEmpty);
  });
}
