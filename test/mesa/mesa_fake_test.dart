import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_service.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

/// Mestre com a mesa já criada, e um jogador pronto para entrar nela.
Future<(MesaFake, Mesa)> mesaPronta() async {
  final mestre = MesaFake('u-mestre');
  await mestre.entrarAnonimo();
  final mesa = await mestre.criarMesa('Sombras de SP', 'Gabriel');
  return (mestre, mesa);
}

Future<MesaFake> jogadorNa(MesaFake mestre, Mesa mesa,
    {String uid = 'u-kaue', String nome = 'Kaue'}) async {
  final j = MesaFake(uid, mundo: mestre.mundo);
  await j.entrarAnonimo();
  await j.entrarPorCodigo(mesa.codigo, nome);
  return j;
}

void main() {
  test('criar mesa: quem cria é o mestre e já é membro', () async {
    final (mestre, mesa) = await mesaPronta();

    expect(mesa.mestreUid, 'u-mestre');
    expect(mesa.codigo, startsWith('MAGO-'));

    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.single.uid, 'u-mestre');
    expect(membros.single.papel, PapelMesa.mestre);
  });

  test('entrar por código: vira jogador', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();

    final mesmaMesa = await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect(mesmaMesa.id, mesa.id);
    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.length, 2);
    expect(membros.firstWhere((m) => m.uid == 'u-kaue').papel,
        PapelMesa.jogador);
  });

  test('código inexistente é recusado', () async {
    final s = MesaFake('u1');
    await s.entrarAnonimo();
    expect(() => s.entrarPorCodigo('MAGO-ZZZZ', 'Fulano'),
        throwsA(isA<MesaNaoEncontrada>()));
  });

  test('entrar duas vezes não duplica o membro', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect((await mestre.observarMembros(mesa.id).first).length, 2);
  });

  test('o mestre entrando de novo continua mestre', () async {
    final (mestre, mesa) = await mesaPronta();

    await mestre.entrarPorCodigo(mesa.codigo, 'Gabriel');

    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.single.papel, PapelMesa.mestre);
  });

  test('sair remove só a si mesmo', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);

    await jogador.sair(mesa.id);

    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.map((m) => m.uid), ['u-mestre']);
  });

  test('só o mestre remove os outros', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);

    expect(() => jogador.removerMembro(mesa.id, 'u-mestre'),
        throwsA(isA<SemPermissao>()));

    await mestre.removerMembro(mesa.id, 'u-kaue');
    expect((await mestre.observarMembros(mesa.id).first).length, 1);
  });

  test('trocar código: o antigo para de funcionar', () async {
    final (mestre, mesa) = await mesaPronta();
    final antigo = mesa.codigo;

    await mestre.trocarCodigo(mesa.id);
    final atual = (await mestre.observarMesa(mesa.id).first)!;
    expect(atual.codigo, isNot(antigo));

    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    expect(() => jogador.entrarPorCodigo(antigo, 'Kaue'),
        throwsA(isA<MesaNaoEncontrada>()));
    await jogador.entrarPorCodigo(atual.codigo, 'Kaue'); // não lança
  });

  test('só o mestre troca o código', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);

    expect(() => jogador.trocarCodigo(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('fechar mesa: quem observa recebe null', () async {
    final (mestre, mesa) = await mesaPronta();

    await mestre.fecharMesa(mesa.id);

    expect(await mestre.observarMesa(mesa.id).first, isNull);
  });

  test('só o mestre fecha', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);

    expect(() => jogador.fecharMesa(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('bater ponto atualiza o visto', () async {
    final (mestre, mesa) = await mesaPronta();
    final antes = (await mestre.observarMembros(mesa.id).first).single.visto;

    mestre.relogio = () => antes.add(const Duration(minutes: 5));
    await mestre.baterPonto(mesa.id);

    final depois = (await mestre.observarMembros(mesa.id).first).single.visto;
    expect(depois.isAfter(antes), isTrue);
  });
}
