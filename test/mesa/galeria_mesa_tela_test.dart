import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/galeria_mesa.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

String _img() {
  final im = img.Image(width: 40, height: 30);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return base64Encode(Uint8List.fromList(img.encodeJpg(im)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;
  late String codigo;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-galeria-tela');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  setUp(() async {
    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;
    codigo = mesa.codigo;
  });

  Future<void> abrir(WidgetTester t, MesaFake servico,
      {required bool souMestre}) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GaleriaMesa(
            servico: servico, mesaId: mesaId, souMestre: souMestre),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('mostra as imagens guardadas, da mais nova para a mais velha',
      (t) async {
    mestre.relogio = () => DateTime(2026, 8, 1, 20);
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa antigo');
    mestre.relogio = () => DateTime(2026, 8, 8, 20);
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa novo');

    await abrir(t, mestre, souMestre: true);

    expect(find.text('mapa antigo'), findsOneWidget);
    expect(find.text('mapa novo'), findsOneWidget);
    // Com maxCrossAxisExtent: 160 e a tela de teste padrão (800 de largura),
    // cabem várias colunas na mesma linha: os dois itens ficam lado a lado
    // na primeira linha, não empilhados. "Mais nova primeiro" aqui quer dizer
    // que ela ocupa a célula anterior (mais à esquerda) — dx, não dy.
    final novo = t.getTopLeft(find.text('mapa novo'));
    final antigo = t.getTopLeft(find.text('mapa antigo'));
    expect(novo.dx, lessThan(antigo.dx));
  });

  testWidgets('tocar numa imagem abre em tela cheia', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    await abrir(t, mestre, souMestre: true);

    await t.tap(find.text('mapa'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });

  testWidgets('galeria vazia explica o que fazer', (t) async {
    await abrir(t, mestre, souMestre: true);

    expect(find.textContaining('Nenhuma imagem'), findsOneWidget);
  });

  testWidgets('jogador não vê apagar nem mostrar agora', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(codigo, 'Kaue');

    await abrir(t, kaue, souMestre: false);

    expect(find.text('mapa'), findsOneWidget);
    expect(find.byTooltip('Mostrar agora'), findsNothing);
    expect(find.byTooltip('Apagar da galeria'), findsNothing);
  });

  testWidgets('mestre apaga e a imagem some da grade', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    await abrir(t, mestre, souMestre: true);

    await t.tap(find.byTooltip('Apagar da galeria'));
    await t.pump();
    await t.tap(find.text('Apagar'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('mapa'), findsNothing);
    expect(find.textContaining('Nenhuma imagem'), findsOneWidget);
  });
}
