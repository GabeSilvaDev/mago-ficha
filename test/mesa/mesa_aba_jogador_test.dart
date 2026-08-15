import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Este teste mora sozinho num arquivo: ele grava no Hive de dentro do
/// fake-async, e a escrita pendente trava qualquer teste que venha depois no
/// mesmo processo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba-jogador');
    await MesaStore.init();
  });

  setUp(() async => Hive.box<String>(MesaStore.boxName).clear());

  /// A tela mantém um Timer de presença; sem avançar o tempo na mão o teste
  /// acusa timer pendente.
  Future<void> assentar(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Toque que grava no Hive — entrar grava o estado atual e a mesa
  /// conhecida, duas escritas em sequência. `runAsync` devolve uma volta ao
  /// loop de verdade: sem isso a gravação fica pendente e a tela não sai do
  /// "carregando"; uma só rodada não é suficiente para as duas escritas.
  Future<void> tocarGravando(WidgetTester t, Finder alvo) async {
    await t.tap(alvo);
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await assentar(t);
  }

  Future<void> abrir(WidgetTester t, MesaFake servico) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: servico))));
    await assentar(t);
  }

  testWidgets('jogador não vê as ações de mestre', (t) async {
    final dono = MesaFake('u-mestre');
    await dono.entrarAnonimo();
    final (mesa, _) = await dono.criarMesa('Sombras', 'Gabriel');

    await abrir(t, MesaFake('u-kaue', mundo: dono.mundo));

    await t.tap(find.text('Entrar com código'));
    await assentar(t);
    await t.enterText(find.byType(TextField).first, mesa.codigo);
    await tocarGravando(t, find.widgetWithText(TextButton, 'Entrar'));

    expect(find.text('Sombras'), findsOneWidget);
    expect(find.byTooltip('Trocar código'), findsNothing);
    expect(find.text('Encerrar sessão'), findsNothing);
    // mural, galeria e cartão da ficha empurram o rodapé para fora do que a
    // lista constrói sem rolar de verdade
    await t.drag(find.byType(ListView), const Offset(0, -2000));
    await assentar(t);
    expect(find.text('Sair da mesa'), findsOneWidget);
    // vê os dois membros, com os papéis certos
    expect(find.text('mestre'), findsOneWidget);
    expect(find.text('jogador'), findsOneWidget);
  });
}
