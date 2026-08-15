import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/chave_mesa.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_service.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

/// Mestre com a mesa já criada, e um jogador pronto para entrar nela.
Future<(MesaFake, Mesa)> mesaPronta() async {
  final mestre = MesaFake('u-mestre');
  await mestre.entrarAnonimo();
  final (mesa, _) = await mestre.criarMesa('Sombras de SP', 'Gabriel');
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

  // Achado da revisão final: `observarMesa` agora recusa quem não é membro
  // nem mestre (espelhando `souMembro(id) || souMestre(id)` das regras). Uma
  // assinatura NOVA feita depois de apagar a mesa seria recusada — é
  // exatamente esse `permission-denied` num listener novo, contra um `null`
  // de verdade num listener que já existia, que escondia o bloqueador da
  // Fase 4 (`observarMesa` "morrendo" quando o registro de membro some).
  // Por isso a assinatura aqui é feita ANTES de apagar: só assim o teste
  // reproduz o que um listener já aberto recebe de verdade.
  test('apagar mesa: quem já observava recebe null', () async {
    final (mestre, mesa) = await mesaPronta();

    final espera =
        expectLater(mestre.observarMesa(mesa.id), emitsThrough(isNull));
    await mestre.apagarMesa(mesa.id);
    await espera;

    // uma tentativa nova de observar, feita depois da mesa já ter sumido,
    // não acha mais nem membro nem mestre — e é recusada. O erro chega PELO
    // stream (como a produção faz: `MesaFirestore` nunca lança síncrono),
    // não como uma exceção síncrona na chamada — senão `_naMesa` quebraria
    // ao reconstruir `_membros`/`MuralDaMesa`/`GaleriaMesa` no exato rebuild
    // em que a mesa some.
    expect(mestre.observarMesa(mesa.id), emitsError(isA<SemPermissao>()));
  });

  test('só o mestre apaga', () async {
    final (mestre, mesa) = await mesaPronta();
    final jogador = await jogadorNa(mestre, mesa);

    expect(() => jogador.apagarMesa(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('encerrar sessão esvazia a mesa mas ela continua existindo', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    await mestre.encerrarSessao(mesa.id);

    // a mesa e a galeria sobrevivem
    expect(await mestre.observarMesa(mesa.id).first, isNotNull);
    expect((await mestre.observarGaleria(mesa.id).first).length, 1);
    // ninguém ficou dentro, e nenhuma ficha ficou publicada
    expect(await mestre.observarMembros(mesa.id).first, isEmpty);
    expect(await mestre.observarFichas(mesa.id).first, isEmpty);
  });

  test('depois de encerrar, dá para entrar de novo com o mesmo código',
      () async {
    final (mestre, mesa) = await mesaPronta();
    await mestre.encerrarSessao(mesa.id);

    final devolta = await mestre.entrarPorCodigo(mesa.codigo, 'Gabriel');

    expect(devolta.id, mesa.id);
    expect(devolta.mestreUid, 'u-mestre');
  });

  // `encerrarSessao` apaga o registro de membro do mestre junto com o dos
  // jogadores. Ele voltar pela lista de mesas conhecidas (`entrarPorId`) não
  // pode rebaixá-lo: o registro de membro não é a fonte da verdade sobre quem
  // manda na mesa, o `mestreUid` dela é.
  test('depois de encerrar, voltar por entrarPorId continua mestre',
      () async {
    final (mestre, mesa) = await mesaPronta();
    await mestre.encerrarSessao(mesa.id);

    final devolta = await mestre.entrarPorId(mesa.id, 'Gabriel');

    expect(devolta.id, mesa.id);
    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.single.uid, 'u-mestre');
    expect(membros.single.papel, PapelMesa.mestre);
  });

  test('apagar mesa leva tudo junto', () async {
    final (mestre, mesa) = await mesaPronta();
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    await mestre.apagarMesa(mesa.id);

    // checagem direta no mundo, não via `observarMesa`: depois de apagada,
    // uma assinatura NOVA é recusada por não achar mais membro nem mestre —
    // ver o teste 'apagar mesa: quem já observava recebe null' para a
    // cobertura de quem já estava ouvindo antes.
    expect(mestre.mundo.mesas[mesa.id], isNull);
    expect(mestre.mundo.galeria[mesa.id], isNull);
  });

  test('só o mestre encerra e só o mestre apaga', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);

    expect(() => kaue.encerrarSessao(mesa.id), throwsA(isA<SemPermissao>()));
    expect(() => kaue.apagarMesa(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('bater ponto atualiza o visto', () async {
    final (mestre, mesa) = await mesaPronta();
    final antes = (await mestre.observarMembros(mesa.id).first).single.visto;

    mestre.relogio = () => antes.add(const Duration(minutes: 5));
    await mestre.baterPonto(mesa.id);

    final depois = (await mestre.observarMembros(mesa.id).first).single.visto;
    expect(depois.isAfter(antes), isTrue);
  });

  test('publicar ficha: o mestre vê, o outro jogador não', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    final erik = await jogadorNa(mestre, mesa, uid: 'u-erik', nome: 'Erik');

    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    final doMestre = await mestre.observarFichas(mesa.id).first;
    expect(doMestre.single.donoUid, 'u-kaue');
    expect(doMestre.single.ficha['nome'], 'Cotoia');

    // o outro jogador não enxerga nada
    expect(await erik.observarFichas(mesa.id).first, isEmpty);
    expect(await erik.observarFicha(mesa.id, 'u-kaue').first, isNull);

    // o dono enxerga a própria
    expect((await kaue.observarFicha(mesa.id, 'u-kaue').first)!.nome, 'Cotoia');
  });

  test('publicar de novo substitui, não duplica', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);

    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia', 'arete': 1}, 'Cotoia');
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia', 'arete': 2}, 'Cotoia');

    final fichas = await mestre.observarFichas(mesa.id).first;
    expect(fichas.length, 1);
    expect(fichas.single.ficha['arete'], 2);
  });

  test('mestre não escreve na ficha do jogador', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    // não existe API para isso; a garantia é o dono do documento
    expect(() => mestre.despublicarFichaDe(mesa.id, 'u-kaue'),
        throwsA(isA<SemPermissao>()));
  });

  test('despublicar tira a ficha da mesa', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    await kaue.despublicarFicha(mesa.id);

    expect(await mestre.observarFichas(mesa.id).first, isEmpty);
  });

  test('mestre mostra no mural e todos veem', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);

    final id = await mestre.guardarNaGaleria(mesa.id, 'AAAA', 'mini', 'mapa da estação');
    await mestre.mostrarAgora(mesa.id, id);

    final visto = await kaue.observarMural(mesa.id).first;
    expect(visto!.imagemId, id);
  });

  test('jogador não escreve no mural', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    final id = await mestre.guardarNaGaleria(mesa.id, 'AAAA', 'mini', 'mapa');

    expect(() => kaue.mostrarAgora(mesa.id, id), throwsA(isA<SemPermissao>()));
    expect(() => kaue.limparMural(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('limpar mural: volta a ser null', () async {
    final (mestre, mesa) = await mesaPronta();
    final id = await mestre.guardarNaGaleria(mesa.id, 'AAAA', 'mini', '');
    await mestre.mostrarAgora(mesa.id, id);

    await mestre.limparMural(mesa.id);

    expect(await mestre.observarMural(mesa.id).first, isNull);
  });

  test('apagar a mesa leva o mural junto', () async {
    final (mestre, mesa) = await mesaPronta();
    final id = await mestre.guardarNaGaleria(mesa.id, 'AAAA', 'mini', 'mapa');
    await mestre.mostrarAgora(mesa.id, id);

    await mestre.apagarMesa(mesa.id);

    expect(mestre.mundo.mural[mesa.id], isNull);
  });

  test('galeria acumula em vez de sobrescrever', () async {
    final (mestre, mesa) = await mesaPronta();

    await mestre.guardarNaGaleria(mesa.id, 'CHEIA1', 'MINI1', 'mapa');
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA2', 'MINI2', 'retrato');

    final itens = await mestre.observarGaleria(mesa.id).first;
    expect(itens.length, 2);
    expect(itens.map((i) => i.legenda), containsAll(['mapa', 'retrato']));
  });

  test('galeria vem com a mais recente primeiro', () async {
    final (mestre, mesa) = await mesaPronta();
    final t0 = DateTime(2026, 8, 1, 20);
    mestre.relogio = () => t0;
    await mestre.guardarNaGaleria(mesa.id, 'C1', 'M1', 'primeira');
    mestre.relogio = () => t0.add(const Duration(hours: 1));
    await mestre.guardarNaGaleria(mesa.id, 'C2', 'M2', 'segunda');

    final itens = await mestre.observarGaleria(mesa.id).first;
    expect(itens.first.legenda, 'segunda');
  });

  test('jogador lê a galeria mas não escreve nela', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    expect((await kaue.observarGaleria(mesa.id).first).single.legenda, 'mapa');
    expect(() => kaue.guardarNaGaleria(mesa.id, 'X', 'Y', 'tentativa'),
        throwsA(isA<SemPermissao>()));
  });

  test('imagem cheia só é buscada quando pedida', () async {
    final (mestre, mesa) = await mesaPronta();
    final id = await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    final itens = await mestre.observarGaleria(mesa.id).first;
    expect(itens.single.miniaturaBase64, 'MINI');
    expect(await mestre.imagemCheia(mesa.id, id), 'CHEIA');
  });

  test('apagar tira da galeria e some com a imagem cheia', () async {
    final (mestre, mesa) = await mesaPronta();
    final id = await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    await mestre.apagarDaGaleria(mesa.id, id);

    expect(await mestre.observarGaleria(mesa.id).first, isEmpty);
    expect(await mestre.imagemCheia(mesa.id, id), isNull);
  });

  test('só o mestre apaga da galeria', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    final id = await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    expect(() => kaue.apagarDaGaleria(mesa.id, id),
        throwsA(isA<SemPermissao>()));
  });

  test('mostrar agora aponta o mural para a imagem da galeria', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    final id = await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    await mestre.mostrarAgora(mesa.id, id);

    final visto = await kaue.observarMural(mesa.id).first;
    expect(visto!.imagemId, id);
  });

  test('apagar a imagem em destaque limpa o mural', () async {
    final (mestre, mesa) = await mesaPronta();
    final id = await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');
    await mestre.mostrarAgora(mesa.id, id);

    await mestre.apagarDaGaleria(mesa.id, id);

    expect(await mestre.observarMural(mesa.id).first, isNull);
  });

  test('sair da mesa despublica a ficha', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    await kaue.sair(mesa.id);

    expect(await mestre.observarFichas(mesa.id).first, isEmpty);
  });

  test('criar mesa devolve uma chave de recuperação', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();

    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');

    expect(ChaveMesa.valida(chave), isTrue);
    expect(mesa.mestreUid, 'u-mestre');
  });

  test('com a chave certa, outro uid reassume a mesa', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    // mesmo humano, aparelho novo: uid diferente
    final novo = MesaFake('u-mestre-2', mundo: mestre.mundo);
    await novo.entrarAnonimo();
    final devolta = await novo.reassumirMesa(mesa.codigo, chave, 'Gabriel');

    expect(devolta.mestreUid, 'u-mestre-2');
    // a galeria continua inteira
    expect((await novo.observarGaleria(mesa.id).first).length, 1);
    // e agora ele manda na mesa
    await novo.guardarNaGaleria(mesa.id, 'C2', 'M2', 'outro mapa');
  });

  test('chave errada não devolve a mesa', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');

    final ladrao = MesaFake('u-ladrao', mundo: mestre.mundo);
    await ladrao.entrarAnonimo();

    expect(() => ladrao.reassumirMesa(mesa.codigo, 'MAGO-AAAA-BBBB', 'X'),
        throwsA(isA<ChaveErrada>()));
    expect((await mestre.observarMesa(mesa.id).first)!.mestreUid, 'u-mestre');
  });

  test('reassumir com código que não existe avisa direito', () async {
    final s = MesaFake('u1');
    await s.entrarAnonimo();
    expect(() => s.reassumirMesa('MAGO-ZZZZ', 'MAGO-AAAA-BBBB', 'X'),
        throwsA(isA<MesaNaoEncontrada>()));
  });
}
