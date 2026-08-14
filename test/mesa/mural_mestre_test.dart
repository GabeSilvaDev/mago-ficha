import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/mural_da_mesa.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

String _imagemBase64() {
  final im = img.Image(width: 60, height: 40);
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
    Hive.init('build/test-hive-mural');
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
        body: MuralDaMesa(
            servico: servico, mesaId: mesaId, souMestre: souMestre),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  Future<MesaFake> jogadorNaMesa() async {
    final j = MesaFake('u-kaue', mundo: mestre.mundo);
    await j.entrarAnonimo();
    await j.entrarPorCodigo(codigo, 'Kaue');
    return j;
  }

  testWidgets('mural vazio oferece mostrar imagem ao mestre', (t) async {
    await abrir(t, mestre, souMestre: true);

    expect(find.text('Mostrar imagem para a mesa'), findsOneWidget);
  });

  testWidgets('com imagem no mural, o mestre pode tirar', (t) async {
    await mestre.mostrarAgora(mesaId,
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa da estação'));
    await abrir(t, mestre, souMestre: true);

    expect(find.text('mapa da estação'), findsOneWidget);
    expect(find.text('Tirar do mural'), findsOneWidget);
  });

  testWidgets('tirar do mural volta a oferecer mostrar', (t) async {
    await mestre.mostrarAgora(mesaId,
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa'));
    await abrir(t, mestre, souMestre: true);

    await t.tap(find.text('Tirar do mural'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Mostrar imagem para a mesa'), findsOneWidget);
    expect(find.text('mapa'), findsNothing);
  });

  /// O ponto do pedido: quem fechou a imagem precisa voltar a ela sem depender
  /// de o mestre mostrar de novo.
  testWidgets('jogador reabre a imagem quantas vezes quiser', (t) async {
    await mestre.mostrarAgora(mesaId,
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa da estação'));
    final kaue = await jogadorNaMesa();
    await abrir(t, kaue, souMestre: false);

    expect(find.text('mapa da estação'), findsOneWidget);
    expect(find.text('Ver em tela cheia'), findsOneWidget);

    for (var vez = 0; vez < 2; vez++) {
      await t.tap(find.text('Ver em tela cheia'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(VisualizadorImagens), findsOneWidget);

      Navigator.of(t.element(find.byType(VisualizadorImagens))).pop();
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(VisualizadorImagens), findsNothing);
    }
  });

  testWidgets('jogador não põe nem tira imagem', (t) async {
    await mestre.mostrarAgora(mesaId,
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa'));
    final kaue = await jogadorNaMesa();
    await abrir(t, kaue, souMestre: false);

    expect(find.text('Tirar do mural'), findsNothing);
    expect(find.text('Mostrar imagem para a mesa'), findsNothing);
  });

  testWidgets('mural vazio explica ao jogador o que vai acontecer', (t) async {
    final kaue = await jogadorNaMesa();
    await abrir(t, kaue, souMestre: false);

    expect(find.textContaining('ainda não mostrou'), findsOneWidget);
    expect(find.text('Mostrar imagem para a mesa'), findsNothing);
  });

  testWidgets('mestre tira e a imagem some da tela do jogador', (t) async {
    await mestre.mostrarAgora(mesaId,
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa'));
    final kaue = await jogadorNaMesa();
    await abrir(t, kaue, souMestre: false);
    expect(find.text('Ver em tela cheia'), findsOneWidget);

    await mestre.limparMural(mesaId);
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Ver em tela cheia'), findsNothing);
    expect(find.textContaining('ainda não mostrou'), findsOneWidget);
  });
}
