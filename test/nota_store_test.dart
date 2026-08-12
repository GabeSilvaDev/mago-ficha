import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-nota');
    await NotaStore.init();
  });

  tearDown(() async => Hive.box<String>(NotaStore.boxName).clear());

  test('salvar, listar e apagar', () async {
    final n = Nota.criar()
      ..titulo = 'Sessão 4 - o Nodo'
      ..texto = 'Os personagens acharam o Nodo sob a estação.'
      ..tags.add('sessão');
    await NotaStore.salvar(n);

    expect(NotaStore.todas().length, 1);
    expect(NotaStore.porId(n.id)!.titulo, 'Sessão 4 - o Nodo');
    expect(NotaStore.porId(n.id)!.tags, ['sessão']);

    await NotaStore.excluir(n.id);
    expect(NotaStore.todas(), isEmpty);
  });

  test('busca por título, texto e tag', () async {
    await NotaStore.salvar(Nota.criar()
      ..titulo = 'O Nodo'
      ..texto = 'nada aqui');
    await NotaStore.salvar(Nota.criar()
      ..titulo = 'Outra'
      ..texto = 'menção ao nodo no corpo');
    await NotaStore.salvar(Nota.criar()
      ..titulo = 'Terceira'
      ..tags.add('nodo'));
    await NotaStore.salvar(Nota.criar()..titulo = 'Nada a ver');

    expect(NotaStore.buscar('nodo').length, 3);
    expect(NotaStore.buscar('NODO').length, 3);
    expect(NotaStore.buscar('inexistente'), isEmpty);
    expect(NotaStore.buscar('  ').length, 4); // termo vazio = tudo
  });

  test('lista de imagens usadas junta todas as notas', () async {
    await NotaStore.salvar(Nota.criar()..imagens.addAll(['a', 'b']));
    await NotaStore.salvar(Nota.criar()..imagens.add('c'));
    expect(NotaStore.imagensUsadas(), {'a', 'b', 'c'});
  });

  test('ordena da mais recente para a mais antiga', () async {
    final velha = Nota.criar()..titulo = 'Velha';
    velha.atualizadoEm = '2020-01-01T00:00:00.000';
    final nova = Nota.criar()..titulo = 'Nova';
    nova.atualizadoEm = '2026-01-01T00:00:00.000';
    await NotaStore.salvar(velha, tocar: false);
    await NotaStore.salvar(nova, tocar: false);
    expect(NotaStore.todas().first.titulo, 'Nova');
  });
}
