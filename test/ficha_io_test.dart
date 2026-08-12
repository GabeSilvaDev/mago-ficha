import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

Uint8List _png() {
  final im = img.Image(width: 300, height: 200);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-io');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();
  });

  test('export embute o retrato e import extrai para o store', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Com foto';
    f.retratoId = await ImagemStore.salvar(_png());
    await FichaStore.salvar(f);

    final json = FichaIO.paraJson(f);
    expect(json['retrato'], isA<String>());
    expect(json.containsKey('retratoId'), isFalse);

    await Hive.box<String>(ImagemStore.boxName).clear();
    final volta = await FichaIO.deJson(json);

    expect(volta.nome, 'Com foto');
    expect(volta.retratoId, isNotNull);
    expect(ImagemStore.bytes(volta.retratoId!), isNotNull);
  });

  test('ficha sem retrato não ganha o campo', () {
    final f = Ficha.criar();
    expect(FichaIO.paraJson(f).containsKey('retrato'), isFalse);
  });

  test('import de id já existente gera id novo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Original';
    await FichaStore.salvar(f);

    final volta = await FichaIO.deJson(FichaIO.paraJson(f));
    expect(volta.id, isNot(f.id));
  });

  test('paraJson não mexe na ficha original', () async {
    final f = Ficha.criar();
    f.retratoId = await ImagemStore.salvar(_png());
    final antes = f.retratoId;
    FichaIO.paraJson(f);
    expect(f.retratoId, antes);
    expect(f.data.containsKey('retrato'), isFalse);
  });
}
