import 'package:uuid/uuid.dart';
import '../data/game_data.dart';

/// Ficha de personagem de Mago: A Ascensão. Guarda tudo num Map (serializa
/// fácil pro Hive como JSON) e expõe acessos tipados.
///
/// Estrutura da criação:
///  1. Identidade  2. Atributos  3. Habilidades  4. Esferas
///  5. Antecedentes/Qualidades & Defeitos  6. Toques Finais (15 bônus)
///  7. Detalhes  8. Revisão
///
/// Os valores das telas 2–4 são os pontos GRATUITOS da criação; os aumentos
/// dos Toques Finais ficam separados em `bonus` — assim cada orçamento valida
/// sozinho e o gasto de bônus é sempre auditável. Valor final = grátis + bônus.
class Ficha {
  final Map<String, dynamic> data;
  Ficha(this.data);

  factory Ficha.criar() {
    return Ficha({
      'id': const Uuid().v4(),
      // ---- 1: Identidade ----
      'nome': '',
      'jogador': '',
      'cronica': '',
      'natureza': '',
      'comportamento': '',
      'essencia': '',
      'afiliacao': '',
      'faccao': '',
      'conceito': '',
      // ---- 2: Atributos ----
      'atributos': _valoresIniciais(GameData.atributos),
      'atributosPrioridade': _prioridadesPadrao(GameData.atributos),
      // ---- 3: Habilidades ----
      'habilidades': _valoresIniciais(GameData.habilidades),
      'habilidadesPrioridade': _prioridadesPadrao(GameData.habilidades),
      'especializacoes': <Map<String, dynamic>>[], // {habilidade, nome}
      // Habilidades opcionais do livro (não estão na lista padrão da ficha).
      // Gastam pontos da MESMA coluna: {categoria, nome, descricao}
      'habilidadesExtras': <Map<String, dynamic>>[],
      // ---- 4: Esferas + vantagens-base ----
      'esferas': {for (final c in GameData.chavesEsferas) c: 0},
      'afinidade': '',
      'arete': GameData.areteInicial,
      'forcaVontade': GameData.forcaVontadeInicial,
      'paradoxo': GameData.paradoxoInicial,
      // ---- 5: Antecedentes/Qualidades (positivos) + Defeitos ----
      'positivos': <Map<String, dynamic>>[], // {classe, nome, sel, detalhe}
      'defeitos': <Map<String, dynamic>>[], // {nome, sel, detalhe, subtipo}
      'defeitosGeneticos': <Map<String, dynamic>>[], // {nome} (valor 0)
      // ---- 6: Toques Finais (15 pontos de bônus, travados) ----
      'bonus': _bonusVazio(),
      // ---- 7: Detalhes (página 2 da ficha) ----
      'historia': '',
      'objetivosDestino': '',
      'rotinas': '',
      'focos': '',
      'maravilhas': <Map<String, dynamic>>[], // {nome, descricao}
      'aparencia': {
        'idade': '',
        'idadeAparente': '',
        'sexo': '',
        'etnia': '',
        'cabelos': '',
        'olhos': '',
        'altura': '',
        'peso': '',
        'descricao': '',
      },
      'itensEquipamentos': '',
      'combate': <Map<String, dynamic>>[], // {arma, dif, dano, tipo, alcance, cadencia}
      'outrasCaracteristicas': <Map<String, dynamic>>[], // {nome, valor}
      'notas': '',
      // ---- Estado de jogo (trackers da ficha) ----
      'vitalidadeDano': 0,
      'experiencia': 0,
      'criadoEm': DateTime.now().toIso8601String(),
      'atualizadoEm': DateTime.now().toIso8601String(),
    });
  }

  static Map<String, dynamic> _valoresIniciais(BlocoTracos b) =>
      {for (final n in b.nomes) n: b.regra.valorInicial};

  static Map<String, dynamic> _prioridadesPadrao(BlocoTracos b) {
    final chaves = b.regra.chaves;
    final m = <String, dynamic>{};
    for (int i = 0; i < b.categorias.length; i++) {
      m[b.categorias[i].nome] =
          i < chaves.length ? chaves[i] : (chaves.isEmpty ? '' : chaves.last);
    }
    return m;
  }

  static Map<String, dynamic> _bonusVazio() => {
        'atributos': <String, dynamic>{},
        'habilidades': <String, dynamic>{},
        'esferas': <String, dynamic>{},
        'arete': 0,
        'forcaVontade': 0,
        'quintessencia': 0, // pacotes (cada um = +4 Quintessência)
      };

