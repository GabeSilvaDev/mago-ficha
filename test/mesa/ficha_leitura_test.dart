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

  /// O buraco de verdade: o lápis de cada seção abre o wizard, que grava no
  /// Hive DESTE aparelho. Pelo mestre isso virava uma cópia da ficha do
  /// jogador na coleção dele, e o jogador não via mudança nenhuma.
  testWidgets('somente leitura não deixa lápis de seção em aba nenhuma',
      (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(
        home: FichaViewScreen(fichaDireta: f, somenteLeitura: true)));
    await t.pump();

    for (final abaNome in const [
      'Personagem',
      'Status',
      'Atributos & Habilidades',
      'Esferas',
      'Vantagens & Defeitos',
      'Detalhes',
    ]) {
      await t.tap(find.text(abaNome));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.edit), findsNothing,
          reason: 'lápis de seção aberto na aba $abaNome');
    }
  });

  /// Sem gravar no Hive: escrita iniciada de dentro do `testWidgets` fica
  /// pendente e trava o encerramento da suíte.
  testWidgets('sem somenteLeitura os lápis continuam lá', (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(home: FichaViewScreen(fichaDireta: f)));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.edit), findsWidgets);
    expect(
        find.byTooltip('Editar ficha inteira (todas as etapas)'), findsOneWidget);
  });
}
