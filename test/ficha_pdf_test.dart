import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_pdf.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-pdf');
    await ImagemStore.init();
  });

  test('gera ficha.pdf preenchida sobre a ficha oficial', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cassandra Vex';
    f.data['jogador'] = 'Gabriel';
    f.data['cronica'] = 'Sombras de SP';
    f.data['natureza'] = 'Visionário';
    f.data['comportamento'] = 'Enganador';
    f.data['essencia'] = 'Dinâmica';
    f.data['afiliacao'] = 'Tradições';
    f.data['faccao'] = 'Ordem de Hermes';
    f.data['conceito'] = 'Detetive paranormal';
    f.setAtributo('Destreza', 4);
    f.setAtributo('Vigor', 3);
    f.setAtributo('Percepção', 4);
    f.setAtributo('Inteligência', 3);
    f.setHabilidade('Prontidão', 3);
    f.setHabilidade('Investigação', 3);
    f.setBonusHabilidade('Investigação', 1); // 3 -> 4 com bônus
    f.setHabilidade('Ocultismo', 3);
    f.setEsfera('forces', 1);
    f.setBonusEsfera('forces', 1);
    f.setEsfera('correspondence', 1);
    f.setEsfera('prime', 1);
    f.setEsfera('time', 1);
    f.afinidade = 'forces';
    f.bonusArete = 1; // Arete 2
    f.bonusForcaVontade = 2; // FdV 7
    f.adicionar('positivos', {
      'classe': 'antecedente', 'nome': 'Avatar/Gênio', 'sel': 3, 'detalhe': ''});
    f.adicionar('positivos', {
      'classe': 'antecedente', 'nome': 'Aliados', 'sel': 2, 'detalhe': ''});
    f.adicionar('positivos', {
      'classe': 'qualidade', 'nome': 'Sentidos Aguçados', 'sel': 3, 'detalhe': ''});
    f.adicionar('positivos', {
      'classe': 'qualidade', 'nome': 'Idiomas', 'sel': 1, 'detalhe': 'Latim'});
    f.adicionar('defeitos', {
      'nome': 'Amaldiçoado', 'sel': 5, 'detalhe': '', 'subtipo': ''});
    f.adicionar('defeitos', {
      'nome': 'Vício', 'sel': 3, 'detalhe': 'Nicotina', 'subtipo': ''});
    f.adicionar('outrasCaracteristicas', {'nome': 'Sorte', 'valor': 2});
    f.adicionar('maravilhas', {
      'Nome': 'Anel de Salomão',
      'Descrição': 'Talismã que armazena 3 pontos de Quintessência para rituais.'
    });
    f.adicionar('combate', {
      'Arma/Manobra': 'Revólver .38', 'Dif.': '6', 'Dano': '4',
      'Tipo': 'Letal', 'Alcance': '12m', 'Cadência': '3'});
    f.data['historia'] =
        'Ex-detetive da polícia civil que Despertou ao reabrir um caso impossível.';
    f.data['objetivosDestino'] = 'Encontrar o artefato da família.';
    f.data['rotinas'] = 'Rituais de proteção ao amanhecer.';
    f.data['focos'] = 'Paradigma: tudo é um experimento. Instrumentos: varinha.';
    f.data['itensEquipamentos'] = 'Revólver .38, kit de investigação, giz ritual.';
    f.aparencia['idade'] = '34';
    f.aparencia['sexo'] = 'F';
    f.aparencia['cabelos'] = 'Pretos';
    f.aparencia['descricao'] = 'Casaco comprido e olhar cansado.';
    f.vitalidadeDano = 2;
    f.fdvAtual = 5;
    f.quintAtual = 6;
    f.paradoxoAtual = 2;
    f.experiencia = 12;

    final bytes = await FichaPdf.gerar(f);
    expect(bytes.length, greaterThan(100000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // salva para inspeção visual externa
    final out = File('build/ficha_test.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  });

  test('história longa vai para o anexo e a ficha marca o corte', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Tagarela';
    f.data['historia'] = List.filled(120,
            'Despertou numa noite de tempestade e desde então persegue o mesmo sonho.')
        .join(' ');

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('História'));
    final item = FichaPdf.anexoGerado.firstWhere((e) => e.titulo == 'História');
    expect(item.texto, f.data['historia']);
  });

  test('ficha curta não gera anexo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Sucinto';
    f.data['historia'] = 'Nasceu, Despertou, seguiu.';

    await FichaPdf.gerar(f);

    expect(FichaPdf.anexoGerado, isEmpty);
  });

  test('listas que passam das linhas da ficha vão para o anexo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Colecionador';
    for (var i = 0; i < 14; i++) {
      f.adicionar('positivos', {
        'classe': 'qualidade',
        'nome': 'Sentidos Aguçados',
        'sel': 3,
        'detalhe': 'variante $i'
      });
    }
    for (var i = 0; i < 12; i++) {
      f.adicionar('combate', {
        'Arma/Manobra': 'Arma $i',
        'Dif.': '6',
        'Dano': '4',
        'Tipo': 'Letal',
        'Alcance': '10m',
        'Cadência': '1'
      });
    }

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('Qualidades (continuação)'));
    expect(titulos, contains('Combate (continuação)'));
  });

  test('especializações de Esfera e valores acima de 5 saem no anexo',
      () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Andarilho';
    f.setEsfera('correspondence', 7);
    f.addEspecEsfera('correspondence', 'Teleportes');
    f.data['arete'] = 8;

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('Especializações de Esfera'));
    expect(titulos, contains('Valores acima de cinco'));
    final vals = FichaPdf.anexoGerado
        .firstWhere((e) => e.titulo == 'Valores acima de cinco')
        .texto;
    expect(vals, contains('Correspondência: 7'));
    expect(vals, contains('Arete: 8'));
  });

  test('PDF com anexo tem mais páginas que o sem anexo', () async {
    final curta = Ficha.criar();
    curta.data['nome'] = 'Curta';
    final bytesCurta = await FichaPdf.gerar(curta);

    final longa = Ficha.criar();
    longa.data['nome'] = 'Longa';
    longa.data['historia'] = List.filled(
            200, 'Uma linha inteira de história que não cabe na ficha oficial.')
        .join(' ');
    final bytesLonga = await FichaPdf.gerar(longa);

    expect(bytesLonga.length, greaterThan(bytesCurta.length));

    final out = File('build/ficha_test_anexo.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytesLonga);
  });

  test('ficha com retrato gera anexo mesmo sem texto excedente', () async {
    final im = img.Image(width: 400, height: 400);
    img.fill(im, color: img.ColorRgb8(90, 30, 120));

    final f = Ficha.criar();
    f.data['nome'] = 'Retratado';
    f.retratoId =
        await ImagemStore.salvar(Uint8List.fromList(img.encodePng(im)));

    final bytes = await FichaPdf.gerar(f);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // sem texto cortado, o anexo existe só por causa do retrato
    expect(FichaPdf.anexoGerado, isEmpty);

    final out = File('build/ficha_test_retrato.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  });

  test('paraFonte troca o que a Helvetica nao encodifica', () {
    expect(FichaPdf.paraFonte('PING \u2014 Corr'), 'PING - Corr');
    expect(FichaPdf.paraFonte('PING\u2026'), 'PING...');
    expect(FichaPdf.paraFonte('\u201CPING\u201D'), '"PING"');
    expect(FichaPdf.paraFonte('l\u2019Arte'), "l'Arte");
    expect(FichaPdf.paraFonte('\u2022 PING'), '- PING');
    expect(FichaPdf.paraFonte('PING \u2192 Corr'), 'PING -> Corr');
    expect(FichaPdf.paraFonte('PING \u{1F52E}'), 'PING ?'); // emoji
    // acento do portugues esta no Latin-1 e nao pode ser mexido
    expect(FichaPdf.paraFonte('Variações básicas: ç ã é ô ü'),
        'Variações básicas: ç ã é ô ü');
    // quebra de linha sobrevive (o anexo depende dela)
    expect(FichaPdf.paraFonte('a\nb'), 'a\nb');
  });

  test('texto com pontuacao de celular nao derruba a exportacao', () async {
    // caso real: aspas curvas, travessao e reticencias que o teclado insere
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia \u2014 “a Andarilha”';
    f.data['focos'] = 'Variações básicas: PING (Corr 1) \u2192 “sentir” o alvo\u2026';
    f.data['rotinas'] = '\u2022 Ritual ao amanhecer\n\u2022 Diário \u2013 sempre';
    f.data['historia'] = 'Ela dizia: \u2018não há distância\u2019 \u{1F52E}';

    final bytes = await FichaPdf.gerar(f);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('ficha com Esfera 7 e Arete 8 gera PDF sem estourar', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Mestre da mesa livre';
    f.modoLivre = true;
    f.setEsfera('correspondence', 7);
    f.setEsfera('forces', 6);
    f.afinidade = 'correspondence';
    f.data['arete'] = 8;

    final bytes = await FichaPdf.gerar(f);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(100000));

    final out = File('build/ficha_test_teto10.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  });
}
