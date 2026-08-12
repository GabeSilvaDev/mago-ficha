import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-narrador');
    await Hive.openBox<String>(FichaStore.boxName);
    await NarradorStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
  });

  test('campo de tag guarda e devolve o valor da ficha', () {
    const c = CampoNarrador(
        id: 'c1',
        nome: 'Status',
        tipo: TipoCampo.tag,
        opcoes: ['Vivo', 'Morto']);
    final f = Ficha.criar()..setCampo('c1', 'Morto');
    expect(c.textoDe(f), 'Morto');
    expect(c.valorDe(f), 'Morto');
    expect(c.textoDe(Ficha.criar()), '');
  });

  test('campo derivado lê direto da ficha e não usa o mapa de campos', () {
    const arete = CampoNarrador(
        id: 'c2', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete');
    final f = Ficha.criar();
    f.bonusArete = 2; // arete final = 3
    expect(arete.valorDe(f), 3);
    expect(arete.textoDe(f), '3');
    expect(f.campos, isEmpty);

    const afi = CampoNarrador(
        id: 'c3',
        nome: 'Afiliação',
        tipo: TipoCampo.derivado,
        origem: 'afiliacao');
    f.data['afiliacao'] = 'Tradições';
    expect(afi.textoDe(f), 'Tradições');
  });

  test('roundtrip de json da definição', () {
    const c = CampoNarrador(id: 'c4', nome: 'Sessão', tipo: TipoCampo.numero);
    final volta = CampoNarrador.fromJson(c.toJson());
    expect(volta.id, 'c4');
    expect(volta.nome, 'Sessão');
    expect(volta.tipo, TipoCampo.numero);
  });

  test('store guarda e devolve as definições', () async {
    await NarradorStore.salvarCampos([
      const CampoNarrador(
          id: 'a', nome: 'Status', tipo: TipoCampo.tag, opcoes: ['Vivo']),
      const CampoNarrador(
          id: 'b', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete'),
    ]);
    final campos = NarradorStore.campos();
    expect(campos.map((c) => c.nome), ['Status', 'Arete']);
    expect(campos.first.opcoes, ['Vivo']);
    expect(campos.last.origem, 'arete');
  });

  test('apagar campo limpa o valor nas fichas', () async {
    await NarradorStore.salvarCampos(
        [const CampoNarrador(id: 'a', nome: 'Status', tipo: TipoCampo.texto)]);
    final f = Ficha.criar()..setCampo('a', 'Vivo');
    await FichaStore.salvar(f);

    await NarradorStore.excluirCampo('a');

    expect(NarradorStore.campos(), isEmpty);
    expect(FichaStore.porId(f.id)!.campo('a'), isNull);
  });
}
