import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/wizard_screen.dart';
import 'package:mago_a_ascensao/widgets/dots.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  Future<void> abrir(WidgetTester t, Widget tela) async {
    await t.pumpWidget(MaterialApp(home: tela));
    await t.pumpAndSettle();
  }

  testWidgets('edição parcial: só a tela pedida, confirma só ela',
      (t) async {
    final f = Ficha.criar();
    await abrir(t, WizardScreen(existente: f, passos: const [2]));

    expect(find.text('Editar · Habilidades'), findsOneWidget);
    expect(find.text('Salvar esta tela'), findsOneWidget);
    expect(find.text('Próximo'), findsNothing); // não cai no wizard geral
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('edição avisa que os limites da criação não valem', (t) async {
    final f = Ficha.criar();
    await abrir(t, WizardScreen(existente: f, passos: const [1]));
    expect(find.textContaining('limites da criação não valem'), findsOneWidget);
    // criação nenhuma etapa incompleta libera o botão; aqui libera:
    expect(find.text('Salvar esta tela'), findsOneWidget);
  });

  testWidgets('editar seção: só Arete e Força de Vontade, sem os 15 bônus',
      (t) async {
    final f = Ficha.criar();
    await abrir(
      t,
      WizardScreen(
        existente: f,
        passos: const [5],
        secoes: const {'arete', 'forcaVontade'},
        titulo: 'Arete & Força de Vontade',
      ),
    );

    expect(find.text('Editar · Arete & Força de Vontade'), findsOneWidget);
    expect(find.text('Arete'), findsOneWidget);
    expect(find.text('Força de Vontade'), findsOneWidget);

    // nada do resto dos Toques Finais entra na tela
    expect(find.textContaining('Quintessência'), findsNothing);
    expect(find.text('Inteligência'), findsNothing);
    // nem o placar dos 15 pontos de bônus, nem o ⚙ de regras
    expect(find.text('Restantes'), findsNothing);
    expect(find.byIcon(Icons.rule), findsNothing);
  });

  testWidgets('edição não cobra os 15 bônus nem a distribuição da criação',
      (t) async {
    final f = Ficha.criar();
    f.modoLivre = false; // ficha gravada como iniciante durante a criação

    await abrir(t, WizardScreen(existente: f, passos: const [1]));
    expect(find.textContaining('Distribua 4'), findsNothing);
    expect(find.text('Distribuição correta!'), findsNothing);

    await abrir(t, WizardScreen(existente: f, passos: const [5]));
    expect(find.text('Restantes'), findsNothing);
  });

  testWidgets('criação continua travando a etapa incompleta', (t) async {
    await abrir(t, const WizardScreen());
    expect(find.text('1/7 · Identidade'), findsOneWidget);
    expect(find.text('Complete esta etapa para continuar.'), findsOneWidget);
    final botao = t.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Próximo'));
    expect(botao.onPressed, isNull);
  });

  testWidgets('editando a ficha inteira: abas livres para qualquer etapa',
      (t) async {
    final f = Ficha.criar();
    await abrir(t, WizardScreen(existente: f));

    // as 7 abas aparecem e dá pra pular direto pra qualquer uma
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Toques Finais'), findsOneWidget);
    expect(find.text('Identidade'), findsWidgets);

    await t.tap(find.widgetWithText(Tab, 'Esferas'));
    await t.pumpAndSettle();
    expect(find.text('Correspondência'), findsOneWidget);

    // ✓ na barra salva de qualquer aba, sem ter que ir até a última
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byIcon(Icons.check)),
        findsOneWidget);
  });

  testWidgets('criação NÃO tem abas (segue travada e sequencial)', (t) async {
    await abrir(t, const WizardScreen());
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('⚙ troca entre iniciante e livre e grava na ficha', (t) async {
    final f = Ficha.criar();
    // ficha inteira: é aqui que o ⚙ aparece (na edição de uma seção ele some,
    // porque ali as regras da criação não valem de qualquer jeito)
    await abrir(t, WizardScreen(existente: f));

    // editar uma ficha pronta entra livre
    expect(find.textContaining('Modo livre'), findsOneWidget);

    await t.tap(find.byIcon(Icons.rule));
    await t.pumpAndSettle();
    await t.tap(find.text('Iniciante (regras da criação)'));
    await t.pumpAndSettle();

    expect(f.modoLivre, isFalse);
    expect(find.textContaining('Modo livre'), findsNothing);

    await t.tap(find.byIcon(Icons.rule));
    await t.pumpAndSettle();
    await t.tap(find.text('Livre — evolução / mestre'));
    await t.pumpAndSettle();
    expect(f.modoLivre, isTrue);
  });

  testWidgets('layout de celular: as 7 telas montam sem estourar', (t) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final f = Ficha.criar();
    f.data['afiliacao'] = 'Nefandi / Caídos';
    f.data['faccao'] = 'Nefandi / Caídos';
    f.addHabilidadeExtra('Talentos', 'Intuição', 'Palpites.');
    for (var p = 0; p < 7; p++) {
      await abrir(t, WizardScreen(existente: f, passos: [p]));
      expect(t.takeException(), isNull, reason: 'etapa $p estourou o layout');
    }
    // e a ficha inteira com abas
    await abrir(t, WizardScreen(existente: f));
    expect(t.takeException(), isNull);
  });

  testWidgets('habilidade personalizada entra na coluna escolhida',
      (t) async {
    final f = Ficha.criar();
    await abrir(t, WizardScreen(existente: f, passos: const [2]));

    final botao = find.text('Habilidade personalizada').first;
    await t.ensureVisible(botao);
    await t.pumpAndSettle();
    await t.tap(botao);
    await t.pumpAndSettle();
    expect(find.text('Habilidade personalizada — Talentos'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'Intuição');
    await t.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await t.pumpAndSettle();

    expect(f.habilidadesExtras.length, 1);
    expect(f.extrasDaCategoria('Talentos').first.nome, 'Intuição');
    expect(find.text('Intuição'), findsOneWidget);
    expect(find.text('Personalizadas (opcionais do livro)'), findsOneWidget);
  });

  testWidgets('habilidade personalizada não aceita nome repetido', (t) async {
    final f = Ficha.criar();
    await abrir(t, WizardScreen(existente: f, passos: const [2]));

    final botao = find.text('Habilidade personalizada').first;
    await t.ensureVisible(botao);
    await t.pumpAndSettle();
    await t.tap(botao);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'briga');
    await t.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await t.pumpAndSettle();

    expect(find.text('Já existe uma Habilidade com esse nome.'), findsOneWidget);
    expect(f.habilidadesExtras, isEmpty);
  });

  testWidgets('modo livre desenha 10 bolinhas por Esfera', (t) async {
    final f = Ficha.criar();
    f.modoLivre = true;
    await abrir(t, WizardScreen(existente: f, passos: const [3]));

    final linhas = t.widgetList<LinhaBolinhas>(find.byType(LinhaBolinhas));
    expect(linhas.where((l) => l.max == 10).length, greaterThanOrEqualTo(9));
  });

  testWidgets('criação mantém 5 bolinhas por Esfera', (t) async {
    // sem `existente` o wizard entra em modo criação, onde vale o teto padrão
    await abrir(t, const WizardScreen(passos: [3]));

    final linhas = t.widgetList<LinhaBolinhas>(find.byType(LinhaBolinhas));
    expect(linhas, isNotEmpty);
    expect(linhas.every((l) => l.max <= 5), isTrue);
  });

  testWidgets('chip de especialização aparece e grava na ficha', (t) async {
    final f = Ficha.criar();
    f.modoLivre = true;
    f.setEsfera('correspondence', 4);
    await abrir(t, WizardScreen(existente: f, passos: const [3]));

    final chip = find.byKey(const ValueKey('espec-correspondence'));
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();

    await t.tap(find.text('Teleportes'));
    await t.pumpAndSettle();

    expect(f.especEsferaDe('correspondence'), ['Teleportes']);
    expect(find.text('Teleportes'), findsOneWidget);
  });
}
