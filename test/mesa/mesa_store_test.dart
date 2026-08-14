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

  test('comFicha preserva a chave de recuperação', () {
    const estado = EstadoMesa(
        mesaId: 'm1',
        nome: 'Sombras',
        uid: 'u1',
        papel: PapelMesa.mestre,
        chave: 'MAGO-K7QW-3XZP');

    final comFicha = estado.comFicha('ficha-1');

    expect(comFicha.chave, 'MAGO-K7QW-3XZP');
    expect(comFicha.fichaPublicadaId, 'ficha-1');
  });

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
