import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_aba.dart';
import 'package:mago_a_ascensao/services/ficha_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

/// A galeria do narrador durante uma sessão: as fichas publicadas pelos
/// jogadores aparecem junto com as locais e somem quando saem da mesa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late MesaFake kaue;
  late String mesaId;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-galeria-mesa');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    final dele = Ficha.criar();
    dele.data['nome'] = 'Cotoia';
    await kaue.publicarFicha(mesaId, FichaIO.paraJson(dele), 'Cotoia');

    // um NPC local, para provar que a lista continua misturando os dois
    final npc = Ficha.criarNpc();
    npc.data['nome'] = 'Guardião';
    await FichaStore.salvar(npc);
    FichaStore.observador = null;

    await MesaStore.entrar(EstadoMesa(
      mesaId: mesaId,
      nome: mesa.nome,
      uid: 'u-mestre',
      papel: PapelMesa.mestre,
    ));
  });

  Future<void> abrir(WidgetTester t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: GaleriaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('ficha publicada aparece na galeria, marcada como só leitura',
      (t) async {
    await abrir(t);

    expect(find.text('Cotoia'), findsOneWidget);
    expect(find.text('na mesa · só leitura'), findsOneWidget);
    expect(find.text('Guardião'), findsOneWidget);
  });

  testWidgets('filtro Jogadores mostra a da mesa e esconde o NPC', (t) async {
    await abrir(t);

    await t.tap(find.byKey(const ValueKey('filtro-pcs')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Cotoia'), findsOneWidget);
    expect(find.text('Guardião'), findsNothing);
  });

  testWidgets('despublicar tira a ficha da galeria', (t) async {
    await abrir(t);
    expect(find.text('Cotoia'), findsOneWidget);

    await kaue.despublicarFicha(mesaId);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Cotoia'), findsNothing);
    expect(find.text('Guardião'), findsOneWidget);
  });

  testWidgets('apagar a mesa tira a ficha da galeria', (t) async {
    await abrir(t);
    expect(find.text('Cotoia'), findsOneWidget);

    await mestre.apagarMesa(mesaId);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Cotoia'), findsNothing);
  });

  // O caso "fora de mesa" mora em galeria_sem_mesa_test.dart: limpar o
  // MesaStore de dentro do fake-async deixa a escrita pendente e trava o
  // encerramento da suíte.
}
