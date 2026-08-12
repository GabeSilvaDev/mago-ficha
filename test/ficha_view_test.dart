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

  testWidgets('Esfera acima de 5 mostra a especialização na aba Esferas',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FichaViewScreen(fichaId: ficha.id)));
    await tester.pump();

    await tester.tap(find.text('Esferas'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Teleportes'), findsOneWidget);
  });
}