  String get id => data['id'] as String;

  /// Modo da ficha:
  ///  * `false` (iniciante) — o wizard cobra as regras de criação.
  ///  * `true` (livre/mestre) — limites viram avisos; dá pra ultrapassar.
  /// Fichas antigas (sem o campo) já estão prontas: entram como livres.
  bool get modoLivre => data['modoLivre'] == true;
  set modoLivre(bool v) => data['modoLivre'] = v;

  /// Modo gravado na ficha; se ela não tiver o campo (ficha antiga, já pronta),
  /// vale [padrao].
  bool modoLivreOu(bool padrao) => (data['modoLivre'] as bool?) ?? padrao;

  String _s(String k) => (data[k] ?? '') as String;
  int _i(String k, int padrao) => (data[k] as num?)?.toInt() ?? padrao;

  String get nome => _s('nome');
  String get jogador => _s('jogador');
  String get cronica => _s('cronica');
  String get natureza => _s('natureza');
  String get comportamento => _s('comportamento');
  String get essencia => _s('essencia');
  String get afiliacao => _s('afiliacao');
  String get faccao => _s('faccao');
  String get conceito => _s('conceito');

  /// Afiliação + Facção sem repetição, para mostrar em lista/cabeçalho.
  /// Afiliações sem subdivisão (Nefandi, Órfão…) repetiam o mesmo nome duas
  /// vezes; facção "vazia" ('Nenhuma', 'Sem facção organizada') também não
  /// acrescenta nada.
  String get grupo {
    const vazias = {'Nenhuma', 'Sem facção organizada', 'Nenhum'};
    final a = afiliacao.trim();
    final fc = faccao.trim();
    if (fc.isEmpty || fc == a || vazias.contains(fc)) return a;
    if (a.isEmpty) return fc;
    return '$a / $fc';
  }

