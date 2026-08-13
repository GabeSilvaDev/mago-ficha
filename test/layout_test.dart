import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/home_screen.dart';
import 'package:mago_a_ascensao/screens/wizard_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';
import 'package:mago_a_ascensao/widgets/layout.dart';

/// Tamanhos reais dos dois donos do app: o jogador no iPhone e o mestre no PC.
const Size iphone = Size(390, 844); // iPhone 14
const Size desktop = Size(1440, 900);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-layout');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await NotaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    final f = Ficha.criar();
    f.data['nome'] = 'Cassandra Vex';
    await FichaStore.salvar(f);
  });

  Future<void> abrirEm(WidgetTester t, Size tamanho, Widget tela) async {
    t.view.physicalSize = tamanho * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: tela));
    await t.pump();
  }

  testWidgets('celular: navegação embaixo, sem barra lateral', (t) async {
    await abrirEm(t, iphone, const HomeScreen());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('PC: navegação na lateral, sem barra embaixo', (t) async {
    await abrirEm(t, desktop, const HomeScreen());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('PC: conteúdo não estica de ponta a ponta', (t) async {
    await abrirEm(t, desktop, const HomeScreen());

    final miolo = t.widget<Miolo>(find.byType(Miolo).first);
    expect(miolo.max, lessThanOrEqualTo(larguraMioloPadrao));

    // o Miolo ocupa a tela; quem é limitado é o conteúdo dentro dele
    final conteudo = find.descendant(
        of: find.byType(Miolo), matching: find.byType(IndexedStack));
    final largura = t.getSize(conteudo).width;
    expect(largura, lessThanOrEqualTo(larguraMioloPadrao + 1));
    expect(largura, lessThan(desktop.width)); // não estica de ponta a ponta
  });

  testWidgets('wizard cabe nos dois tamanhos sem estourar', (t) async {
    final f = Ficha.criar();
    for (final tamanho in [iphone, desktop]) {
      await abrirEm(t, tamanho, WizardScreen(existente: f, passos: const [3]));
      expect(t.takeException(), isNull,
          reason: 'estourou em ${tamanho.width.toInt()}px');
    }
  });

  testWidgets('as duas abas continuam alcançáveis no PC', (t) async {
    await abrirEm(t, desktop, const HomeScreen());

    expect(find.text('Magos'), findsOneWidget);
    expect(find.text('Narrador'), findsOneWidget);

    await t.tap(find.text('Narrador'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Galeria'), findsOneWidget);
  });
}
