import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/ficha_view_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-leitura');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  testWidgets('ficha vinda da mesa abre sem estar no Hive', (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(
        home: FichaViewScreen(fichaDireta: f, somenteLeitura: true)));
    await t.pump();

    expect(find.text('Cotoia'), findsWidgets);
    expect(FichaStore.porId(f.id), isNull); // nunca foi gravada aqui
  });

  testWidgets('somente leitura esconde editar e trava os trackers', (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(
        home: FichaViewScreen(fichaDireta: f, somenteLeitura: true)));
    await t.pump();

    // sem lápis de editar a ficha inteira
    expect(
        find.byTooltip('Editar ficha inteira (todas as etapas)'), findsNothing);

    // os trackers moram na aba Status
    await t.tap(find.text('Status'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    // e nenhum + / − responde
    final mais = t.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    expect(mais, isNotEmpty);
    expect(mais.every((b) => b.onPressed == null), isTrue);
  });
}
