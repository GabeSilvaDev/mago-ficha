import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/ficha_view_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Ficha ficha;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-view');
    await Hive.openBox<String>(FichaStore.boxName);
    await NarradorStore.init();
  });

  // A ficha é gravada FORA do `testWidgets`: escrita de disco não completa
  // dentro do fake-async do teste de widget e a suíte trava esperando.
  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    ficha = Ficha.criar();
    ficha.data['nome'] = 'Cassandra Vex';
    ficha.setEsfera('correspondence', 7);
    ficha.addEspecEsfera('correspondence', 'Teleportes');
    await FichaStore.salvar(ficha);
  });

  testWidgets('cancelar não exclui', (tester) async {
    await tester.pumpWidget(MaterialApp(home: FichaViewScreen(fichaId: ficha.id)));
    await tester.pump();

    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Excluir ficha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(FichaStore.porId(ficha.id), isNotNull);
  });

  testWidgets('Esfera acima de 5 mostra a especialização na aba Esferas',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FichaViewScreen(fichaId: ficha.id)));
    await tester.pump();

    await tester.tap(find.text('Esferas'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Teleportes'), findsOneWidget);
  });

  // ÚLTIMO DO ARQUIVO DE PROPÓSITO: excluir dispara escrita real de disco de
  // dentro do fake-async do teste de widget. A operação fica pendente e trava
  // o `setUp` do teste seguinte — com este por último, não há teste seguinte.
  testWidgets('dá para excluir a ficha pela própria tela', (tester) async {
    // NPC só é alcançável pela galeria, que abre esta tela: sem exclusão aqui,
    // não existe jeito de apagar um NPC.
    expect(FichaStore.porId(ficha.id), isNotNull);

    await tester.pumpWidget(MaterialApp(home: FichaViewScreen(fichaId: ficha.id)));
    await tester.pump();

    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Excluir ficha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pump();
    // o excluir dispara escrita real de disco de dentro do fake-async; sem
    // deixar a I/O terminar, ela fica pendente e trava o teste seguinte
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(FichaStore.porId(ficha.id), isNull);
  });
}
