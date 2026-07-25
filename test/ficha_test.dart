import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  test('defaults da criação', () {
    final f = Ficha.criar();
    expect(f.arete, 1);
    expect(f.forcaVontade, 5);
    expect(f.paradoxo, 0);
    expect(f.avatar, 0);
    expect(f.quintessencia, 0);
    expect(f.bonusGasto, 0);
    expect(f.bonusRestante, 15);
    expect(f.atributo('Força'), 1); // atributos começam em 1
    expect(f.habilidade('Briga'), 0); // habilidades começam em 0
    expect(f.esferasGasto, 0);
  });

  test('exemplo do livro: 4 positivos (8 pts) == 2 defeitos (8 pts)', () {
    final f = Ficha.criar();
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Avatar/Gênio', 'sel': 2, 'detalhe': ''});
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Contatos', 'sel': 2, 'detalhe': ''});
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Aliados', 'sel': 1, 'detalhe': ''});
    f.adicionar('positivos',
        {'classe': 'qualidade', 'nome': 'Sentidos Aguçados', 'sel': 3, 'detalhe': ''});
    f.adicionar('defeitos',
        {'nome': 'Amaldiçoado', 'sel': 5, 'detalhe': '', 'subtipo': ''});
    f.adicionar('defeitos', {'nome': 'Vício', 'sel': 3, 'detalhe': '', 'subtipo': ''});
    expect(f.totalPositivo, 8);
    expect(f.totalDefeito, 8);
    expect(f.avatar, 2);
    expect(f.positivos.length, 4);
    expect(f.defeitos.length, 2);
  });

  test('antecedentes de custo dobrado: grad × 2', () {
    final f = Ficha.criar();
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Aprimoramento', 'sel': 2, 'detalhe': ''});
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Totem', 'sel': 3, 'detalhe': ''});
    expect(f.totalPositivo, 4 + 6);
  });

  test('qualidades: Fé Verdadeira 2=14, Conexões=3, Idiomas=1', () {
    final f = Ficha.criar();
    f.adicionar('positivos',
        {'classe': 'qualidade', 'nome': 'Fé Verdadeira', 'sel': 2, 'detalhe': ''});
    f.adicionar('positivos',
        {'classe': 'qualidade', 'nome': 'Conexões', 'sel': 3, 'detalhe': 'Polícia'});
    f.adicionar('positivos',
        {'classe': 'qualidade', 'nome': 'Idiomas', 'sel': 1, 'detalhe': 'Japonês'});
    expect(f.totalPositivo, 14 + 3 + 1);
  });

  test('bônus: tabela de custos fecha nos 15', () {
    final f = Ficha.criar();
    f.setBonusAtributo('Força', 1); // 5
    f.setBonusHabilidade('Briga', 2); // 4
    f.bonusArete = 1; // 4
    f.bonusForcaVontade = 2; // 2
    expect(f.bonusGasto, 15);
    expect(f.bonusRestante, 0);
    expect(f.areteFinal, 2);
    expect(f.forcaVontadeFinal, 7);
    expect(f.atributoFinal('Força'), 2);
    expect(f.habilidadeFinal('Briga'), 2);
  });

  test('Quintessência = Avatar + pacotes ×4 (Avatar 3 + 2 pacotes = 11)', () {
    final f = Ficha.criar();
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Avatar/Gênio', 'sel': 3, 'detalhe': ''});
    f.bonusQuintessencia = 2;
    expect(f.avatar, 3);
    expect(f.quintessencia, 11); // 3 + 2×4
    expect(f.bonusGasto, 2); // só os pacotes de Quintessência
    // Avatar entra no equilíbrio com Defeitos (positivos), não nos bônus:
    expect(f.totalPositivo, 3);
  });

  test('bônus: esfera custa 7/ponto; antecedentes NÃO entram nos bônus', () {
    final f = Ficha.criar();
    f.setBonusEsfera('forces', 1);
    f.adicionar('positivos',
        {'classe': 'antecedente', 'nome': 'Aprimoramento', 'sel': 1, 'detalhe': ''});
    expect(f.bonusGasto, 7); // só a Esfera; Aprimoramento vai nos positivos
    expect(f.totalPositivo, 2); // dobrado: 1 × 2
    expect(f.esferaFinal('forces'), 1);
    expect(GameData.custoBonus('antecedente'), 0); // não existe custo de bônus
  });

  test('afinidades: Ahl-i-Batin sem Entropia; Tradições canônicas; Órfãos qualquer', () {
    expect(GameData.opcoesAfinidade('Ahl-i-Batin'), isNot(contains('entropy')));
    expect(GameData.esferasBloqueadas('Ahl-i-Batin'), contains('entropy'));
    expect(GameData.opcoesAfinidade('Ordem de Hermes'), ['forces']);
    expect(GameData.opcoesAfinidade('Verbena'), ['life']);
    expect(GameData.opcoesAfinidade('Órfãos').length, 9);
    expect(GameData.opcoesAfinidade('Sindicato'),
        containsAll(['entropy', 'mind', 'prime']));
  });

  test('regras da mesa: atributos 4-3-3-3-2-2-2-2-1, hab 15/11/9 + espec 2/1/0, esferas 9/máx 3', () {
    final ra = GameData.atributos.regra;
    expect(ra.modo, 'distribuicao');
    expect(ra.distribuicao.map((d) => '${d.key}x${d.value}').toList(),
        ['4x1', '3x3', '2x4', '1x1']);
    final rh = GameData.habilidades.regra;
    expect(rh.modo, 'prioridade');
    expect(rh.pontosDe('primaria'), 15);
    expect(rh.pontosDe('secundaria'), 11);
    expect(rh.pontosDe('terciaria'), 9);
    expect(rh.especDe('primaria'), 2);
    expect(rh.especDe('secundaria'), 1);
    expect(rh.especDe('terciaria'), 0);
    expect(GameData.esferasPontosGratuitos, 6);
    expect(GameData.esferasMaximoCriacao, 3);
  });

  test('especializações: permitidas pela prioridade da coluna', () {
    final f = Ficha.criar();
    // padrão: Talentos=primaria(2), Perícias=secundaria(1), Conhecimentos=terciaria(0)
    expect(f.especPermitidas('Talentos'), 2);
    expect(f.especPermitidas('Perícias'), 1);
    expect(f.especPermitidas('Conhecimentos'), 0);
    f.adicionar('especializacoes', {'habilidade': 'Briga', 'nome': 'imobilização'});
    f.adicionar('especializacoes', {'habilidade': 'Lábia', 'nome': 'blefe'});
    final talentos = GameData.habilidades.categorias
        .firstWhere((c) => c.nome == 'Talentos');
    expect(f.especDaCategoria(talentos).length, 2);
  });

  test('personalizados: custo = valor escolhido, entra no equilíbrio', () {
    final f = Ficha.criar();
    f.adicionar('positivos', {
      'classe': 'antecedente', 'nome': 'Relíquia de Família', 'sel': 3,
      'detalhe': '', 'custom': true, 'descricao': 'Um anel ancestral.'});
    f.adicionar('positivos', {
      'classe': 'qualidade', 'nome': 'Sorte de Iniciante', 'sel': 2,
      'detalhe': '', 'custom': true, 'descricao': 'Uma vez por sessão...'});
    f.adicionar('defeitos', {
      'nome': 'Medo de Espelhos', 'sel': 5, 'detalhe': '', 'subtipo': '',
      'custom': true, 'descricao': 'Pânico ao ver reflexos.'});
    expect(f.totalPositivo, 5); // 3 + 2 (sem dobro, valor direto)
    expect(f.totalDefeito, 5);
  });

  test('habilidades personalizadas: gastam pontos da mesma coluna', () {
    final f = Ficha.criar();
    final talentos =
        GameData.habilidades.categorias.firstWhere((c) => c.nome == 'Talentos');
    f.setHabilidade('Briga', 3);
    expect(f.gastoHabilidades(talentos), 3);
    expect(f.orcamentoHabilidades('Talentos'), 15); // primária por padrão

    f.addHabilidadeExtra('Talentos', 'Intuição', 'Palpites certeiros.');
    expect(f.habilidade('Intuição'), 0);
    f.setHabilidade('Intuição', 2);
    expect(f.gastoHabilidades(talentos), 5); // 3 + 2, mesmo orçamento
    expect(f.tracosDaCategoria(talentos).length, 11 + 1);
    expect(f.extrasDaCategoria('Perícias'), isEmpty);
  });

  test('habilidades personalizadas: especialização, bônus e remoção', () {
    final f = Ficha.criar();
    final talentos =
        GameData.habilidades.categorias.firstWhere((c) => c.nome == 'Talentos');
    f.addHabilidadeExtra('Talentos', 'Intuição', '');
    f.setHabilidade('Intuição', 3);
    f.setBonusHabilidade('Intuição', 1);
    f.adicionar('especializacoes', {'habilidade': 'Intuição', 'nome': 'perigo'});
    expect(f.habilidadeFinal('Intuição'), 4);
    expect(f.especDaCategoria(talentos).length, 1);
    expect(f.bonusGasto, 2);

    f.removerHabilidadeExtra('Intuição');
    expect(f.habilidadesExtras, isEmpty);
    expect(f.habilidade('Intuição'), 0);
    expect(f.bonusGasto, 0);
    expect(f.especDaCategoria(talentos), isEmpty);
    expect(f.gastoHabilidades(talentos), 0);
  });

  test('nome duplicado de habilidade é detectável antes de criar', () {
    final f = Ficha.criar();
    expect(f.nomesHabilidades, contains('Briga'));
    f.addHabilidadeExtra('Talentos', 'Intuição', '');
    expect(f.nomesHabilidades, contains('Intuição'));
    expect(f.nomesHabilidades.length, 33 + 1);
  });

  test('ficha antiga (sem habilidadesExtras) continua funcionando', () {
    final f = Ficha({'id': 'x', 'habilidades': {'Briga': 2}});
    expect(f.habilidadesExtras, isEmpty);
    final talentos =
        GameData.habilidades.categorias.firstWhere((c) => c.nome == 'Talentos');
    expect(f.gastoHabilidades(talentos), 2);
  });

  test('grupo: afiliação + facção sem repetir nem "Nenhuma"', () {
    Ficha comGrupo(String a, String fc) =>
        Ficha({'id': 'x', 'afiliacao': a, 'faccao': fc});
    expect(comGrupo('Tradições', 'Verbena').grupo, 'Tradições / Verbena');
    expect(comGrupo('Nefandi / Caídos', 'Nefandi / Caídos').grupo,
        'Nefandi / Caídos');
    expect(comGrupo('Órfão / Independente', 'Nenhuma').grupo,
        'Órfão / Independente');
    expect(comGrupo('Desauridos / Loucos', 'Sem facção organizada').grupo,
        'Desauridos / Loucos');
    expect(comGrupo('Tecnocracia', '').grupo, 'Tecnocracia');
  });

  test('modoLivre: só grava quando escolhido; padrão vale pro resto', () {
    final nova = Ficha.criar();
    expect(nova.data.containsKey('modoLivre'), isFalse);
    expect(nova.modoLivreOu(false), isFalse); // criando → iniciante
    expect(nova.modoLivreOu(true), isTrue); // editando → livre
    nova.modoLivre = false; // escolha explícita do jogador
    expect(nova.modoLivreOu(true), isFalse); // respeitada mesmo editando
  });

  test('trackers de jogo: limites', () {
    final f = Ficha.criar();
    f.vitalidadeDano = 99;
    expect(f.vitalidadeDano, GameData.niveisVitalidade.length);
    f.fdvAtual = 99;
    expect(f.fdvAtual, 5);
    f.quintAtual = 99;
    expect(f.quintAtual, GameData.rodaQuintessencia);
    f.experiencia = -3;
    expect(f.experiencia, 0);
  });
}
