import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/widgets/retrato.dart';

Uint8List _png() {
  final im = img.Image(width: 120, height: 120);
  img.fill(im, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? idSalvo;

  setUpAll(() async {
    Hive.init('build/test-hive-retrato');
    await ImagemStore.init();
  });

  // gravação fora do `testWidgets`: escrita de disco não completa dentro do
  // fake-async do teste de widget
  setUp(() async {
    await Hive.box<String>(ImagemStore.boxName).clear();
    idSalvo = await ImagemStore.salvar(_png());
  });

  testWidgets('sem retrato mostra o ícone padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: null, tamanho: 40)),
    ));
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('com retrato mostra a imagem', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: idSalvo, tamanho: 40)),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
  });

  testWidgets('id inexistente cai no ícone padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: 'nao-existe', tamanho: 40)),
    ));
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
