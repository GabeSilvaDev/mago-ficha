import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/screens/home_screen.dart';
import 'package:mago_a_ascensao/screens/narrador/cadernos_aba.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_aba.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-narrador-ui');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await NotaStore.init();
  });

  // gravações ficam fora do `testWidgets`: escrita de disco não completa
  // dentro do fake-async do teste de widget
  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
    await Hive.box<String>(NotaStore.boxName).clear();

    await NarradorStore.salvarCampos([
      const CampoNarrador(
          id: 'a', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete'),
    ]);
    final pc = Ficha.criar();
    pc.data['nome'] = 'Cassandra';
    pc.bonusArete = 2;
    await FichaStore.salvar(pc);
    final npc = Ficha.criarNpc();
    npc.data['nome'] = 'Barqueiro';
    await FichaStore.salvar(npc);

    await NotaStore.salvar(Nota.criar()..titulo = 'Sessão 4 - o Nodo');
    await NotaStore.salvar(Nota.criar()..titulo = 'Lista de NPCs');
  });

  testWidgets('home tem as abas Magos e Narrador', (t) async {
    await t.pumpWidget(const MaterialApp(home: HomeScreen()));
    await t.pump();

    expect(find.text('Magos'), findsOneWidget);
    expect(find.text('Narrador'), findsOneWidget);
    expect(find.text('CRIAR PERSONAGEM'), findsOneWidget);

    await t.tap(find.text('Narrador'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Cadernos'), findsOneWidget);
  });

  testWidgets('galeria mostra PCs e NPCs com o campo escolhido', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await t.pump();

    expect(find.text('Cassandra'), findsOneWidget);
    expect(find.text('Barqueiro'), findsOneWidget);
    expect(find.text('Arete: 3'), findsOneWidget); // 1 base + 2 de bônus
    expect(find.text('NPC'), findsOneWidget);
  });

  testWidgets('filtro NPC esconde os PCs', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('filtro-npcs')));
    await t.pump();

    expect(find.text('Barqueiro'), findsOneWidget);
    expect(find.text('Cassandra'), findsNothing);
  });

  testWidgets('lista de cadernos filtra pela busca', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: CadernosAba())));
    await t.pump();

    expect(find.text('Sessão 4 - o Nodo'), findsOneWidget);
    expect(find.text('Lista de NPCs'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'nodo');
    await t.pump();

    expect(find.text('Sessão 4 - o Nodo'), findsOneWidget);
    expect(find.text('Lista de NPCs'), findsNothing);
  });

  testWidgets('aba Magos não lista NPC', (t) async {
    await t.pumpWidget(const MaterialApp(home: HomeScreen()));
    await t.pump();

    expect(find.text('Cassandra'), findsOneWidget);
    expect(find.text('Barqueiro'), findsNothing);
  });
}
