import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

/// Atualizar o app — o site no GitHub Pages ou o APK — não pode apagar o que
/// já está no aparelho. Este teste escreve nas caixas exatamente o que uma
/// versão ANTERIOR à Fase 4 teria gravado e lê tudo com o código de hoje.
///
/// É o cenário "publiquei a versão nova e quem já tinha ficha": a resposta
/// tem de ser sempre a mesma ficha, com o mesmo id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-atualizacao');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NotaStore.init();
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(MesaStore.boxName).clear();
  });

  test('ficha gravada por versão antiga continua legível e intacta', () async {
    // JSON no formato de antes da Fase 4: sem nada que a fase acrescentou
    const antiga = {
      'id': 'ficha-antiga-1',
      'nome': 'Cotoia',
      'jogador': 'Kaue',
      'arete': 3,
      'forcaVontade': 6,
      'fdvAtual': 4,
      'quintAtual': 5,
      'paradoxoAtual': 2,
      'experiencia': 12,
      'vitalidadeDano': 2,
      'esferas': {'forces': 3, 'life': 2},
    };
    await Hive.box<String>(FichaStore.boxName)
        .put('ficha-antiga-1', jsonEncode(antiga));

    final lida = FichaStore.porId('ficha-antiga-1');

    expect(lida, isNotNull);
    expect(lida!.nome, 'Cotoia');
    expect(lida.areteFinal, 3);
    expect(lida.fdvAtual, 4);
    expect(lida.quintAtual, 5);
    expect(lida.paradoxoAtual, 2);
    expect(lida.experiencia, 12);
    expect(lida.vitalidadeDano, 2);
    expect(FichaStore.todas().length, 1);
  });

  test('a limpeza de imagens do boot não leva imagem de ficha antiga',
      () async {
    final imagemId = await ImagemStore.salvarBase64(_pngMinimo);
    await Hive.box<String>(FichaStore.boxName).put(
        'ficha-antiga-2',
        jsonEncode({
          'id': 'ficha-antiga-2',
          'nome': 'Com retrato',
          'retratoId': imagemId,
        }));

    // exatamente o que `main()` faz ao abrir o app
    await ImagemStore.limpar(
        {...FichaStore.imagensUsadas(), ...NotaStore.imagensUsadas()});

    expect(ImagemStore.bytes(imagemId), isNotNull,
        reason: 'o retrato da ficha não pode ser recolhido como órfão');
  });

  test('estado de mesa gravado sem os campos da Fase 4 não quebra', () async {
    // como a versão anterior gravava: sem `chave`
    await Hive.box<String>(MesaStore.boxName).put(
        'atual',
        jsonEncode({
          'mesaId': 'm-antiga',
          'nome': 'Sombras de SP',
          'uid': 'u-antigo',
          'papel': 'mestre',
        }));

    final estado = MesaStore.atual;

    expect(estado, isNotNull);
    expect(estado!.mesaId, 'm-antiga');
    expect(estado.papel, PapelMesa.mestre);
    expect(estado.chave, isNull);
    // e a lista de mesas conhecidas, que nem existia, nasce vazia em vez de
    // estourar
    expect(MesaStore.conhecidas(), isEmpty);
  });
}

/// PNG 1x1 válido, o menor possível.
const String _pngMinimo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
    'IQAAAABJRU5ErkJggg==';
