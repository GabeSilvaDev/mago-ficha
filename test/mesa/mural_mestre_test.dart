import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/painel_mestre.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

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
    mesaId = (await mestre.criarMesa('Sombras', 'Gabriel')).id;
  });

  testWidgets('mural vazio oferece mostrar imagem', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Mostrar imagem para a mesa'), findsOneWidget);
  });

  testWidgets('com imagem no mural, oferece tirar', (t) async {
    await mestre.mostrarNoMural(mesaId, 'AAAA', 'mapa da estação');

    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('mapa da estação'), findsOneWidget);
    expect(find.text('Tirar do mural'), findsOneWidget);
  });

  testWidgets('tirar do mural volta a oferecer mostrar', (t) async {
    await mestre.mostrarNoMural(mesaId, 'AAAA', 'mapa');

    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    await t.tap(find.text('Tirar do mural'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Mostrar imagem para a mesa'), findsOneWidget);
    expect(find.text('mapa'), findsNothing);
  });
}
