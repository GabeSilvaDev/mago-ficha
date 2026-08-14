import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-store');
    await MesaStore.init();
  });

  setUp(() async => Hive.box<String>(MesaStore.boxName).clear());

  test('lembrar guarda a mesa e sobrevive a sair dela', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.mestre, chave: 'K'));
    await MesaStore.entrar(const EstadoMesa(
        mesaId: 'm1', nome: 'Sombras', uid: 'u1', papel: PapelMesa.mestre));

    await MesaStore.limpar();

    expect(MesaStore.atual, isNull);
    expect(MesaStore.conhecidas().single.nome, 'Sombras');
    expect(MesaStore.chaveDe('m1'), 'K');
  });

  test('lembrar a mesma mesa duas vezes não duplica', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.jogador));
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras de SP', papel: PapelMesa.jogador));

    expect(MesaStore.conhecidas().length, 1);
    expect(MesaStore.conhecidas().single.nome, 'Sombras de SP');
  });

  test('esquecer tira da lista', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.mestre));
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm2', nome: 'Outra', papel: PapelMesa.jogador));

    await MesaStore.esquecer('m1');

    expect(MesaStore.conhecidas().map((m) => m.mesaId), ['m2']);
  });
}
