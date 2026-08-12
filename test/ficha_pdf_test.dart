import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

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
