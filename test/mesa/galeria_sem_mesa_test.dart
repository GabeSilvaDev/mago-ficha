import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_aba.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

/// Fora de mesa a galeria é a de sempre: nada de rede, nada de ficha alheia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-galeria-sem-mesa');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(MesaStore.boxName).clear();

    final npc = Ficha.criarNpc();
    npc.data['nome'] = 'Guardião';
    await FichaStore.salvar(npc);
    FichaStore.observador = null;
  });

  testWidgets('sem mesa, a galeria mostra só o que é local', (t) async {
    // um serviço com fichas publicadas por outra gente: nada disso pode vazar
    final mestre = MesaFake('u-mestre');

    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: GaleriaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Guardião'), findsOneWidget);
    expect(find.text('na mesa · só leitura'), findsNothing);
  });
}
