import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/screens/narrador/cadernos_aba.dart';
import 'package:mago_a_ascensao/screens/narrador/nota_screen.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

Uint8List _png(int cor) {
  final im = img.Image(width: 200, height: 150);
  img.fill(im, color: img.ColorRgb8(cor, 30, 60));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Nota comImagens;
  late String img1;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-caderno-ui');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NotaStore.init();
  });

  // gravações fora do `testWidgets`: escrita de disco não completa dentro do
  // fake-async do teste de widget
  setUp(() async {
    await Hive.box<String>(NotaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();

    img1 = await ImagemStore.salvar(_png(200));
    final img2 = await ImagemStore.salvar(_png(40));

    comImagens = Nota.criar()
      ..titulo = 'Sessão 4 - o Nodo'
      ..texto = 'Acharam o Nodo sob a estação.'
      ..imagens.addAll([img1, img2])
      ..legendas[img1] = 'mapa da estação'
      ..tags.add('sessão');
    await NotaStore.salvar(comImagens);

    await NotaStore.salvar(Nota.criar()
      ..titulo = 'Lista de NPCs'
      ..tags.add('npc'));
  });

  testWidgets('miniatura abre o visualizador em tela cheia', (t) async {
    await t.pumpWidget(MaterialApp(home: NotaScreen(existente: comImagens)));
    await t.pump();

    expect(find.byType(VisualizadorImagens), findsNothing);

    final miniatura = find.byType(Image).first;
    await t.ensureVisible(miniatura);
    await t.pump();
    await t.tap(miniatura);
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('mapa da estação'), findsOneWidget); // legenda
  });

  testWidgets('modo mostrar esconde barra e legenda', (t) async {
    await t.pumpWidget(MaterialApp(
      home: VisualizadorImagens(
        imagens: comImagens.imagens,
        legendas: comImagens.legendas,
      ),
    ));
    await t.pump();

    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('mapa da estação'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('modo-mostrar')));
    await t.pump();

    // sem barra, sem contador, sem legenda: só a imagem para a mesa
    expect(find.text('1 de 2'), findsNothing);
    expect(find.text('mapa da estação'), findsNothing);
    expect(find.byKey(const ValueKey('sair-modo-mostrar')), findsOneWidget);
  });

  testWidgets('visualizador aguenta id de imagem que sumiu', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: VisualizadorImagens(imagens: ['fantasma']),
    ));
    await t.pump();
    expect(find.text('Imagem não encontrada.'), findsOneWidget);
  });

  testWidgets('chip de tag filtra a lista de cadernos', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: CadernosAba())));
    await t.pump();

    expect(find.text('Sessão 4 - o Nodo'), findsOneWidget);
    expect(find.text('Lista de NPCs'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('tag-npc')));
    await t.pump();

    expect(find.text('Lista de NPCs'), findsOneWidget);
    expect(find.text('Sessão 4 - o Nodo'), findsNothing);
  });

  testWidgets('alfinete marca a nota como fixada', (t) async {
    await t.pumpWidget(MaterialApp(home: NotaScreen(existente: comImagens)));
    await t.pump();

    expect(comImagens.fixada, isFalse);
    await t.tap(find.byKey(const ValueKey('fixar-nota')));
    await t.pump();
    expect(comImagens.fixada, isTrue);
  });
}
