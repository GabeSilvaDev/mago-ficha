# Fase 5 — Área do Narrador — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma área própria para o narrador: cadernos de anotação com imagens, campos customizados por personagem, galeria de cards estilo Notion com ordenação e filtro, e fichas de NPC leves.

**Architecture:** NPC é uma `Ficha` com `tipo: 'npc'` — o model já é um `Map` sem esquema, então NPC reaproveita serialização, retrato, backup e PDF sem duplicar nada; o que muda é só o caminho de criação. Os campos customizados têm definição global (box `narrador`) e valores por ficha (`data['campos']`); campos do tipo `derivado` leem direto da ficha, o que permite ordenar por Arete ou Afiliação sem redigitar. Os cadernos moram na box `notas` e referenciam imagens pelo id do `ImagemStore` da Fase 3.

**Tech Stack:** Flutter, Hive, `flutter_test`, `archive` (extensão do backup da Fase 4).

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`.
- Código, comentários e textos em português do Brasil.
- Depende das Fases 1–4 (usa `ImagemStore`, `RetratoAvatar`, `BackupIO`).
- Ficha sem `tipo` é PC; ficha sem `campos` tem `{}` — nenhuma migração destrutiva.
- A aba "Magos" continua sendo a lista de hoje, sem mudança de comportamento.
- Backup continua na `versao: 1`: a Fase 4 já ignora pastas desconhecidas, então zip novo abre em app antigo (só perde a parte do narrador).
- Testes de store usam `Hive.init('build/test-hive-<nome>')`.
- Rodar `flutter analyze` antes de cada commit; zero warning novo.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: NPC e valores de campo na `Ficha`

**Files:**
- Modify: `lib/models/ficha.dart`
- Test: `test/ficha_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `Ficha.tipo` → `String` (`'pc'` ou `'npc'`; ausente = `'pc'`)
  - `Ficha.ehNpc` → `bool`
  - `Ficha.criarNpc()` → `Ficha` (factory)
  - `Ficha.campos` → `Map<String, dynamic>`
  - `Ficha.campo(String id)` → `dynamic`
  - `Ficha.setCampo(String id, dynamic valor)` → `void` (valor nulo/vazio remove a chave)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ficha_test.dart`:

```dart
  test('ficha nova é PC; NPC é marcado no tipo', () {
    expect(Ficha.criar().ehNpc, isFalse);
    expect(Ficha.criar().tipo, 'pc');
    final npc = Ficha.criarNpc();
    expect(npc.ehNpc, isTrue);
    expect(npc.tipo, 'npc');
    expect(npc.id, isNotEmpty);
  });

  test('ficha antiga sem tipo entra como PC', () {
    expect(Ficha({'id': 'x'}).ehNpc, isFalse);
  });

  test('campos customizados: grava, lê e apaga', () {
    final f = Ficha.criar();
    expect(f.campos, isEmpty);
    f.setCampo('c1', 'Vivo');
    f.setCampo('c2', 4);
    expect(f.campo('c1'), 'Vivo');
    expect(f.campo('c2'), 4);
    f.setCampo('c1', null);
    expect(f.campo('c1'), isNull);
    f.setCampo('c2', '');
    expect(f.campos, isEmpty);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_test.dart`
Expected: FAIL — `The getter 'ehNpc' isn't defined for the type 'Ficha'`.

- [ ] **Step 3: Implementar**

Em `lib/models/ficha.dart`, acrescentar a factory ao lado de `Ficha.criar()`:

```dart
  /// NPC do narrador: mesma estrutura da ficha de jogador, marcada no `tipo`.
  /// Assim ele entra na galeria, no retrato, no backup e no PDF sem código
  /// duplicado — o que muda é só o caminho de criação (formulário curto).
  factory Ficha.criarNpc() {
    final f = Ficha.criar();
    f.data['tipo'] = 'npc';
    f.data['modoLivre'] = true; // NPC não passa pelo orçamento da criação
    return f;
  }
```

E, junto dos getters de identidade:

```dart
  /// 'pc' (padrão) ou 'npc'.
  String get tipo => (data['tipo'] as String?) ?? 'pc';
  bool get ehNpc => tipo == 'npc';

  /// Valores dos campos customizados do narrador, por id do campo.
  Map<String, dynamic> get campos {
    if (data['campos'] is! Map) data['campos'] = <String, dynamic>{};
    return (data['campos'] as Map).cast<String, dynamic>();
  }

  dynamic campo(String id) => campos[id];

  void setCampo(String id, dynamic valor) {
    if (valor == null || (valor is String && valor.trim().isEmpty)) {
      campos.remove(id);
    } else {
      campos[id] = valor;
    }
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/ficha.dart test/ficha_test.dart
git commit -m "ficha: tipo npc e valores de campos customizados"
```

---

### Task 2: Definição dos campos customizados

**Files:**
- Create: `lib/models/campo_narrador.dart`
- Create: `lib/store/narrador_store.dart`
- Modify: `lib/main.dart`
- Test: `test/campo_narrador_test.dart` (criar)

**Interfaces:**
- Consumes: `Ficha`, `FichaStore`.
- Produces:
  - `enum TipoCampo { texto, numero, tag, derivado }`
  - `class CampoNarrador { String id, nome; TipoCampo tipo; List<String> opcoes; String origem; }`
    - `CampoNarrador.fromJson(Map)`, `toJson()`
    - `CampoNarrador.origensDerivadas` → `Map<String, String>` (chave → rótulo)
    - `valorDe(Ficha f)` → `Object?` (`num` ou `String`, usado para ordenar)
    - `textoDe(Ficha f)` → `String` (usado para mostrar)
  - `NarradorStore.boxName` → `'narrador'`
  - `NarradorStore.init()` → `Future<void>`
  - `NarradorStore.campos()` → `List<CampoNarrador>`
  - `NarradorStore.salvarCampos(List<CampoNarrador>)` → `Future<void>`
  - `NarradorStore.excluirCampo(String id)` → `Future<void>` (apaga a definição e os valores nas fichas)

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/campo_narrador_test.dart`:

```dart
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
    final c = CampoNarrador(
        id: 'c1', nome: 'Status', tipo: TipoCampo.tag,
        opcoes: ['Vivo', 'Morto']);
    final f = Ficha.criar()..setCampo('c1', 'Morto');
    expect(c.textoDe(f), 'Morto');
    expect(c.valorDe(f), 'Morto');
    expect(c.textoDe(Ficha.criar()), '');
  });

  test('campo derivado lê direto da ficha e não usa o mapa de campos', () {
    final arete = CampoNarrador(
        id: 'c2', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete');
    final f = Ficha.criar();
    f.bonusArete = 2; // arete final = 3
    expect(arete.valorDe(f), 3);
    expect(arete.textoDe(f), '3');

    final afi = CampoNarrador(
        id: 'c3', nome: 'Afiliação', tipo: TipoCampo.derivado,
        origem: 'afiliacao');
    f.data['afiliacao'] = 'Tradições';
    expect(afi.textoDe(f), 'Tradições');
  });

  test('roundtrip de json da definição', () {
    final c = CampoNarrador(
        id: 'c4', nome: 'Sessão', tipo: TipoCampo.numero);
    final volta = CampoNarrador.fromJson(c.toJson());
    expect(volta.id, 'c4');
    expect(volta.nome, 'Sessão');
    expect(volta.tipo, TipoCampo.numero);
  });

  test('store guarda e devolve as definições', () async {
    await NarradorStore.salvarCampos([
      CampoNarrador(id: 'a', nome: 'Status', tipo: TipoCampo.tag, opcoes: ['Vivo']),
      CampoNarrador(id: 'b', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete'),
    ]);
    final campos = NarradorStore.campos();
    expect(campos.map((c) => c.nome), ['Status', 'Arete']);
  });

  test('apagar campo limpa o valor nas fichas', () async {
    await NarradorStore.salvarCampos(
        [CampoNarrador(id: 'a', nome: 'Status', tipo: TipoCampo.texto)]);
    final f = Ficha.criar()..setCampo('a', 'Vivo');
    await FichaStore.salvar(f);

    await NarradorStore.excluirCampo('a');

    expect(NarradorStore.campos(), isEmpty);
    expect(FichaStore.porId(f.id)!.campo('a'), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/campo_narrador_test.dart`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Implementar o model**

Criar `lib/models/campo_narrador.dart`:

```dart
import 'ficha.dart';

/// Tipo de um campo customizado do narrador.
/// `derivado` não é editável: lê direto da ficha, o que permite ordenar e
/// filtrar por característica sem redigitar nada.
enum TipoCampo { texto, numero, tag, derivado }

class CampoNarrador {
  final String id;
  final String nome;
  final TipoCampo tipo;

  /// Opções do tipo `tag`.
  final List<String> opcoes;

  /// Chave da característica lida, quando o tipo é `derivado`.
  final String origem;

  const CampoNarrador({
    required this.id,
    required this.nome,
    required this.tipo,
    this.opcoes = const [],
    this.origem = '',
  });

  /// Características que um campo derivado pode ler: chave → rótulo.
  static const Map<String, String> origensDerivadas = {
    'arete': 'Arete',
    'forcaVontade': 'Força de Vontade',
    'afiliacao': 'Afiliação',
    'faccao': 'Facção',
    'conceito': 'Conceito',
    'essencia': 'Essência',
    'vitalidade': 'Dano de Vitalidade',
    'experiencia': 'Experiência',
  };

  factory CampoNarrador.fromJson(Map<String, dynamic> j) => CampoNarrador(
        id: j['id'] as String,
        nome: (j['nome'] ?? '') as String,
        tipo: TipoCampo.values.firstWhere(
          (t) => t.name == j['tipo'],
          orElse: () => TipoCampo.texto,
        ),
        opcoes: List<String>.from(j['opcoes'] ?? const <String>[]),
        origem: (j['origem'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo.name,
        if (opcoes.isNotEmpty) 'opcoes': opcoes,
        if (origem.isNotEmpty) 'origem': origem,
      };

  /// Valor bruto, para ordenar (num ou String).
  Object? valorDe(Ficha f) {
    if (tipo != TipoCampo.derivado) return f.campo(id);
    switch (origem) {
      case 'arete':
        return f.areteFinal;
      case 'forcaVontade':
        return f.forcaVontadeFinal;
      case 'afiliacao':
        return f.afiliacao;
      case 'faccao':
        return f.faccao;
      case 'conceito':
        return f.conceito;
      case 'essencia':
        return f.essencia;
      case 'vitalidade':
        return f.vitalidadeDano;
      case 'experiencia':
        return f.experiencia;
      default:
        return null;
    }
  }

  /// Valor pronto para mostrar no card.
  String textoDe(Ficha f) {
    final v = valorDe(f);
    return v == null ? '' : '$v';
  }
}
```

- [ ] **Step 4: Implementar o store**

Criar `lib/store/narrador_store.dart`:

```dart
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/campo_narrador.dart';
import 'ficha_store.dart';

/// Configuração do narrador que vale para todas as fichas — hoje, as
/// definições dos campos customizados.
class NarradorStore {
  static const String boxName = 'narrador';
  static const String _chaveCampos = 'campos';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static List<CampoNarrador> campos() {
    final s = _box.get(_chaveCampos);
    if (s == null) return [];
    final lista = jsonDecode(s) as List;
    return [
      for (final e in lista)
        CampoNarrador.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  static Future<void> salvarCampos(List<CampoNarrador> campos) async {
    await _box.put(
        _chaveCampos, jsonEncode([for (final c in campos) c.toJson()]));
  }

  /// Apaga a definição e também os valores guardados nas fichas — deixar
  /// valor órfão só engorda o JSON e reaparece se o id for reaproveitado.
  static Future<void> excluirCampo(String id) async {
    await salvarCampos(campos().where((c) => c.id != id).toList());
    for (final f in FichaStore.todas()) {
      if (f.campos.containsKey(id)) {
        f.setCampo(id, null);
        await FichaStore.salvar(f);
      }
    }
  }
}
```

- [ ] **Step 5: Abrir a box na inicialização**

Em `lib/main.dart`, depois de `await ImagemStore.init();`:

```dart
  await NarradorStore.init();
```

com o import correspondente.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/campo_narrador_test.dart`
Expected: PASS (5 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/models/campo_narrador.dart lib/store/narrador_store.dart lib/main.dart test/campo_narrador_test.dart
git commit -m "narrador: campos customizados com tipo derivado"
```

---

### Task 3: Cadernos de anotação

**Files:**
- Create: `lib/models/nota.dart`
- Create: `lib/store/nota_store.dart`
- Modify: `lib/main.dart`
- Test: `test/nota_store_test.dart` (criar)

**Interfaces:**
- Consumes: `ImagemStore`.
- Produces:
  - `class Nota { String id, titulo, texto; List<String> imagens, tags, fichas; String criadoEm, atualizadoEm; }` com `Nota.criar()`, `Nota.fromJson`, `toJson()`
  - `NotaStore.boxName` → `'notas'`
  - `NotaStore.init()`, `NotaStore.todas()`, `NotaStore.porId(String)`, `NotaStore.salvar(Nota)`, `NotaStore.excluir(String)`
  - `NotaStore.buscar(String termo)` → `List<Nota>` (título, texto e tags, sem diferenciar maiúsculas)
  - `NotaStore.imagensUsadas()` → `Set<String>`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/nota_store_test.dart`:

```dart
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
      ..titulo = 'Sessão 4 — o Nodo'
      ..texto = 'Os personagens acharam o Nodo sob a estação.'
      ..tags.add('sessão');
    await NotaStore.salvar(n);

    expect(NotaStore.todas().length, 1);
    expect(NotaStore.porId(n.id)!.titulo, 'Sessão 4 — o Nodo');

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
    await NotaStore.salvar(velha);
    await NotaStore.salvar(nova);
    expect(NotaStore.todas().first.titulo, 'Nova');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/nota_store_test.dart`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Implementar o model**

Criar `lib/models/nota.dart`:

```dart
import 'package:uuid/uuid.dart';

/// Caderno de anotação do narrador: texto simples, imagens (ids do
/// `ImagemStore`), tags e atalhos para fichas.
class Nota {
  String id;
  String titulo;
  String texto;
  List<String> imagens;
  List<String> tags;
  List<String> fichas;
  String criadoEm;
  String atualizadoEm;

  Nota({
    required this.id,
    this.titulo = '',
    this.texto = '',
    List<String>? imagens,
    List<String>? tags,
    List<String>? fichas,
    String? criadoEm,
    String? atualizadoEm,
  })  : imagens = imagens ?? [],
        tags = tags ?? [],
        fichas = fichas ?? [],
        criadoEm = criadoEm ?? DateTime.now().toIso8601String(),
        atualizadoEm = atualizadoEm ?? DateTime.now().toIso8601String();

  factory Nota.criar() => Nota(id: const Uuid().v4());

  factory Nota.fromJson(Map<String, dynamic> j) => Nota(
        id: j['id'] as String,
        titulo: (j['titulo'] ?? '') as String,
        texto: (j['texto'] ?? '') as String,
        imagens: List<String>.from(j['imagens'] ?? const <String>[]),
        tags: List<String>.from(j['tags'] ?? const <String>[]),
        fichas: List<String>.from(j['fichas'] ?? const <String>[]),
        criadoEm: j['criadoEm'] as String?,
        atualizadoEm: j['atualizadoEm'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'texto': texto,
        'imagens': imagens,
        'tags': tags,
        'fichas': fichas,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
      };
}
```

- [ ] **Step 4: Implementar o store**

Criar `lib/store/nota_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/nota.dart';

/// Cadernos do narrador, um JSON por registro (mesmo desenho do `FichaStore`).
class NotaStore {
  static const String boxName = 'notas';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static List<Nota> todas() {
    final lista = _box.values
        .map((s) => Nota.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) => b.atualizadoEm.compareTo(a.atualizadoEm));
    return lista;
  }

  static Nota? porId(String id) {
    final s = _box.get(id);
    return s == null ? null : Nota.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> salvar(Nota n) async {
    n.atualizadoEm = DateTime.now().toIso8601String();
    await _box.put(n.id, jsonEncode(n.toJson()));
  }

  static Future<void> excluir(String id) async => _box.delete(id);

  /// Busca em título, texto e tags, ignorando maiúsculas.
  static List<Nota> buscar(String termo) {
    final t = termo.trim().toLowerCase();
    if (t.isEmpty) return todas();
    return todas()
        .where((n) =>
            n.titulo.toLowerCase().contains(t) ||
            n.texto.toLowerCase().contains(t) ||
            n.tags.any((tag) => tag.toLowerCase().contains(t)))
        .toList();
  }

  static Set<String> imagensUsadas() =>
      {for (final n in todas()) ...n.imagens};
}
```

**Atenção:** o teste "ordena da mais recente" grava `atualizadoEm` na mão, mas `salvar()` sobrescreve o campo com a hora atual. Ajustar o teste para gravar direto na box, ou — melhor — dar a `salvar` um parâmetro:

```dart
  static Future<void> salvar(Nota n, {bool tocar = true}) async {
    if (tocar) n.atualizadoEm = DateTime.now().toIso8601String();
    await _box.put(n.id, jsonEncode(n.toJson()));
  }
```

e no teste usar `await NotaStore.salvar(velha, tocar: false)` / `salvar(nova, tocar: false)`.

- [ ] **Step 5: Abrir a box e incluir na faxina**

Em `lib/main.dart`, depois de `NarradorStore.init()`:

```dart
  await NotaStore.init();
```

E trocar a faxina para considerar as duas origens:

```dart
  await ImagemStore.limpar(
      {...FichaStore.imagensUsadas(), ...NotaStore.imagensUsadas()});
```

(removendo a chamada a `FichaStore.limparImagensOrfas()`, que passa a ser insuficiente sozinha — apagaria as imagens dos cadernos.)

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/nota_store_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/models/nota.dart lib/store/nota_store.dart lib/main.dart test/nota_store_test.dart
git commit -m "narrador: cadernos de anotacao com busca e imagens"
```

---

### Task 4: Ordenação e filtro da galeria

**Files:**
- Create: `lib/screens/narrador/galeria_ordem.dart`
- Test: `test/galeria_ordem_test.dart` (criar)

**Interfaces:**
- Consumes: `CampoNarrador`, `Ficha`.
- Produces:
  - `enum FiltroTipo { todos, pcs, npcs }`
  - `class GaleriaOrdem { static List<Ficha> aplicar(List<Ficha> fichas, {FiltroTipo tipo, CampoNarrador? ordenarPor, bool crescente, String busca, String? tagFiltro, CampoNarrador? campoTag}) }`

Toda a lógica de lista fica aqui, fora do widget: é o que dá para testar sem montar tela.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/galeria_ordem_test.dart`:

```dart
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

  final arete = CampoNarrador(
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
    final desc = GaleriaOrdem.aplicar(lista, ordenarPor: arete, crescente: false);
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
    final status = CampoNarrador(
        id: 's', nome: 'Status', tipo: TipoCampo.tag, opcoes: ['Vivo', 'Morto']);
    final vivo = _pc('Vivo', 0)..setCampo('s', 'Vivo');
    final morto = _pc('Morto', 0)..setCampo('s', 'Morto');
    final resultado = GaleriaOrdem.aplicar([vivo, morto],
        campoTag: status, tagFiltro: 'Morto');
    expect(resultado.map((f) => f.nome), ['Morto']);
  });

  test('ficha sem valor no campo vai para o fim da ordenação', () {
    final semValor = _pc('Sem', 0);
    final campo = CampoNarrador(id: 'x', nome: 'Sessão', tipo: TipoCampo.numero);
    final comValor = _pc('Com', 0)..setCampo('x', 3);
    final ordenada =
        GaleriaOrdem.aplicar([semValor, comValor], ordenarPor: campo);
    expect(ordenada.map((f) => f.nome), ['Com', 'Sem']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/galeria_ordem_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

Criar `lib/screens/narrador/galeria_ordem.dart`:

```dart
import '../../models/campo_narrador.dart';
import '../../models/ficha.dart';

enum FiltroTipo { todos, pcs, npcs }

/// Regras de lista da galeria, separadas do widget para poderem ser testadas
/// sem montar tela.
class GaleriaOrdem {
  static List<Ficha> aplicar(
    List<Ficha> fichas, {
    FiltroTipo tipo = FiltroTipo.todos,
    CampoNarrador? ordenarPor,
    bool crescente = true,
    String busca = '',
    CampoNarrador? campoTag,
    String? tagFiltro,
  }) {
    final termo = busca.trim().toLowerCase();
    final lista = fichas.where((f) {
      if (tipo == FiltroTipo.pcs && f.ehNpc) return false;
      if (tipo == FiltroTipo.npcs && !f.ehNpc) return false;
      if (termo.isNotEmpty && !f.nome.toLowerCase().contains(termo)) {
        return false;
      }
      if (campoTag != null && tagFiltro != null && tagFiltro.isNotEmpty) {
        if (campoTag.textoDe(f) != tagFiltro) return false;
      }
      return true;
    }).toList();

    lista.sort((a, b) {
      if (ordenarPor == null) {
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
      final va = ordenarPor.valorDe(a);
      final vb = ordenarPor.valorDe(b);
      // quem não tem valor no campo fica sempre no fim, nos dois sentidos
      if (va == null && vb == null) return a.nome.compareTo(b.nome);
      if (va == null) return 1;
      if (vb == null) return -1;
      final c = (va is num && vb is num)
          ? va.compareTo(vb)
          : '$va'.toLowerCase().compareTo('$vb'.toLowerCase());
      return crescente ? c : -c;
    });

    return lista;
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/galeria_ordem_test.dart`
Expected: PASS (6 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/narrador/galeria_ordem.dart test/galeria_ordem_test.dart
git commit -m "narrador: regras de ordenacao e filtro da galeria"
```

---

### Task 5: Home com aba Narrador

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Create: `lib/screens/narrador/narrador_screen.dart`
- Test: `test/home_navegacao_test.dart` (criar)

**Interfaces:**
- Consumes: `NarradorScreen`.
- Produces: `NarradorScreen` — `StatefulWidget` com duas seções internas (Galeria e Cadernos) num `TabBar`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/home_navegacao_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/screens/home_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-home');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
    await NotaStore.init();
  });

  testWidgets('home tem as abas Magos e Narrador', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Magos'), findsOneWidget);
    expect(find.text('Narrador'), findsOneWidget);
    expect(find.text('CRIAR PERSONAGEM'), findsOneWidget);

    await tester.tap(find.text('Narrador'));
    await tester.pumpAndSettle();

    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Cadernos'), findsOneWidget);
    expect(find.text('CRIAR PERSONAGEM'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/home_navegacao_test.dart`
Expected: FAIL — não existe texto "Narrador".

- [ ] **Step 3: Implementar**

Transformar `HomeScreen` em `StatefulWidget` com duas abas. O corpo que existe hoje vira o widget `_AbaMagos` (mesmo conteúdo, sem mudanças de comportamento):

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_aba == 0 ? 'MAGO: A ASCENSÃO' : 'NARRADOR'),
        actions: [ /* menu ⋮ que já existe, sem mudança */ ],
      ),
      body: IndexedStack(
        index: _aba,
        children: const [_AbaMagos(), NarradorScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Magos'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Narrador'),
        ],
      ),
    );
  }
}
```

Criar `lib/screens/narrador/narrador_screen.dart` com o esqueleto das duas seções:

```dart
import 'package:flutter/material.dart';

import 'cadernos_aba.dart';
import 'galeria_aba.dart';

/// Área do narrador: galeria de personagens e cadernos de anotação.
class NarradorScreen extends StatelessWidget {
  const NarradorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Galeria'), Tab(text: 'Cadernos')]),
          Expanded(child: TabBarView(children: [GaleriaAba(), CadernosAba()])),
        ],
      ),
    );
  }
}
```

Criar `lib/screens/narrador/galeria_aba.dart` e `lib/screens/narrador/cadernos_aba.dart` com um placeholder mínimo por enquanto (`const Center(child: Text('Galeria'))` / `'Cadernos'`) — o conteúdo entra nas Tasks 6 e 7. Isso mantém cada task com um deliverable que compila e roda.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/home_navegacao_test.dart && flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart lib/screens/narrador/ test/home_navegacao_test.dart
git commit -m "home: aba do narrador ao lado da lista de magos"
```

---

### Task 6: Galeria de personagens

**Files:**
- Modify: `lib/screens/narrador/galeria_aba.dart`
- Create: `lib/screens/narrador/campos_config_screen.dart`
- Create: `lib/screens/narrador/npc_screen.dart`
- Test: `test/galeria_aba_test.dart` (criar)

**Interfaces:**
- Consumes: `GaleriaOrdem`, `NarradorStore.campos`, `FichaStore`, `RetratoAvatar`, `Ficha.criarNpc`.
- Produces:
  - `GaleriaAba` — grade de cards
  - `CamposConfigScreen` — cria, edita e apaga definições de campo
  - `NpcScreen({Ficha? existente})` — formulário curto de NPC

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/galeria_aba_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/campo_narrador.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/narrador/galeria_aba.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-galeria');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
  });

  testWidgets('mostra PCs e NPCs com o valor do campo escolhido',
      (tester) async {
    await NarradorStore.salvarCampos([
      CampoNarrador(
          id: 'a', nome: 'Arete', tipo: TipoCampo.derivado, origem: 'arete'),
    ]);
    final pc = Ficha.criar();
    pc.data['nome'] = 'Cassandra';
    pc.bonusArete = 2;
    await FichaStore.salvar(pc);
    final npc = Ficha.criarNpc();
    npc.data['nome'] = 'Barqueiro';
    await FichaStore.salvar(npc);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await tester.pumpAndSettle();

    expect(find.text('Cassandra'), findsOneWidget);
    expect(find.text('Barqueiro'), findsOneWidget);
    expect(find.textContaining('Arete'), findsWidgets);
  });

  testWidgets('filtro NPC esconde os PCs', (tester) async {
    final pc = Ficha.criar();
    pc.data['nome'] = 'Cassandra';
    await FichaStore.salvar(pc);
    final npc = Ficha.criarNpc();
    npc.data['nome'] = 'Barqueiro';
    await FichaStore.salvar(npc);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GaleriaAba())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('filtro-npcs')));
    await tester.pumpAndSettle();

    expect(find.text('Barqueiro'), findsOneWidget);
    expect(find.text('Cassandra'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/galeria_aba_test.dart`
Expected: FAIL — a aba ainda é o placeholder com o texto 'Galeria'.

- [ ] **Step 3: Implementar a galeria**

Substituir o conteúdo de `lib/screens/narrador/galeria_aba.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/campo_narrador.dart';
import '../../models/ficha.dart';
import '../../store/ficha_store.dart';
import '../../store/narrador_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../ficha_view_screen.dart';
import 'campos_config_screen.dart';
import 'galeria_ordem.dart';
import 'npc_screen.dart';

/// Galeria de personagens: cards com retrato e os campos que o narrador
/// escolheu mostrar, com filtro por tipo e ordenação por característica.
class GaleriaAba extends StatefulWidget {
  const GaleriaAba({super.key});
  @override
  State<GaleriaAba> createState() => _GaleriaAbaState();
}

class _GaleriaAbaState extends State<GaleriaAba> {
  FiltroTipo _tipo = FiltroTipo.todos;
  CampoNarrador? _ordem;
  bool _crescente = true;
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final campos = NarradorStore.campos();
    return ValueListenableBuilder(
      valueListenable: FichaStore.listenable,
      builder: (context, Box<String> box, _) {
        final lista = GaleriaOrdem.aplicar(
          FichaStore.todas(),
          tipo: _tipo,
          ordenarPor: _ordem,
          crescente: _crescente,
          busca: _busca,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar pelo nome',
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final par in const [
                    (FiltroTipo.todos, 'Todos', 'filtro-todos'),
                    (FiltroTipo.pcs, 'Jogadores', 'filtro-pcs'),
                    (FiltroTipo.npcs, 'NPCs', 'filtro-npcs'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey(par.$3),
                        label: Text(par.$2),
                        selected: _tipo == par.$1,
                        onSelected: (_) => setState(() => _tipo = par.$1),
                      ),
                    ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _ordem?.id ?? '',
                    hint: const Text('Ordenar'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Nome')),
                      for (final c in campos)
                        DropdownMenuItem(value: c.id, child: Text(c.nome)),
                    ],
                    onChanged: (v) => setState(() => _ordem = (v == null || v.isEmpty)
                        ? null
                        : campos.firstWhere((c) => c.id == v)),
                  ),
                  IconButton(
                    tooltip: _crescente ? 'Crescente' : 'Decrescente',
                    icon: Icon(_crescente
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    onPressed: () => setState(() => _crescente = !_crescente),
                  ),
                  IconButton(
                    tooltip: 'Campos customizados',
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CamposConfigScreen()));
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhum personagem por aqui.\n'
                          'Crie um mago na aba Magos ou um NPC no + abaixo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _card(lista[i], campos),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(Ficha f, List<CampoNarrador> campos) {
    // mostra no máximo três campos para o card não virar tabela
    final mostrar = campos.take(3).toList();
    return Card(
      child: InkWell(
        onTap: () async {
          if (f.ehNpc) {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NpcScreen(existente: f)));
          } else {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FichaViewScreen(fichaId: f.id)));
          }
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: RetratoAvatar(retratoId: f.retratoId, tamanho: 76)),
              const SizedBox(height: 8),
              Text(f.nome.isEmpty ? 'Sem nome' : f.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
              if (f.ehNpc)
                const Text('NPC',
                    style: TextStyle(fontSize: 11, color: Cores.indigoClaro)),
              const SizedBox(height: 4),
              for (final c in mostrar)
                if (c.textoDe(f).isNotEmpty)
                  Text('${c.nome}: ${c.textoDe(f)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implementar a tela de campos**

Criar `lib/screens/narrador/campos_config_screen.dart`: lista os campos de `NarradorStore.campos()`, com botão `+` que abre um diálogo pedindo **nome**, **tipo** (`texto`, `numero`, `tag`, `derivado`), **opções** (quando `tag`, uma por linha) e **origem** (quando `derivado`, um dropdown com `CampoNarrador.origensDerivadas`). Salvar chama `NarradorStore.salvarCampos([...atuais, novo])` com `id` de `const Uuid().v4()`. O ícone de lixeira chama `NarradorStore.excluirCampo(c.id)` **depois** de um `AlertDialog` avisando que os valores nas fichas também somem:

```dart
  Future<void> _confirmarExcluir(CampoNarrador c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: Text('Apagar o campo "${c.nome}"?'),
        content: const Text(
            'O valor desse campo será removido de todas as fichas. '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) {
      await NarradorStore.excluirCampo(c.id);
      if (mounted) setState(() {});
    }
  }
```

- [ ] **Step 5: Implementar a tela de NPC**

Criar `lib/screens/narrador/npc_screen.dart`: formulário com retrato (`RetratoAvatar` + `escolherRetrato`), nome, conceito, afiliação, notas (`data['notas']`), os campos customizados editáveis (tipo `texto`, `numero`, `tag`; `derivado` aparece só de leitura) e a lista `outrasCaracteristicas` (nome + valor, que já sai no PDF). Salvar chama `FichaStore.salvar(f)`. No `AppBar`, uma ação "Abrir no criador completo" que empurra `WizardScreen(existente: f)` — por baixo o NPC é uma `Ficha` normal.

Na `GaleriaAba`, acrescentar o `FloatingActionButton` que cria NPC — como a aba não tem `Scaffold` próprio, colocá-lo no `Scaffold` da `HomeScreen` só quando a aba Narrador estiver ativa, ou usar um botão "＋ NPC" no fim da barra de filtros. Escolher o botão na barra de filtros: menos acoplamento entre telas.

```dart
                  IconButton(
                    tooltip: 'Novo NPC',
                    icon: const Icon(Icons.person_add_alt),
                    onPressed: () async {
                      await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NpcScreen()));
                      setState(() {});
                    },
                  ),
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/galeria_aba_test.dart`
Expected: PASS (2 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/screens/narrador/ test/galeria_aba_test.dart
git commit -m "narrador: galeria de personagens, campos customizados e NPC"
```

---

### Task 7: Cadernos na interface

**Files:**
- Modify: `lib/screens/narrador/cadernos_aba.dart`
- Create: `lib/screens/narrador/nota_screen.dart`
- Test: `test/cadernos_aba_test.dart` (criar)

**Interfaces:**
- Consumes: `NotaStore`, `ImagemStore`, `escolherRetrato` (mesmo seletor de imagem).
- Produces:
  - `CadernosAba` — lista com busca
  - `NotaScreen({Nota? existente})` — editor

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/cadernos_aba_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/models/nota.dart';
import 'package:mago_a_ascensao/screens/narrador/cadernos_aba.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/nota_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-cadernos');
    await NotaStore.init();
    await ImagemStore.init();
  });

  tearDown(() async => Hive.box<String>(NotaStore.boxName).clear());

  testWidgets('lista as notas e filtra pela busca', (tester) async {
    await NotaStore.salvar(Nota.criar()..titulo = 'Sessão 4 — o Nodo');
    await NotaStore.salvar(Nota.criar()..titulo = 'Lista de NPCs');

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CadernosAba())));
    await tester.pumpAndSettle();

    expect(find.text('Sessão 4 — o Nodo'), findsOneWidget);
    expect(find.text('Lista de NPCs'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nodo');
    await tester.pumpAndSettle();

    expect(find.text('Sessão 4 — o Nodo'), findsOneWidget);
    expect(find.text('Lista de NPCs'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/cadernos_aba_test.dart`
Expected: FAIL — a aba ainda é o placeholder.

- [ ] **Step 3: Implementar**

`lib/screens/narrador/cadernos_aba.dart`: `ValueListenableBuilder` sobre `NotaStore.listenable`, campo de busca no topo (chama `NotaStore.buscar`), `ListView` de `Card` com título, primeira linha do texto, tags como `Chip` e a data de atualização. Toque abre `NotaScreen(existente: n)`; `IconButton` de `+` no topo abre `NotaScreen()` vazia; deslizar ou menu ⋮ apaga com confirmação (`AlertDialog`, mesmo padrão de `_confirmarExcluir` da home).

`lib/screens/narrador/nota_screen.dart`: `TextField` do título, `TextField` multilinha do texto (`maxLines: null`, `expands` dentro de um `Expanded`), linha de tags (chips com `onDeleted` + campo para adicionar), grade das imagens (`Image.memory(ImagemStore.bytes(id)!)` com `onLongPress` para remover) e botão "Adicionar imagem" que reaproveita `escolherRetrato(context)` — a função devolve o id salvo no `ImagemStore`, que é exatamente o que a nota guarda:

```dart
                onPressed: () async {
                  final id = await escolherRetrato(context);
                  if (id == null) return;
                  setState(() => nota.imagens.add(id));
                },
```

Salvar chama `NotaStore.salvar(nota)` no `pop` (mesmo comportamento de "salva ao sair" do resto do app).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/cadernos_aba_test.dart`
Expected: PASS

- [ ] **Step 5: Conferir no app**

Run: `flutter run -d chrome`; criar caderno com imagem, sair, voltar — a imagem continua lá; reiniciar o app e conferir que a faxina de órfãs não apagou a imagem do caderno.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/narrador/ test/cadernos_aba_test.dart
git commit -m "narrador: cadernos com busca, tags e imagens"
```

---

### Task 8: Narrador no backup

**Files:**
- Modify: `lib/services/backup_io.dart`
- Modify: `lib/store/imagem_store.dart` (gravar preservando o id)
- Test: `test/backup_io_test.dart`

**Interfaces:**
- Consumes: `NotaStore`, `NarradorStore`, `ImagemStore`.
- Produces:
  - `ImagemStore.gravar(String id, Uint8List bytes)` → `Future<void>` (preserva o id, usado só no import de backup)
  - `ResumoBackup` ganha `List<Map<String, dynamic>> notas` e `List<Map<String, dynamic>> camposNarrador`
  - `BackupIO.montarZip` passa a incluir `narrador/campos.json`, `narrador/notas.json` e `narrador/imagens/<id>.jpg`

- [ ] **Step 1: Escrever o teste que falha**

Em `test/backup_io_test.dart`:

```dart
  test('backup leva e traz de volta cadernos, campos e imagens', () async {
    await NarradorStore.salvarCampos([
      CampoNarrador(id: 'a', nome: 'Status', tipo: TipoCampo.tag, opcoes: ['Vivo']),
    ]);
    final imgId = await ImagemStore.salvar(_png());
    await NotaStore.salvar(Nota.criar()
      ..titulo = 'Sessão 1'
      ..texto = 'Começou'
      ..imagens.add(imgId));

    final bytes = BackupIO.montarZip(FichaStore.todas());

    await Hive.box<String>(NotaStore.boxName).clear();
    await Hive.box<String>(NarradorStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar);

    expect(NarradorStore.campos().map((c) => c.nome), ['Status']);
    final notas = NotaStore.todas();
    expect(notas.length, 1);
    expect(notas.first.titulo, 'Sessão 1');
    expect(ImagemStore.bytes(notas.first.imagens.first), isNotNull);
  });
```

Acrescentar os imports de `Nota`, `NotaStore`, `CampoNarrador`, `NarradorStore` e o helper `_png()` (igual ao de `test/imagem_store_test.dart`), e abrir as boxes `notas` e `narrador` no `setUpAll`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/backup_io_test.dart`
Expected: FAIL — os cadernos e campos não voltam.

- [ ] **Step 3: Implementar**

Em `lib/store/imagem_store.dart`:

```dart
  /// Grava preservando o id — usado só no import de backup, onde as notas
  /// já referenciam a imagem por esse id.
  static Future<void> gravar(String id, Uint8List bytes) async =>
      _box.put(id, base64Encode(reduzir(bytes)));
```

Em `montarZip`, depois das fichas:

```dart
    final campos = NarradorStore.campos();
    if (campos.isNotEmpty) {
      add('narrador/campos.json',
          json.convert([for (final c in campos) c.toJson()]));
    }

    final notas = NotaStore.todas();
    if (notas.isNotEmpty) {
      add('narrador/notas.json',
          json.convert([for (final n in notas) n.toJson()]));
      for (final id in NotaStore.imagensUsadas()) {
        final bytes = ImagemStore.bytes(id);
        if (bytes != null) {
          arquivo.addFile(
              ArchiveFile('narrador/imagens/$id.jpg', bytes.length, bytes));
        }
      }
    }
```

e o manifesto ganha as contagens:

```dart
      json.convert({
        'versao': versao,
        'app': app,
        'fichas': fichas.length,
        'notas': notas.length,
        'campos': campos.length,
      }),
```

Em `lerZip`, além das fichas:

```dart
    List<Map<String, dynamic>> listaDe(String caminho) {
      final arq = zip.files.where((f) => f.name == caminho).toList();
      if (arq.isEmpty) return [];
      final j = jsonDecode(utf8.decode(arq.first.content as List<int>));
      return [
        for (final e in (j as List)) (e as Map).cast<String, dynamic>(),
      ];
    }

    final notas = listaDe('narrador/notas.json');
    final campos = listaDe('narrador/campos.json');
    final imagens = <String, Uint8List>{
      for (final f in zip.files)
        if (f.name.startsWith('narrador/imagens/') && f.name.endsWith('.jpg'))
          f.name.substring('narrador/imagens/'.length).replaceAll('.jpg', ''):
              Uint8List.fromList(f.content as List<int>),
    };
```

`ResumoBackup` ganha os três campos (`notas`, `camposNarrador`, `imagens`) e `aplicar` grava depois das fichas:

```dart
    for (final entrada in r.imagens.entries) {
      await ImagemStore.gravar(entrada.key, entrada.value);
    }
    for (final j in r.notas) {
      final n = Nota.fromJson(j);
      if (NotaStore.porId(n.id) == null || politica != PoliticaColisao.pular) {
        await NotaStore.salvar(n, tocar: false);
      }
    }
    if (r.camposNarrador.isNotEmpty) {
      // definições de campo são configuração global: o backup substitui
      await NarradorStore.salvarCampos(
          [for (final j in r.camposNarrador) CampoNarrador.fromJson(j)]);
    }
```

O diálogo de confirmação na home passa a mostrar também `${r.notas.length} caderno(s)`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/backup_io_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/backup_io.dart lib/store/imagem_store.dart lib/screens/home_screen.dart test/backup_io_test.dart
git commit -m "backup: cadernos, campos e imagens do narrador no zip"
```

---

### Task 9: Fechamento da fase

- [ ] **Step 1: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Analisar**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Passeio completo no app**

Run: `flutter run -d chrome`
1. Criar campo `Status` (tag: Vivo/Morto) e campo derivado `Arete`.
2. Criar um NPC com retrato e marcar `Status: Morto`.
3. Na galeria, ordenar por Arete e filtrar só NPCs.
4. Criar um caderno com imagem e tag.
5. Exportar tudo, limpar os dados do navegador, importar o zip: fichas, NPC, campos, cadernos e imagens voltam.

- [ ] **Step 4: Atualizar o README**

Acrescentar a área do narrador e o backup em massa na descrição das funcionalidades, com uma imagem nova em `docs/img/`.

- [ ] **Step 5: Commit final**

```bash
git add -A
git commit -m "fase 5: area do narrador concluida"
```
