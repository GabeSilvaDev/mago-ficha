import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/screens/home_screen.dart';
import 'package:mago_a_ascensao/screens/narrador/cadernos_aba.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_aba.dart';
import 'package:mago_a_ascensao/screens/wizard_screen.dart';
import 'package:mago_a_ascensao/widgets/dots.dart';
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
    await MesaStore.init();
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
      const CampoNarrador(
          id: 's',
          nome: 'Situação',
          tipo: TipoCampo.tag,
          opcoes: ['Vivo', 'Morto']),
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

  testWidgets('botão + NPC abre o wizard completo em modo livre', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await t.pump();

    await t.tap(find.byTooltip('Novo NPC (ficha completa, modo livre)'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    // é o passo a passo do jogador: começa na Identidade, 7 etapas
    expect(find.byType(WizardScreen), findsOneWidget);
    expect(find.text('NPC · 1/7 · Identidade'), findsOneWidget);

    final wizard = t.widget<WizardScreen>(find.byType(WizardScreen));
    expect(wizard.inicial!.ehNpc, isTrue);
    expect(wizard.inicial!.modoLivre, isTrue);

    // modo livre: o Próximo não trava mesmo com a Identidade em branco
    final proximo = find.widgetWithText(ElevatedButton, 'Próximo');
    expect(t.widget<ElevatedButton>(proximo).onPressed, isNotNull);
    expect(find.text('Complete esta etapa para continuar.'), findsNothing);
  });

  testWidgets('NPC criado no wizard usa o teto 10 das Esferas', (t) async {
    await t.pumpWidget(MaterialApp(
        home: WizardScreen(inicial: Ficha.criarNpc(), passos: const [3])));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    final linhas = t.widgetList<LinhaBolinhas>(find.byType(LinhaBolinhas));
    expect(linhas.where((l) => l.max == 10).length, greaterThanOrEqualTo(9));
  });

  testWidgets('tocar num NPC abre a ficha completa, igual jogador', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await t.pump();

    await t.tap(find.text('Barqueiro'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    // as 6 abas da ficha de personagem
    expect(find.text('Atributos & Habilidades'), findsOneWidget);
    expect(find.text('Esferas'), findsOneWidget);
  });

  testWidgets('campos do narrador aparecem na ficha e são editáveis',
      (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await t.pump();

    await t.tap(find.text('Cassandra'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Campos do narrador'.toUpperCase()), findsOneWidget);
    expect(find.text('Situação'), findsOneWidget);
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
