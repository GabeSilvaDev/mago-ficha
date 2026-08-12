import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/backup_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

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
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();
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
