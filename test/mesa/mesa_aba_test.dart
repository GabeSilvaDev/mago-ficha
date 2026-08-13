import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba');
    await MesaStore.init();
  });

  setUp(() async => Hive.box<String>(MesaStore.boxName).clear());

  /// A tela mantém um Timer de presença; sem avançar o tempo na mão o teste
  /// acusa timer pendente.
  Future<void> assentar(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Toque que grava no Hive. `runAsync` devolve uma volta ao loop de verdade:
  /// sem isso a gravação fica pendente e a tela não sai do "carregando".
  Future<void> tocarGravando(WidgetTester t, Finder alvo) async {
    await t.tap(alvo);
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

  testWidgets('sem mesa: oferece criar ou entrar', (t) async {
    await abrir(t, MesaFake('u1'));

    expect(find.text('Criar mesa'), findsOneWidget);
    expect(find.text('Entrar com código'), findsOneWidget);
    expect(find.textContaining('não está em nenhuma mesa'), findsOneWidget);
  });

  testWidgets('código inválido avisa e não entra', (t) async {
    await abrir(t, MesaFake('u1'));

    await t.tap(find.text('Entrar com código'));
    await assentar(t);
    await t.enterText(find.byType(TextField).first, 'MAGO-000');
    await tocarGravando(t, find.widgetWithText(TextButton, 'Entrar'));

    expect(find.text('Código inválido.'), findsOneWidget);
    expect(MesaStore.atual, isNull);
  });

  testWidgets('mesa que não existe mostra recado, não quebra', (t) async {
    await abrir(t, MesaFake('u1'));

    await t.tap(find.text('Entrar com código'));
    await assentar(t);
    await t.enterText(find.byType(TextField).first, 'MAGO-ZZZZ');
    await tocarGravando(t, find.widgetWithText(TextButton, 'Entrar'));

    expect(find.textContaining('Não encontrei essa mesa'), findsOneWidget);
    expect(MesaStore.atual, isNull);
  });

  // DAQUI PARA BAIXO: testes que gravam no Hive de dentro do fake-async. A
  // escrita fica pendente e trava o `setUp` do teste seguinte, então eles
  // ficam no fim do arquivo, sem ninguém depois.
  testWidgets('criar mesa mostra o código e me lista como mestre', (t) async {
    await abrir(t, MesaFake('u1'));

    await t.tap(find.text('Criar mesa'));
    await assentar(t);
    await t.enterText(find.byType(TextField).first, 'Sombras de SP');
    await tocarGravando(t, find.widgetWithText(TextButton, 'Criar'));

    expect(find.text('Sombras de SP'), findsOneWidget);
    expect(find.textContaining('MAGO-'), findsOneWidget);
    expect(find.text('mestre'), findsOneWidget);
    expect(find.byTooltip('Trocar código'), findsOneWidget);
    expect(find.text('Fechar mesa'), findsOneWidget);
  });
}
