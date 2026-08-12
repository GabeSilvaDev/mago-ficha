import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/services/backup_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

Uint8List _png() {
  final im = img.Image(width: 120, height: 90);
  img.fill(im, color: img.ColorRgb8(1, 2, 3));
  return Uint8List.fromList(img.encodePng(im));
}

Ficha _ficha(String nome) {
  final f = Ficha.criar();
  f.data['nome'] = nome;
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-backup');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await NotaStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
    await Hive.box<String>(NotaStore.boxName).clear();
  });

  test('zip tem manifesto e uma entrada por ficha', () {
    final fichas = [_ficha('Cassandra Vex'), _ficha('João da Silva')];
    final bytes = BackupIO.montarZip(fichas);

    final zip = ZipDecoder().decodeBytes(bytes);
    final nomes = zip.files.map((f) => f.name).toList();

    expect(nomes, contains('manifest.json'));
    expect(nomes.where((n) => n.startsWith('fichas/')).length, 2);
    expect(nomes.any((n) => n.contains('Cassandra-Vex')), isTrue);

    final man = jsonDecode(utf8.decode(zip.files
        .firstWhere((f) => f.name == 'manifest.json')
        .content as List<int>));
    expect(man['versao'], BackupIO.versao);
    expect(man['app'], 'mago-a-ascensao');
    expect(man['fichas'], 2);
  });

  test('cada arquivo de ficha é um JSON importável sozinho', () {
    final bytes = BackupIO.montarZip([_ficha('Solitária')]);
    final zip = ZipDecoder().decodeBytes(bytes);
    final arq = zip.files.firstWhere((f) => f.name.startsWith('fichas/'));
    final json = jsonDecode(utf8.decode(arq.content as List<int>));
    expect(json['nome'], 'Solitária');
    expect(json['id'], isA<String>());
  });

  test('nomes repetidos não viram o mesmo arquivo', () {
    final bytes = BackupIO.montarZip([_ficha('Igual'), _ficha('Igual')]);
    final zip = ZipDecoder().decodeBytes(bytes);
    final nomes =
        zip.files.map((f) => f.name).where((n) => n.startsWith('fichas/'));
    expect(nomes.toSet().length, 2);
  });

  test('leitura devolve resumo com as fichas e as colisões', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);

    final bytes = BackupIO.montarZip([existente, _ficha('Nova')]);
    final resumo = BackupIO.lerZip(bytes);

    expect(resumo.versao, BackupIO.versao);
    expect(resumo.total, 2);
    expect(resumo.colidem, ['Repetida']);
  });

  test('aplicar duplicar mantém a existente e grava uma cópia', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    final resumo = BackupIO.lerZip(BackupIO.montarZip([existente]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.duplicar);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 2);
    expect(FichaStore.porId(existente.id), isNotNull);
  });

  test('aplicar substituir sobrescreve a existente', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    existente.data['nome'] = 'Repetida (editada no backup)';
    final resumo = BackupIO.lerZip(BackupIO.montarZip([existente]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.substituir);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 1);
    expect(FichaStore.porId(existente.id)!.nome, 'Repetida (editada no backup)');
  });

  test('aplicar pular ignora a colidente', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    final resumo =
        BackupIO.lerZip(BackupIO.montarZip([existente, _ficha('Nova')]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.pular);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 2);
  });

  test('roundtrip: exporta, limpa e importa de volta', () async {
    for (final n in ['Um', 'Dois', 'Três']) {
      await FichaStore.salvar(_ficha(n));
    }
    final bytes = BackupIO.montarZip(FichaStore.todas());
    await Hive.box<String>(FichaStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar);

    final nomes = FichaStore.todas().map((f) => f.nome).toList()..sort();
    expect(nomes, ['Dois', 'Três', 'Um']);
  });

  test('backup leva e traz de volta cadernos, campos e imagens', () async {
    await NarradorStore.salvarCampos([
      const CampoNarrador(
          id: 'a', nome: 'Status', tipo: TipoCampo.tag, opcoes: ['Vivo']),
    ]);
    final imgId = await ImagemStore.salvar(_png());
    await NotaStore.salvar(Nota.criar()
      ..titulo = 'Sessão 1'
      ..texto = 'Começou'
      ..imagens.add(imgId));

    final bytes = BackupIO.montarZip(FichaStore.todas());

    await Hive.box<String>(NotaStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar);

    expect(NarradorStore.campos().map((c) => c.nome), ['Status']);
    final notas = NotaStore.todas();
    expect(notas.length, 1);
    expect(notas.first.titulo, 'Sessão 1');
    expect(notas.first.imagens.first, imgId);
    expect(ImagemStore.bytes(imgId), isNotNull);
  });

  test('importar marcando como NPC vale para o lote inteiro', () async {
    final bytes = BackupIO.montarZip([_ficha('Um'), _ficha('Dois')]);
    await Hive.box<String>(FichaStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar,
        marcarComoNpc: true);

    final todas = FichaStore.todas();
    expect(todas.length, 2);
    expect(todas.every((f) => f.ehNpc), isTrue);
  });

  test('sem marcar, o lote continua entrando como jogador', () async {
    final bytes = BackupIO.montarZip([_ficha('Um')]);
    await Hive.box<String>(FichaStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar);

    expect(FichaStore.todas().single.ehNpc, isFalse);
  });

  test('substituir tambem respeita marcar como NPC', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    final bytes = BackupIO.montarZip([existente]);

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.substituir,
        marcarComoNpc: true);

    expect(FichaStore.porId(existente.id)!.ehNpc, isTrue);
  });

  test('zip antigo, sem pasta do narrador, continua importável', () {
    final resumo = BackupIO.lerZip(BackupIO.montarZip([_ficha('Sozinha')]));
    expect(resumo.total, 1);
    expect(resumo.notas, isEmpty);
    expect(resumo.camposNarrador, isEmpty);
    expect(resumo.imagens, isEmpty);
  });

  test('zip sem manifesto é recusado', () {
    final bytes = ZipEncoder().encode(Archive());
    expect(() => BackupIO.lerZip(Uint8List.fromList(bytes)),
        throwsA(isA<Exception>()));
  });

  test('versão futura é recusada', () {
    final arquivo = Archive();
    final man = utf8.encode('{"versao": 99, "app": "mago-a-ascensao"}');
    arquivo.addFile(ArchiveFile('manifest.json', man.length, man));
    final bytes = ZipEncoder().encode(arquivo);
    expect(() => BackupIO.lerZip(Uint8List.fromList(bytes)),
        throwsA(isA<Exception>()));
  });
}
