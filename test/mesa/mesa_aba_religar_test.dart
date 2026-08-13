import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// O app foi fechado dentro da mesa e reaberto depois. O estado vem do disco,
/// mas a sessão online não existe: a tela precisa refazer o login antes de
/// observar qualquer coisa. Sem isso o Firestore estoura, porque nem o
/// Firebase foi inicializado — foi o que derrubou a aba Mesa na web.
///
/// A gravação no Hive fica toda no `setUp`: escrita iniciada de dentro do
/// `testWidgets` trava o teste seguinte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake recemAberto;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-religar');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    await MesaStore.entrar(EstadoMesa(
      mesaId: mesa.id,
      nome: mesa.nome,
      uid: 'u-kaue',
      papel: PapelMesa.jogador,
    ));

    // o serviço de um app recém-aberto: ninguém chamou entrarAnonimo nele
    recemAberto = MesaFake('u-kaue', mundo: mestre.mundo);
  });

  testWidgets('reabrir o app dentro da mesa refaz a sessão e mostra a mesa',
      (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: recemAberto))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(t.takeException(), isNull);
    expect(find.text('Sombras'), findsOneWidget);
    expect(find.text('Publicar uma ficha'), findsOneWidget);
  });
}
