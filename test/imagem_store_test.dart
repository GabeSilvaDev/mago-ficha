import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

Uint8List _pngGrande() {
  final im = img.Image(width: 2400, height: 1600);
  img.fill(im, color: img.ColorRgb8(120, 40, 160));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-imagem');
    await ImagemStore.init();
    await Hive.openBox<String>(FichaStore.boxName);
  });

  tearDown(() async {
    await Hive.box<String>(ImagemStore.boxName).clear();
    await Hive.box<String>(FichaStore.boxName).clear();
  });

  test('reduzir: encolhe para 1024px no maior lado e devolve JPEG', () {
    final saida = ImagemStore.reduzir(_pngGrande());
    final decodificada = img.decodeImage(saida)!;
    expect(decodificada.width, 1024);
    expect(decodificada.height, lessThanOrEqualTo(1024));
    // assinatura JPEG
    expect(saida[0], 0xFF);
    expect(saida[1], 0xD8);
    // o teto de 1024px + JPEG q80 mantém o retrato num tamanho que cabe
    // folgado dentro do JSON exportado
    expect(saida.length, lessThan(500 * 1024));
  });

  test('reduzir mantém imagem menor que o teto no tamanho original', () {
    final pequena = img.Image(width: 300, height: 200);
    img.fill(pequena, color: img.ColorRgb8(10, 20, 30));
    final saida =
        ImagemStore.reduzir(Uint8List.fromList(img.encodePng(pequena)));
    final decodificada = img.decodeImage(saida)!;
    expect(decodificada.width, 300);
    expect(decodificada.height, 200);
  });

  test('salvar e ler de volta', () async {
    final id = await ImagemStore.salvar(_pngGrande());
    expect(id, isNotEmpty);
    expect(ImagemStore.bytes(id), isNotNull);
    expect(ImagemStore.base64De(id), isNotNull);
    expect(ImagemStore.bytes('inexistente'), isNull);
  });

  test('excluir remove a imagem', () async {
    final id = await ImagemStore.salvar(_pngGrande());
    await ImagemStore.excluir(id);
    expect(ImagemStore.bytes(id), isNull);
  });

  test('limpar apaga órfã e preserva a que está em uso', () async {
    final usada = await ImagemStore.salvar(_pngGrande());
    final orfa = await ImagemStore.salvar(_pngGrande());

    final apagadas = await ImagemStore.limpar({usada});

    expect(apagadas, 1);
    expect(ImagemStore.bytes(usada), isNotNull);
    expect(ImagemStore.bytes(orfa), isNull);
  });

  test('faxina preserva o retrato em uso e apaga o resto', () async {
    final usada = await ImagemStore.salvar(_pngGrande());
    await ImagemStore.salvar(_pngGrande()); // órfã

    final f = Ficha.criar();
    f.retratoId = usada;
    await FichaStore.salvar(f);

    final apagadas = await FichaStore.limparImagensOrfas();

    expect(apagadas, 1);
    expect(ImagemStore.bytes(usada), isNotNull);
  });
}
