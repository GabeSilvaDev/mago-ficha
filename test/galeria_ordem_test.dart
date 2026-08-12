import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_ordem.dart';

Ficha _pc(String nome, int bonusArete) {
  final f = Ficha.criar();
  f.data['nome'] = nome;
  f.bonusArete = bonusArete;
  return f;
}

Ficha _npc(String nome) {
  final f = Ficha.criarNpc();
  f.data['nome'] = nome;
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  const arete = CampoNarrador(
      id: 'a', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete');

  test('filtra por tipo', () {
    final lista = [_pc('Um', 0), _npc('Dois'), _pc('Três', 0)];
    expect(GaleriaOrdem.aplicar(lista, tipo: FiltroTipo.pcs).length, 2);
    expect(GaleriaOrdem.aplicar(lista, tipo: FiltroTipo.npcs).length, 1);
    expect(GaleriaOrdem.aplicar(lista, tipo: FiltroTipo.todos).length, 3);
  });

  test('ordena por campo derivado, crescente e decrescente', () {
    final lista = [_pc('Baixo', 0), _pc('Alto', 4), _pc('Meio', 2)];
    final cres = GaleriaOrdem.aplicar(lista, ordenarPor: arete, crescente: true);
    expect(cres.map((f) => f.nome), ['Baixo', 'Meio', 'Alto']);
    final desc =
        GaleriaOrdem.aplicar(lista, ordenarPor: arete, crescente: false);
    expect(desc.map((f) => f.nome), ['Alto', 'Meio', 'Baixo']);
  });

  test('sem campo de ordenação, ordena por nome', () {
    final lista = [_pc('Zebra', 0), _pc('Abelha', 0)];
    expect(GaleriaOrdem.aplicar(lista).map((f) => f.nome), ['Abelha', 'Zebra']);
  });

  test('busca pelo nome', () {
    final lista = [_pc('Cassandra', 0), _pc('João', 0)];
    expect(GaleriaOrdem.aplicar(lista, busca: 'cass').map((f) => f.nome),
        ['Cassandra']);
  });

  test('filtra por valor de tag', () {
    const status = CampoNarrador(
        id: 's',
        nome: 'Status',
        tipo: TipoCampo.tag,
        opcoes: ['Vivo', 'Morto']);
    final vivo = _pc('Vivo', 0)..setCampo('s', 'Vivo');
    final morto = _pc('Morto', 0)..setCampo('s', 'Morto');
    final resultado = GaleriaOrdem.aplicar([vivo, morto],
        campoTag: status, tagFiltro: 'Morto');
    expect(resultado.map((f) => f.nome), ['Morto']);
  });

  test('ficha sem valor no campo vai para o fim da ordenação', () {
    final semValor = _pc('Sem', 0);
    const campo = CampoNarrador(id: 'x', nome: 'Sessão', tipo: TipoCampo.numero);
    final comValor = _pc('Com', 0)..setCampo('x', 3);
    expect(GaleriaOrdem.aplicar([semValor, comValor], ordenarPor: campo)
        .map((f) => f.nome), ['Com', 'Sem']);
    // e continua no fim quando a ordem inverte
    expect(GaleriaOrdem.aplicar([semValor, comValor],
        ordenarPor: campo, crescente: false).map((f) => f.nome), ['Com', 'Sem']);
  });
}