  // ---- Traços (atributos / habilidades), acesso genérico ----
  Map<String, dynamic> _mapa(String chave, BlocoTracos b) {
    if (data[chave] is! Map) data[chave] = _valoresIniciais(b);
    return (data[chave] as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> _prioridades(String chave, BlocoTracos b) {
    if (data[chave] is! Map) data[chave] = _prioridadesPadrao(b);
    return (data[chave] as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> get atributos => _mapa('atributos', GameData.atributos);
  Map<String, dynamic> get atributosPrioridade =>
      _prioridades('atributosPrioridade', GameData.atributos);

  Map<String, dynamic> get habilidades =>
      _mapa('habilidades', GameData.habilidades);
  Map<String, dynamic> get habilidadesPrioridade =>
      _prioridades('habilidadesPrioridade', GameData.habilidades);

  int atributo(String nome) => (atributos[nome] as num?)?.toInt() ?? 1;
  void setAtributo(String nome, int v) => atributos[nome] = v;

  int habilidade(String nome) => (habilidades[nome] as num?)?.toInt() ?? 0;
  void setHabilidade(String nome, int v) => habilidades[nome] = v;

  // ---- Habilidades personalizadas (opcionais do livro) ----
  /// Entradas {categoria, nome, descricao}. O VALOR mora no mapa `habilidades`
  /// (mesma chave = nome), então elas gastam pontos da coluna como as padrão.
  List<Map<String, dynamic>> get habilidadesExtras =>
      _lista('habilidadesExtras');

  /// Habilidades personalizadas da categoria [categoria], como traços.
  List<ItemDescrito> extrasDaCategoria(String categoria) => [
        for (final e in habilidadesExtras)
          if (e['categoria'] == categoria)
            ItemDescrito('${e['nome']}', '${e['descricao'] ?? ''}'),
      ];

  /// Todos os traços da categoria: os padrão + os personalizados.
  List<ItemDescrito> tracosDaCategoria(Categoria cat) =>
      [...cat.tracos, ...extrasDaCategoria(cat.nome)];

  /// Nomes já usados (padrão + personalizados) — para barrar duplicata.
  Set<String> get nomesHabilidades => {
        ...GameData.habilidades.nomes,
        ...habilidadesExtras.map((e) => '${e['nome']}'),
      };

  void addHabilidadeExtra(String categoria, String nome, String descricao) {
    adicionar('habilidadesExtras',
        {'categoria': categoria, 'nome': nome, 'descricao': descricao});
    habilidades[nome] ??= 0;
  }

  /// Remove a habilidade personalizada e tudo que dependia dela
  /// (valor, bônus e especializações).
  void removerHabilidadeExtra(String nome) {
    habilidadesExtras.removeWhere((e) => e['nome'] == nome);
    habilidades.remove(nome);
    _bonusSub('habilidades').remove(nome);
    especializacoes.removeWhere((e) => e['habilidade'] == nome);
  }

  // ---- Especializações de Habilidade (por prioridade da coluna) ----
  List<Map<String, dynamic>> get especializacoes => _lista('especializacoes');

  /// Especializações pertencentes às habilidades da categoria [cat]
  /// (incluindo as personalizadas dessa coluna).
  List<Map<String, dynamic>> especDaCategoria(Categoria cat) {
    final nomes = tracosDaCategoria(cat).map((t) => t.nome).toSet();
    return especializacoes
        .where((e) => nomes.contains(e['habilidade']))
        .toList();
  }

  /// Quantas especializações a categoria [catNome] pode ter (pela prioridade).
  int especPermitidas(String catNome) {
    final chave = habilidadesPrioridade[catNome] as String? ?? '';
    return GameData.habilidades.regra.especDe(chave);
  }

  /// Pontos gastos numa coluna de Habilidades (padrão + personalizadas).
  int gastoHabilidades(Categoria cat) {
    final ini = GameData.habilidades.regra.valorInicial;
    var t = 0;
    for (final tr in tracosDaCategoria(cat)) {
      t += habilidade(tr.nome) - ini;
    }
    return t;
  }

  /// Orçamento de pontos da coluna [catNome], pela prioridade escolhida.
  int orcamentoHabilidades(String catNome) => GameData.habilidades.regra
      .pontosDe(habilidadesPrioridade[catNome] as String? ?? '');

  // ---- Esferas + vantagens-base ----
  Map<String, dynamic> get esferas {
    if (data['esferas'] is! Map) {
      data['esferas'] = {for (final c in GameData.chavesEsferas) c: 0};
    }
    return (data['esferas'] as Map).cast<String, dynamic>();
  }

  int esfera(String chave) => (esferas[chave] as num?)?.toInt() ?? 0;
  void setEsfera(String chave, int v) => esferas[chave] = v;

  String get afinidade => _s('afinidade');
  set afinidade(String v) => data['afinidade'] = v;

  int get arete => _i('arete', GameData.areteInicial);
  int get forcaVontade => _i('forcaVontade', GameData.forcaVontadeInicial);
  int get paradoxo => _i('paradoxo', GameData.paradoxoInicial);

  /// Soma dos pontos gratuitos gastos em Esferas.
  int get esferasGasto {
    var t = 0;
    for (final c in GameData.chavesEsferas) {
      t += esfera(c);
    }
    return t;
  }

  // ---- Antecedentes/Qualidades (positivos) + Defeitos ----
  List<Map<String, dynamic>> _lista(String k) {
    if (data[k] is! List) data[k] = <Map<String, dynamic>>[];
    return (data[k] as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get positivos => _lista('positivos');
  List<Map<String, dynamic>> get defeitos => _lista('defeitos');
  List<Map<String, dynamic>> get defeitosGeneticos =>
      _lista('defeitosGeneticos');

  void adicionar(String lista, Map<String, dynamic> e) {
    _lista(lista);
    (data[lista] as List).add(e);
  }

  void remover(String lista, int i) {
    _lista(lista);
    (data[lista] as List).removeAt(i);
  }

  int get totalPositivo {
    var t = 0;
    for (final e in positivos) {
      t += GameData.custoPositivo(e);
    }
    return t;
  }

  int get totalDefeito {
    var t = 0;
    for (final e in defeitos) {
      t += GameData.custoDefeito(e);
    }
    return t;
  }

  /// Avatar-base = graduação do Antecedente Avatar/Gênio entre os positivos.
  int get avatar {
    for (final e in positivos) {
      if (e['classe'] == 'antecedente' && e['nome'] == GameData.nomeAvatar) {
        return (e['sel'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  // ---- Toques Finais: 15 pontos de bônus (travados) ----
  Map<String, dynamic> get bonus {
    if (data['bonus'] is! Map) data['bonus'] = _bonusVazio();
    return (data['bonus'] as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> _bonusSub(String k) {
    final b = bonus;
    if (b[k] is! Map) b[k] = <String, dynamic>{};
    return (b[k] as Map).cast<String, dynamic>();
  }

  int _bonusDe(String sub, String nome) =>
      (_bonusSub(sub)[nome] as num?)?.toInt() ?? 0;

  int bonusAtributo(String n) => _bonusDe('atributos', n);
  void setBonusAtributo(String n, int v) => _bonusSub('atributos')[n] = v;

  int bonusHabilidade(String n) => _bonusDe('habilidades', n);
  void setBonusHabilidade(String n, int v) => _bonusSub('habilidades')[n] = v;

  int bonusEsfera(String c) => _bonusDe('esferas', c);
  void setBonusEsfera(String c, int v) => _bonusSub('esferas')[c] = v;

  int get bonusArete => (bonus['arete'] as num?)?.toInt() ?? 0;
  set bonusArete(int v) => bonus['arete'] = v;

  int get bonusForcaVontade => (bonus['forcaVontade'] as num?)?.toInt() ?? 0;
  set bonusForcaVontade(int v) => bonus['forcaVontade'] = v;

  int get bonusQuintessencia => (bonus['quintessencia'] as num?)?.toInt() ?? 0;
  set bonusQuintessencia(int v) => bonus['quintessencia'] = v;

  /// Total de pontos de bônus gastos (sempre ≤ 15).
  /// Antecedentes, Qualidades e Defeitos NUNCA entram aqui — são a categoria
  /// positiva equilibrada pelos Defeitos, fora dos 15.
  int get bonusGasto {
    var t = 0;
    _bonusSub('atributos').forEach(
        (_, v) => t += ((v as num?)?.toInt() ?? 0) * GameData.custoBonus('atributo'));
    _bonusSub('habilidades').forEach(
        (_, v) => t += ((v as num?)?.toInt() ?? 0) * GameData.custoBonus('habilidade'));
    _bonusSub('esferas').forEach(
        (_, v) => t += ((v as num?)?.toInt() ?? 0) * GameData.custoBonus('esfera'));
    t += bonusArete * GameData.custoBonus('arete');
    t += bonusForcaVontade * GameData.custoBonus('forcaVontade');
    t += bonusQuintessencia * GameData.custoBonus('quintessencia');
    return t;
  }

  int get bonusRestante => GameData.bonusTotal - bonusGasto;

  // ---- Valores FINAIS (grátis + bônus) ----
  int atributoFinal(String n) => atributo(n) + bonusAtributo(n);
  int habilidadeFinal(String n) => habilidade(n) + bonusHabilidade(n);
  int esferaFinal(String c) => esfera(c) + bonusEsfera(c);
  int get areteFinal => arete + bonusArete;
  int get forcaVontadeFinal => forcaVontade + bonusForcaVontade;

  /// Quintessência inicial = Avatar + pacotes de bônus × 4.
  int get quintessencia =>
      avatar + bonusQuintessencia * GameData.quintessenciaPacote;

  // ---- Detalhes (página 2) ----
  Map<String, dynamic> get aparencia {
    if (data['aparencia'] is! Map) data['aparencia'] = <String, dynamic>{};
    return (data['aparencia'] as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> get maravilhas => _lista('maravilhas');
  List<Map<String, dynamic>> get combate => _lista('combate');
  List<Map<String, dynamic>> get outrasCaracteristicas =>
      _lista('outrasCaracteristicas');

  // ---- Estado de jogo (trackers) ----
  int get vitalidadeDano => _i('vitalidadeDano', 0);
  set vitalidadeDano(int v) => data['vitalidadeDano'] =
      v.clamp(0, GameData.niveisVitalidade.length);

  int get fdvAtual =>
      ((data['fdvAtual'] as num?)?.toInt() ?? forcaVontadeFinal)
          .clamp(0, forcaVontadeFinal);
  set fdvAtual(int v) => data['fdvAtual'] = v.clamp(0, forcaVontadeFinal);

  int get quintAtual => ((data['quintAtual'] as num?)?.toInt() ?? quintessencia)
      .clamp(0, GameData.rodaQuintessencia);
  set quintAtual(int v) =>
      data['quintAtual'] = v.clamp(0, GameData.rodaQuintessencia);

  int get paradoxoAtual => ((data['paradoxoAtual'] as num?)?.toInt() ?? paradoxo)
      .clamp(0, GameData.rodaQuintessencia);
  set paradoxoAtual(int v) =>
      data['paradoxoAtual'] = v.clamp(0, GameData.rodaQuintessencia);

  int get experiencia => _i('experiencia', 0);
  set experiencia(int v) => data['experiencia'] = v < 0 ? 0 : v;

  Map<String, dynamic> toJson() => data;
}
