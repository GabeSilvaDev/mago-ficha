import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Sozinho no arquivo: entrar grava no Hive de dentro do fake-async.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-conhecidas');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    // já esteve nesta mesa, mas não está dentro dela agora
    await MesaStore.lembrar(MesaConhecida(
        mesaId: mesaId,
        nome: 'Sombras',
        papel: PapelMesa.mestre,
        chave: chave));
  });

  testWidgets('fora de mesa, a mesa conhecida aparece para voltar', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsOneWidget);
    expect(find.text('Criar mesa'), findsOneWidget);
    expect(find.text('Entrar com código'), findsOneWidget);
  });

  testWidgets('esquecer tira a mesa da lista', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.byTooltip('Esquecer esta mesa'));
    await t.pump();
    await t.tap(find.text('Esquecer'));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsNothing);
    expect(MesaStore.conhecidas(), isEmpty);
  });
}
