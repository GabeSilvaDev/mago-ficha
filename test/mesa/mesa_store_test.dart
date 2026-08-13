import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa');
    await MesaStore.init();
  });

  tearDown(() async => Hive.box<String>(MesaStore.boxName).clear());

  test('sem mesa, atual é null', () {
    expect(MesaStore.atual, isNull);
  });

  test('entrar e limpar', () async {
    await MesaStore.entrar(const EstadoMesa(
      mesaId: 'm1',
      nome: 'Sombras de SP',
      uid: 'u1',
      papel: PapelMesa.mestre,
    ));

    final a = MesaStore.atual!;
    expect(a.mesaId, 'm1');
    expect(a.nome, 'Sombras de SP');
    expect(a.uid, 'u1');
    expect(a.papel, PapelMesa.mestre);
    expect(a.fichaPublicadaId, isNull);

    await MesaStore.limpar();
    expect(MesaStore.atual, isNull);
  });

  test('guarda qual ficha foi publicada', () async {
    await MesaStore.entrar(const EstadoMesa(
      mesaId: 'm1',
      nome: 'Sombras',
      uid: 'u1',
      papel: PapelMesa.jogador,
      fichaPublicadaId: 'ficha-7',
    ));
    expect(MesaStore.atual!.fichaPublicadaId, 'ficha-7');
  });

  test('comFicha troca só a ficha publicada', () {
    const e = EstadoMesa(
      mesaId: 'm1',
      nome: 'Sombras',
      uid: 'u1',
      papel: PapelMesa.jogador,
    );
    final comFicha = e.comFicha('ficha-7');
    expect(comFicha.mesaId, 'm1');
    expect(comFicha.papel, PapelMesa.jogador);
    expect(comFicha.fichaPublicadaId, 'ficha-7');
    expect(comFicha.comFicha(null).fichaPublicadaId, isNull);
  });
}
