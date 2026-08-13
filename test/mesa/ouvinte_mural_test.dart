import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/ouvinte_mural.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';

String _imagemBase64() {
  final im = img.Image(width: 60, height: 40);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return base64Encode(Uint8List.fromList(img.encodeJpg(im)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(MesaFake, String)> mesaAberta(WidgetTester t) async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    // um serviço "recém-aberto", sem login: é assim que a home constrói o
    // ouvinte quando o app reabre já dentro da mesa
    final recemAberto = MesaFake('u-jogador', mundo: mestre.mundo);
    await t.pumpWidget(MaterialApp(
      home: OuvinteMural(
        servico: recemAberto,
        mesaId: mesa.id,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    return (mestre, mesa.id);
  }

  testWidgets('imagem nova no mural abre em tela cheia', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);
    expect(find.byType(VisualizadorImagens), findsNothing);

    final id =
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa');
    await mestre.mostrarAgora(mesaId, id);
    // um pump a mais que antes: agora o ouvinte busca a imagem cheia
    // (`imagemCheia`) antes de abrir, e essa busca é mais um salto assíncrono
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });

  testWidgets('mural limpo não reabre nada', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);

    await mestre.limparMural(mesaId);
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsNothing);
  });

  /// O stream emite de novo a cada mexida na mesa (alguém entra, bate ponto).
  /// Se cada emissão reabrisse, a tela do jogador viraria um popup sem fim.
  testWidgets('a mesma imagem não reabre a cada emissão', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);

    final id =
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa');
    await mestre.mostrarAgora(mesaId, id);
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    // fecha e provoca novas emissões sem imagem nova
    Navigator.of(t.element(find.byType(VisualizadorImagens))).pop();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await mestre.baterPonto(mesaId);
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsNothing);
  });
}
