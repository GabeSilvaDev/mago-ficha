import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

/// Sozinho no arquivo: publicar grava no Hive de dentro do fake-async, e a
/// escrita pendente trava o `setUp` de qualquer teste que venha depois.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late MesaFake jogador;
  late Mesa mesa;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-mesa-publicar');
    await MesaStore.init();
    // sem `FichaStore.init`: ele chama `Hive.initFlutter`, que precisa do
    // path_provider e não existe no ambiente de teste
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();
    await Hive.box<String>(FichaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');

    jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    // já dentro da mesa: o teste é sobre publicar, não sobre entrar
    await MesaStore.entrar(EstadoMesa(
      mesaId: mesa.id,
      nome: mesa.nome,
      uid: 'u-kaue',
      papel: PapelMesa.jogador,
    ));

    final f = Ficha.criar();
    f.data['nome'] = 'Cassandra Vex';
    await FichaStore.salvar(f);
    FichaStore.observador = null;
  });

  testWidgets('jogador publica uma ficha e ela chega ao mestre', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: jogador))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Publicar uma ficha'), findsOneWidget);

    // o mural entrou antes do cartão da ficha: o botão desceu na lista
    await t.ensureVisible(find.text('Publicar uma ficha'));
    await t.pump();
    await t.tap(find.text('Publicar uma ficha'));
    await t.pump();
    await t.tap(find.text('Cassandra Vex').last);
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Tirar da mesa'), findsOneWidget);
    expect(find.text('Publicar uma ficha'), findsNothing);

    final naMesa = await mestre.observarFichas(mesa.id).first;
    expect(naMesa.single.nome, 'Cassandra Vex');
    expect(MesaStore.atual!.fichaPublicadaId, isNotNull);
  });
}
