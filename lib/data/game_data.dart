import 'dart:convert';
import 'package:flutter/services.dart';

/// Item simples com nome + texto de regra (Natureza, Comportamento, traço...).
class ItemDescrito {
  final String nome;
  final String descricao;
  ItemDescrito(this.nome, this.descricao);
}

/// Uma facção pertencente a uma afiliação.
class Faccao {
  final String nome;
  final String resumo;
  Faccao(this.nome, this.resumo);
  factory Faccao.fromJson(Map<String, dynamic> j) =>
      Faccao(j['nome'] as String, (j['resumo'] ?? '') as String);
}

/// Uma afiliação (Tradições, Tecnocracia, Discrepantes, Órfão, etc.) e suas facções.
class Afiliacao {
  final String nome;
  final String descricao;
  final List<Faccao> faccoes;
  Afiliacao(this.nome, this.descricao, this.faccoes);
  factory Afiliacao.fromJson(Map<String, dynamic> j) => Afiliacao(
        j['nome'] as String,
        (j['descricao'] ?? '') as String,
        (j['faccoes'] as List)
            .map((e) => Faccao.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Um Conceito sugerido (com exemplos). A lista não é fechada.
class Conceito {
  final String nome;
  final String exemplos;
  Conceito(this.nome, this.exemplos);
  factory Conceito.fromJson(Map<String, dynamic> j) =>
      Conceito(j['nome'] as String, (j['exemplos'] ?? '') as String);
}

/// Uma categoria de traços (ex.: Físicos, ou Talentos) com seus traços.
class Categoria {
  final String nome;
  final List<ItemDescrito> tracos;
  Categoria(this.nome, this.tracos);
  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        j['nome'] as String,
        (j['tracos'] as List)
            .map((e) => ItemDescrito(
                (e as Map)['nome'] as String, (e['descricao'] ?? '') as String))
            .toList(),
      );
}

/// Uma prioridade de categoria (Principal/Secundário/Terciário) com pontos
/// e quantas especializações concede.
class Prioridade {
  final String chave; // primaria | secundaria | terciaria
  final String nome;
  final int pontos;
  final int especializacoes;
  Prioridade(this.chave, this.nome, this.pontos, [this.especializacoes = 0]);
  factory Prioridade.fromJson(Map<String, dynamic> j) => Prioridade(
        j['chave'] as String,
        j['nome'] as String,
        (j['pontos'] as num).toInt(),
        (j['especializacoes'] as num?)?.toInt() ?? 0,
      );
}

/// Regra de criação de um bloco de traços. Dois modos:
///  - "prioridade": cada categoria recebe Principal/Secundário/Terciário
///    com um orçamento de pontos (Habilidades).
///  - "distribuicao": forma fixa de valores finais, ex. 4-3-3-3-2-2-2-2-1
///    entre todos os traços (Atributos).
class RegraPrioridade {
  final String modo; // prioridade | distribuicao
  final int valorInicial; // 1 (atributos) ou 0 (habilidades)
  final int maximoCriacao; // teto de UM traço na criação
  final int maximo; // teto absoluto (5)
  final String texto;
  final List<Prioridade> prioridades;
  final List<MapEntry<int, int>> distribuicao; // valor -> quantidade
  RegraPrioridade(this.modo, this.valorInicial, this.maximoCriacao, this.maximo,
      this.texto, this.prioridades, this.distribuicao);
  factory RegraPrioridade.fromJson(Map<String, dynamic> j) => RegraPrioridade(
        (j['modo'] ?? 'prioridade') as String,
        (j['valor_inicial'] as num?)?.toInt() ?? 0,
        (j['maximo_criacao'] as num?)?.toInt() ?? 5,
        (j['maximo'] as num?)?.toInt() ?? 5,
        (j['texto'] ?? '') as String,
        (j['prioridades'] as List? ?? const [])
            .map((e) => Prioridade.fromJson(e as Map<String, dynamic>))
            .toList(),
        (j['distribuicao'] as List? ?? const [])
            .map((e) => MapEntry(((e as Map)['valor'] as num).toInt(),
                (e['quantidade'] as num).toInt()))
            .toList(),
      );

  Prioridade prioridadeDe(String chave) => prioridades.firstWhere(
      (p) => p.chave == chave,
      orElse: () => Prioridade(chave, chave, 0));

  int pontosDe(String chave) => prioridadeDe(chave).pontos;
  int especDe(String chave) => prioridadeDe(chave).especializacoes;

  List<String> get chaves => prioridades.map((p) => p.chave).toList();
}

/// Uma Esfera da mágika (chave interna + nome PT + descrição).
class Esfera {
  final String chave;
  final String nome;
  final String descricao;
  Esfera(this.chave, this.nome, this.descricao);
  factory Esfera.fromJson(Map<String, dynamic> j) => Esfera(
      j['chave'] as String, j['nome'] as String, (j['descricao'] ?? '') as String);
}

/// Bloco de traços = categorias + regra de prioridade (atributos OU habilidades).
class BlocoTracos {
  final List<Categoria> categorias;
  final RegraPrioridade regra;
  BlocoTracos(this.categorias, this.regra);

  List<String> get nomes => [
        for (final c in categorias)
          for (final t in c.tracos) t.nome,
      ];

  String descricao(String nome) {
    for (final c in categorias) {
      for (final t in c.tracos) {
        if (t.nome == nome) return t.descricao;
      }
    }
    return '';
  }
}

/// Especificação de custo de uma Qualidade ou Defeito.
/// tipos: fixo | opcoes | faixa | porPonto | instancia.
class CustoSpec {
  final String tipo;
  final int valor; // fixo / instancia
  final List<int> valores; // opcoes
  final int min, max; // faixa / porPonto (graduação)
  final int unidade; // porPonto (multiplicador)
  final String rotulo; // instancia (rótulo do detalhe, ex.: "Idioma")
  CustoSpec({
    this.tipo = 'fixo',
    this.valor = 0,
    this.valores = const [],
    this.min = 1,
    this.max = 5,
    this.unidade = 1,
    this.rotulo = '',
  });
  factory CustoSpec.fromJson(Map<String, dynamic> j) => CustoSpec(
        tipo: (j['tipo'] ?? 'fixo') as String,
        valor: (j['valor'] as num?)?.toInt() ?? 0,
        valores: (j['valores'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        min: (j['min'] as num?)?.toInt() ?? 1,
        max: (j['max'] as num?)?.toInt() ?? 5,
        unidade: (j['unidade'] as num?)?.toInt() ?? 1,
        rotulo: (j['rotulo'] ?? '') as String,
      );

  /// O item precisa que o jogador escolha um número (graduação/opção)?
  bool get temSelecao =>
      tipo == 'opcoes' || tipo == 'faixa' || tipo == 'porPonto';

  /// Valores que o jogador pode escolher no seletor (vazio = sem seleção).
  List<int> get opcoesSelecao {
    switch (tipo) {
      case 'opcoes':
        return valores;
      case 'faixa':
      case 'porPonto':
        return [for (int i = min; i <= max; i++) i];
      default:
        return const [];
    }
  }

  /// Custo em pontos dado o valor escolhido [sel].
  int custo(int sel) {
    switch (tipo) {
      case 'opcoes':
      case 'faixa':
        return sel;
      case 'porPonto':
        return sel * unidade;
      default: // fixo, instancia
        return valor;
    }
  }

  /// Valor inicial sugerido ao adicionar.
  int get selInicial {
    switch (tipo) {
      case 'opcoes':
        return valores.isEmpty ? 0 : valores.first;
      case 'faixa':
      case 'porPonto':
        return min;
      default:
        return valor;
    }
  }
}

/// Antecedente (vantagem positiva). Alguns custam o dobro (grad × 2).
class Antecedente {
  final String nome, resumo;
  final bool dobrado, restrito, avatar;
  Antecedente(this.nome, this.resumo, this.dobrado, this.restrito, this.avatar);
  factory Antecedente.fromJson(Map<String, dynamic> j) => Antecedente(
        j['nome'] as String,
        (j['resumo'] ?? '') as String,
        j['dobrado'] == true,
        j['restrito'] == true,
        j['avatar'] == true,
      );
  int custo(int grad) => grad * (dobrado ? 2 : 1);
}

/// Qualidade (vantagem positiva comprada com pontos, não com bônus).
class Qualidade {
  final String nome, resumo, exclui;
  final bool repetivel;
  final CustoSpec custoSpec;
  Qualidade(
      this.nome, this.resumo, this.exclui, this.repetivel, this.custoSpec);
  factory Qualidade.fromJson(Map<String, dynamic> j) => Qualidade(
        j['nome'] as String,
        (j['resumo'] ?? '') as String,
        (j['exclui'] ?? '') as String,
        j['repetivel'] == true,
        CustoSpec.fromJson((j['custo'] ?? const {}) as Map<String, dynamic>),
      );
}

/// Defeito (desvantagem; nesta mesa só equilibra os positivos).
class Defeito {
  final String nome, resumo, exclui;
  final CustoSpec custoSpec;
  final List<String> subtipos;
  Defeito(this.nome, this.resumo, this.exclui, this.custoSpec, this.subtipos);
  factory Defeito.fromJson(Map<String, dynamic> j) => Defeito(
        j['nome'] as String,
        (j['resumo'] ?? '') as String,
        (j['exclui'] ?? '') as String,
        CustoSpec.fromJson((j['custo'] ?? const {}) as Map<String, dynamic>),
        List<String>.from(j['subtipos'] ?? const []),
      );
}

/// Dados estáticos do sistema, carregados dos assets JSON uma vez no início.
class GameData {
  static late List<ItemDescrito> naturezas;
  static late List<ItemDescrito> comportamentos;
  static late List<ItemDescrito> essencias;
  static late List<Afiliacao> afiliacoes;
  static late List<Conceito> conceitos;
  static late List<String> conceitosPersonalizados;

  static late BlocoTracos atributos;
  static late BlocoTracos habilidades;

  // ---- Esferas ----
  static late List<Esfera> esferas;
  static late int esferasPontosGratuitos;
  static late int esferasMaximoCriacao;
  static late int areteInicial;
  static late int forcaVontadeInicial;
  static late int paradoxoInicial;
  static late String esferasRegraTexto;
  static late Map<String, List<String>> _afinidades; // faccao -> [chaves] ou ["*"]
  static late Map<String, List<String>> _bloqueios; // faccao -> [chaves bloqueadas]

  // ---- Antecedentes / Qualidades / Defeitos ----
  static late List<Antecedente> antecedentes;
  static late List<Qualidade> qualidades;
  static late List<Defeito> defeitos;
  static late List<String> defeitosGeneticos;
  static late String defeitosGeneticosTexto;

  // ---- Toques Finais (15 pontos de bônus) ----
  static late int bonusTotal;
  static late Map<String, int> _custosBonus;
  static late int quintessenciaPacote;
  static late int areteMaximoCriacao;
  static late int forcaVontadeMaxima;
  static late String bonusTexto;

  /// Níveis de Vitalidade da ficha (nome, penalidade) — fixos, não configuráveis.
  static const niveisVitalidade = [
    ['Escoriado', '0'],
    ['Machucado', '-1'],
    ['Ferido', '-1'],
    ['Ferido Gravemente', '-2'],
    ['Espancado', '-2'],
    ['Aleijado', '-5'],
    ['Incapacitado', '—'],
  ];

  /// Tamanho da roda de Quintessência/Paradoxo da ficha (20 espaços).
  static const rodaQuintessencia = 20;

  static Future<void> carregar() async {
    naturezas = await _itens('assets/data/naturezas.json', 'naturezas');
    comportamentos =
        await _itens('assets/data/comportamentos.json', 'comportamentos');
    essencias = await _itens('assets/data/essencias.json', 'essencias');

    final afi = jsonDecode(await rootBundle
        .loadString('assets/data/afiliacoes.json')) as Map<String, dynamic>;
    afiliacoes = (afi['afiliacoes'] as List)
        .map((e) => Afiliacao.fromJson(e as Map<String, dynamic>))
        .toList();

    final con = jsonDecode(await rootBundle
        .loadString('assets/data/conceitos.json')) as Map<String, dynamic>;
    conceitos = (con['conceitos'] as List)
        .map((e) => Conceito.fromJson(e as Map<String, dynamic>))
        .toList();
    conceitosPersonalizados =
        List<String>.from(con['exemplos_personalizados'] ?? const []);

    atributos = await _bloco('assets/data/atributos.json');
    habilidades = await _bloco('assets/data/habilidades.json');

    final esf = jsonDecode(await rootBundle
        .loadString('assets/data/esferas.json')) as Map<String, dynamic>;
    esferas = (esf['esferas'] as List)
        .map((e) => Esfera.fromJson(e as Map<String, dynamic>))
        .toList();
    final rc = (esf['regra_criacao'] ?? {}) as Map<String, dynamic>;
    esferasPontosGratuitos = (rc['pontos_gratuitos'] as num?)?.toInt() ?? 9;
    esferasMaximoCriacao = (rc['maximo_criacao'] as num?)?.toInt() ?? 3;
    areteInicial = (rc['arete_inicial'] as num?)?.toInt() ?? 1;
    forcaVontadeInicial = (rc['forca_vontade_inicial'] as num?)?.toInt() ?? 5;
    paradoxoInicial = (rc['paradoxo_inicial'] as num?)?.toInt() ?? 0;
    esferasRegraTexto = (rc['texto'] ?? '') as String;
    _afinidades = ((esf['afinidades'] ?? {}) as Map).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)));
    _bloqueios = ((esf['bloqueios'] ?? {}) as Map).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)));

    final ant = jsonDecode(await rootBundle
        .loadString('assets/data/antecedentes.json')) as Map<String, dynamic>;
    antecedentes = (ant['antecedentes'] as List)
        .map((e) => Antecedente.fromJson(e as Map<String, dynamic>))
        .toList();

    final qua = jsonDecode(await rootBundle
        .loadString('assets/data/qualidades.json')) as Map<String, dynamic>;
    qualidades = (qua['qualidades'] as List)
        .map((e) => Qualidade.fromJson(e as Map<String, dynamic>))
        .toList();

    final def = jsonDecode(await rootBundle
        .loadString('assets/data/defeitos.json')) as Map<String, dynamic>;
    defeitos = (def['defeitos'] as List)
        .map((e) => Defeito.fromJson(e as Map<String, dynamic>))
        .toList();
    final gen = (def['geneticos'] ?? const {}) as Map<String, dynamic>;
    defeitosGeneticos = List<String>.from(gen['tipos'] ?? const []);
    defeitosGeneticosTexto = (gen['descricao'] ?? '') as String;

    final bon = jsonDecode(await rootBundle
        .loadString('assets/data/bonus.json')) as Map<String, dynamic>;
    bonusTotal = (bon['total'] as num?)?.toInt() ?? 15;
    _custosBonus = ((bon['custos'] ?? {}) as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    quintessenciaPacote = (bon['quintessencia_pacote'] as num?)?.toInt() ?? 4;
    areteMaximoCriacao = (bon['arete_maximo_criacao'] as num?)?.toInt() ?? 3;
    forcaVontadeMaxima = (bon['forca_vontade_maxima'] as num?)?.toInt() ?? 10;
    bonusTexto = (bon['texto'] ?? '') as String;
  }

  /// Custo em pontos de bônus por ponto da característica [chave]
  /// (atributo, habilidade, antecedente, esfera, arete, forcaVontade, quintessencia).
  static int custoBonus(String chave) => _custosBonus[chave] ?? 0;

  static Antecedente? antecedentePorNome(String? n) {
    for (final a in antecedentes) {
      if (a.nome == n) return a;
    }
    return null;
  }

  static Qualidade? qualidadePorNome(String? n) {
    for (final q in qualidades) {
      if (q.nome == n) return q;
    }
    return null;
  }

  static Defeito? defeitoPorNome(String? n) {
    for (final d in defeitos) {
      if (d.nome == n) return d;
    }
    return null;
  }

  /// Nome do Antecedente marcado como Avatar (para a Quintessência inicial).
  static String get nomeAvatar {
    for (final a in antecedentes) {
      if (a.avatar) return a.nome;
    }
    return 'Avatar/Gênio';
  }

  /// Custo em pontos positivos de uma entrada {classe, nome, sel}.
  /// Entradas personalizadas ({custom: true}) valem o próprio sel.
  static int custoPositivo(Map<String, dynamic> e) {
    final sel = (e['sel'] as num?)?.toInt() ?? 1;
    if (e['custom'] == true) return sel;
    if (e['classe'] == 'antecedente') {
      return antecedentePorNome(e['nome'] as String?)?.custo(sel) ?? sel;
    }
    final q = qualidadePorNome(e['nome'] as String?);
    return q?.custoSpec.custo(sel) ?? 0;
  }

  /// Custo em pontos negativos de uma entrada de Defeito {nome, sel}.
  /// Entradas personalizadas ({custom: true}) valem o próprio sel.
  static int custoDefeito(Map<String, dynamic> e) {
    final sel = (e['sel'] as num?)?.toInt() ?? 1;
    if (e['custom'] == true) return sel;
    return defeitoPorNome(e['nome'] as String?)?.custoSpec.custo(sel) ?? 0;
  }

  static List<String> get chavesEsferas =>
      esferas.map((e) => e.chave).toList();

  static Esfera? esferaPorChave(String? chave) {
    if (chave == null) return null;
    for (final e in esferas) {
      if (e.chave == chave) return e;
    }
    return null;
  }

  /// Chaves das Esferas bloqueadas para uma Facção (ex.: Ahl-i-Batin → entropy).
  static Set<String> esferasBloqueadas(String faccao) =>
      (_bloqueios[faccao] ?? const <String>[]).toSet();

  /// Esferas permitidas como Afinidade para a Facção (já sem as bloqueadas).
  /// Facção vazia/desconhecida ou "*" → todas as nove.
  static List<String> opcoesAfinidade(String faccao) {
    final def = _afinidades[faccao];
    final bloq = esferasBloqueadas(faccao);
    final base = (def == null || def.contains('*')) ? chavesEsferas : def;
    return base.where((c) => !bloq.contains(c)).toList();
  }

  static Future<BlocoTracos> _bloco(String path) async {
    final j =
        jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
    final cats = (j['categorias'] as List)
        .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
        .toList();
    final regra = RegraPrioridade.fromJson(
        (j['regra_criacao'] ?? {}) as Map<String, dynamic>);
    return BlocoTracos(cats, regra);
  }

  static Future<List<ItemDescrito>> _itens(String path, String chave) async {
    final j =
        jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
    return (j[chave] as List)
        .map((e) => ItemDescrito(
              (e as Map)['nome'] as String,
              (e['resumo'] ?? e['descricao'] ?? '') as String,
            ))
        .toList();
  }

  static String descricaoDe(List<ItemDescrito> lista, String nome) =>
      lista.firstWhere((e) => e.nome == nome,
          orElse: () => ItemDescrito(nome, '')).descricao;

  static Afiliacao? afiliacaoPorNome(String? nome) {
    if (nome == null) return null;
    for (final a in afiliacoes) {
      if (a.nome == nome) return a;
    }
    return null;
  }
}
