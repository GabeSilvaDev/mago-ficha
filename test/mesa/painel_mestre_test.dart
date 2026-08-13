import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/painel_mestre.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;
  late String codigo;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-painel');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  setUp(() async {
    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;
    codigo = mesa.codigo;
  });

  testWidgets('lista as fichas publicadas com o estado de jogo', (t) async {
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(codigo, 'Kaue');

    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';
    f.vitalidadeDano = 2;
    await kaue.publicarFicha(mesaId, FichaIO.paraJson(f), 'Cotoia');

    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Cotoia'), findsOneWidget);
    // 2 de dano = segundo nível da tabela do livro
    expect(find.textContaining('Machucado'), findsOneWidget);
    expect(find.textContaining('Arete'), findsOneWidget);
  });

  testWidgets('sem fichas publicadas, explica o que fazer', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.textContaining('Ninguém publicou ficha'), findsOneWidget);
  });
}
