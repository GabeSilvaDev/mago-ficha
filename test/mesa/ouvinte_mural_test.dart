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
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');

    // o jogador já entrou nesta mesa antes: em produção o registro de membro
    // dele já existe no Firestore de uma entrada anterior, sobrevivendo ao
    // fechar e reabrir o app (é o próprio anonymous uid que persiste). Sem
    // este passo o `recemAberto` de baixo simularia um uid que nunca esteve
    // na mesa — e a checagem de permissão do fake (que este mesmo bloqueador
    // deixou de furar) recusaria a leitura.
    final primeiraEntrada = MesaFake('u-jogador', mundo: mestre.mundo);
    await primeiraEntrada.entrarAnonimo();
    await primeiraEntrada.entrarPorCodigo(mesa.codigo, 'Kaue');

    // um serviço "recém-aberto", sem login: é assim que a home constrói o
    // ouvinte quando o app reabre já dentro da mesa — instância nova, mas
    // mesmo uid (persistido) e mesmo mundo compartilhado
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
    // um pump a mais que antes: o ouvinte busca a imagem cheia
    // (`imagemCheia`) antes de abrir, e essa busca é mais um salto
    // assíncrono. A legenda vem de graça dentro do próprio `item` do mural
    // (não é uma segunda busca), então não soma mais nenhum pump.
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });

  testWidgets('legenda aparece na tela cheia', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);

    final id = await mestre.guardarNaGaleria(
        mesaId, _imagemBase64(), 'mini', 'o mapa que vocês acham na mesa');
    await mestre.mostrarAgora(mesaId, id);
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('o mapa que vocês acham na mesa'), findsOneWidget);
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

  testWidgets('ponteiro para imagem que sumiu não abre nada', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);
    final id =
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa');
    // apaga ANTES de apontar o mural pra ela: se fosse depois, `apagarDaGaleria`
    // já limpa sozinho o mural que aponta pro id apagado (dado da mesa
    // consistente), e o teste nunca chegaria a exercitar a defesa do ouvinte.
    // Isso simula o ponteiro chegando órfão — mural com um `imagemId` cuja
    // imagem cheia já não existe mais.
    await mestre.apagarDaGaleria(mesaId, id);
    await mestre.mostrarAgora(mesaId, id);

    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsNothing);
  });

  /// Achado da revisão final: `_ultimoAberto` era gravado ANTES da busca da
  /// imagem cheia. Se a busca falhasse (rede fora) ou voltasse `null`, a
  /// guarda que evita reabrir a mesma imagem a cada emissão passava a
  /// descartar TODAS as emissões seguintes do mesmo ponteiro — o aparelho
  /// nunca mais abriria aquela imagem, mesmo com a rede de volta.
  testWidgets(
      'falha ao buscar a imagem não queima o ponteiro: reemissão do mesmo mural tenta de novo',
      (t) async {
    final (mestre, mesaId) = await mesaAberta(t);
    final id =
        await mestre.guardarNaGaleria(mesaId, _imagemBase64(), 'mini', 'mapa');
    // simula a falha: a imagem cheia some depois de guardada (rede caiu
    // bem no meio, por exemplo) — `imagemCheia` volta `null` na primeira
    // busca do ouvinte.
    mestre.mundo.cheias[mesaId]!.remove(id);
    await mestre.mostrarAgora(mesaId, id);

    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    // a primeira tentativa falhou: nada abre ainda
    expect(find.byType(VisualizadorImagens), findsNothing);

    // a rede volta: a imagem passa a existir, e o MESMO ponteiro (mesma
    // `em`, mesmo `imagemId`) é reemitido por qualquer mexida na mesa — aqui,
    // um bater de ponto, sem que o mestre precise mostrar de novo
    mestre.mundo.cheias[mesaId]![id] = _imagemBase64();
    await mestre.baterPonto(mesaId);
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });
}
