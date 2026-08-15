# Mesa online · Fase 4 — Mesa permanente e galeria da crônica — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar task a task. Steps usam checkbox (`- [ ]`).

**Goal:** A mesa dura enquanto o mestre quiser, e tudo que ele mostrou continua lá — o mapa da primeira sessão ainda está na quinta.

**Architecture:** O mural de uma imagem só vira uma galeria: cada imagem são dois documentos (um leve com miniatura, um pesado com a imagem), e `mural/atual` passa a ser um ponteiro para o id da imagem em destaque. `fecharMesa` se divide em `encerrarSessao` (mesa continua) e `apagarMesa` (destrutivo). O aparelho guarda as mesas conhecidas para voltar sem código, e uma chave de recuperação devolve a mesa ao mestre que perdeu o uid anônimo.

**Tech Stack:** Flutter 3.44, `cloud_firestore`, `image`, Hive, `flutter_test`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`, branch `mesa-online`.
- Flutter roda por Docker: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter <cmd>"`.
- Depende das Fases 1, 2 e 3 concluídas.
- Código, comentários e textos de UI em português do Brasil.
- **Só o mestre escreve na galeria.** Jogador só lê.
- Nenhum documento do Firestore pode passar de 1 MiB — teto de 700 KB em base64 para a imagem cheia, 40 KB para a miniatura.
- Gravação no Hive nunca dentro de `testWidgets` — a escrita fica pendente e trava o teste seguinte. Se um teste precisar gravar, ele fica sozinho no arquivo ou a gravação vai para o `setUp`.
- **Antes de gerar APK, `flutter clean`**: o Gradle já entregou APK novo com `libapp.so` velho. Conferir com `unzip -p ... libapp.so | strings -a | grep -c '<texto novo>'`.
- `flutter analyze` limpo antes de cada commit. Não rodar `dart format`.
- Commits em português, sem menção a IA/Claude/Anthropic.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `lib/mesa/imagem_mural.dart` (modificar) | Gera imagem cheia **e** miniatura |
| `lib/mesa/chave_mesa.dart` (criar) | Gera e normaliza a chave de recuperação |
| `lib/mesa/mesa_service.dart` (modificar) | `ItemGaleria`, novos métodos da interface |
| `lib/mesa/mesa_fake.dart` (modificar) | Galeria, mural por ponteiro, chave, encerrar/apagar |
| `lib/mesa/mesa_firestore.dart` (modificar) | Mesmos métodos contra o Firestore |
| `lib/mesa/mesa_store.dart` (modificar) | Mesas conhecidas + chave local |
| `lib/mesa/telas/galeria_mesa.dart` (criar) | Grade de miniaturas, abrir, mostrar agora, apagar |
| `lib/mesa/telas/mural_da_mesa.dart` (modificar) | Passa a enviar para a galeria com escolha |
| `lib/mesa/telas/mesa_aba.dart` (modificar) | Mesas conhecidas, encerrar/apagar, recuperar |
| `lib/mesa/ouvinte_mural.dart` (modificar) | Segue ponteiro e busca a imagem cheia |
| `firestore.rules` (modificar) | galeria, imagens, privado, update com chave |

---

### Task 1: Miniatura junto da imagem cheia

**Files:**
- Modify: `lib/mesa/imagem_mural.dart`
- Test: `test/mesa/imagem_mural_test.dart`

**Interfaces:**
- Consumes: pacote `image`.
- Produces:
  - `ImagemMural.tetoMiniatura` → `int` (40 * 1024)
  - `ImagemMural.miniatura(Uint8List original)` → `String` (base64 JPEG ~200px)
  - `ImagemMural.preparar` continua existindo, sem mudança de assinatura.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar em `test/mesa/imagem_mural_test.dart`:

```dart
  test('miniatura é pequena o suficiente para a galeria inteira', () {
    final b64 = ImagemMural.miniatura(_ruido(1600, 1200));
    expect(b64.length, lessThan(ImagemMural.tetoMiniatura));
    final im = img.decodeImage(base64Decode(b64))!;
    expect(im.width, lessThanOrEqualTo(200));
  });

  test('miniatura de imagem pequena não é ampliada', () {
    final b64 = ImagemMural.miniatura(_ruido(120, 90));
    final im = img.decodeImage(base64Decode(b64))!;
    expect(im.width, 120);
  });

  test('cinquenta miniaturas cabem numa abertura de galeria barata', () {
    final b64 = ImagemMural.miniatura(_ruido(1600, 1200));
    expect(b64.length * 50, lessThan(2 * 1024 * 1024));
  });

  test('miniatura de bytes inválidos falha com mensagem clara', () {
    expect(() => ImagemMural.miniatura(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()));
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/imagem_mural_test.dart"`
Expected: FAIL — `miniatura` não definido.

- [ ] **Step 3: Implementar**

Em `lib/mesa/imagem_mural.dart`, acrescentar à classe `ImagemMural`:

```dart
  /// Teto da miniatura. A galeria lê uma por imagem: com 50 imagens são ~2 MB
  /// no pior caso, contra 15 MB se ela lesse as imagens cheias.
  static const int tetoMiniatura = 40 * 1024;

  static const int _ladoMiniatura = 200;

  /// Versão pequena, para a grade da galeria. A imagem cheia só é buscada
  /// quando alguém abre.
  static String miniatura(Uint8List original) {
    final imagem = _decodificar(original);
    final pequena = imagem.width > _ladoMiniatura
        ? img.copyResize(imagem,
            width: _ladoMiniatura, interpolation: img.Interpolation.average)
        : imagem;
    for (final q in [60, 45, 30]) {
      final b64 = base64Encode(img.encodeJpg(pequena, quality: q));
      if (b64.length <= tetoMiniatura) return b64;
    }
    return base64Encode(img.encodeJpg(
        img.copyResize(imagem, width: 120), quality: 40));
  }
```

e extrair o decode que hoje está dentro de `preparar` para um helper usado
pelos dois:

```dart
  /// `decodeImage` não devolve só null em arquivo inválido: com poucos bytes
  /// ele estoura dentro de um dos decodificadores que tenta (o de PSD lê o
  /// cabeçalho antes de conferir o tamanho).
  static img.Image _decodificar(Uint8List original) {
    img.Image? imagem;
    try {
      imagem = img.decodeImage(original);
    } catch (_) {
      imagem = null;
    }
    if (imagem == null) {
      throw Exception('Não foi possível ler a imagem.');
    }
    return imagem;
  }
```

Trocar o início de `preparar` para `final imagem = _decodificar(original);`.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/imagem_mural_test.dart"`
Expected: PASS (8 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/imagem_mural.dart test/mesa/imagem_mural_test.dart
git commit -m "mesa: miniatura para a grade da galeria"
```

---

### Task 2: Chave de recuperação

**Files:**
- Create: `lib/mesa/chave_mesa.dart`
- Create: `test/mesa/chave_mesa_test.dart`

**Interfaces:**
- Consumes: `CodigoMesa.alfabeto` de `lib/mesa/codigo.dart`.
- Produces:
  - `ChaveMesa.gerar()` → `String` no formato `MAGO-XXXX-XXXX`
  - `ChaveMesa.normalizar(String)` → `String` (maiúsculas, sem espaço, com prefixo e hífens)
  - `ChaveMesa.valida(String)` → `bool`

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/chave_mesa_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/chave_mesa.dart';

void main() {
  test('gera no formato MAGO-XXXX-XXXX', () {
    final c = ChaveMesa.gerar();
    expect(ChaveMesa.valida(c), isTrue);
    expect(c, startsWith('MAGO-'));
    expect(c.length, 'MAGO-XXXX-XXXX'.length);
  });

  test('duas chaves seguidas não são iguais', () {
    expect(ChaveMesa.gerar(), isNot(ChaveMesa.gerar()));
  });

  test('normalizar aceita o que a pessoa digita', () {
    expect(ChaveMesa.normalizar(' mago-k7qw-3xzp '), 'MAGO-K7QW-3XZP');
    expect(ChaveMesa.normalizar('k7qw3xzp'), 'MAGO-K7QW-3XZP');
    expect(ChaveMesa.normalizar('K7QW-3XZP'), 'MAGO-K7QW-3XZP');
  });

  test('chave curta ou com letra fora do alfabeto é inválida', () {
    expect(ChaveMesa.valida('MAGO-K7QW-3XZ'), isFalse);
    expect(ChaveMesa.valida('MAGO-K7QW-3XZI'), isFalse); // I não está no alfabeto
    expect(ChaveMesa.valida(''), isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/chave_mesa_test.dart"`
Expected: FAIL — `chave_mesa.dart` não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/chave_mesa.dart`:

```dart
import 'dart:math';

import 'codigo.dart';

/// A senha da mesa: quem tem a chave é o mestre.
///
/// O login é anônimo, e o uid vive no aparelho — limpar os dados do app o
/// destrói. Sem esta chave a crônica ficaria sem dono, com a galeria inteira
/// presa numa mesa que ninguém mais comanda.
///
/// Mesmo alfabeto do código da mesa: sem I, L, O, S e 0, 1, 5, que a pessoa
/// erra ao ler em voz alta ou copiar de um papel.
class ChaveMesa {
  static const String prefixo = 'MAGO-';
  static const int _porBloco = 4;

  static final Random _sorte = Random.secure();

  static String gerar() {
    String bloco() => List.generate(
        _porBloco,
        (_) => CodigoMesa
            .alfabeto[_sorte.nextInt(CodigoMesa.alfabeto.length)]).join();
    return '$prefixo${bloco()}-${bloco()}';
  }

  /// Aceita com ou sem prefixo, com ou sem hífen, em qualquer caixa.
  static String normalizar(String bruta) {
    final limpa = bruta
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceFirst(RegExp('^MAGO'), '');
    if (limpa.length != _porBloco * 2) return bruta.trim().toUpperCase();
    return '$prefixo${limpa.substring(0, _porBloco)}-'
        '${limpa.substring(_porBloco)}';
  }

  static bool valida(String chave) {
    final c = normalizar(chave);
    if (c.length != prefixo.length + _porBloco * 2 + 1) return false;
    if (!c.startsWith(prefixo)) return false;
    final corpo = c.substring(prefixo.length).replaceAll('-', '');
    return corpo.length == _porBloco * 2 &&
        corpo.split('').every(CodigoMesa.alfabeto.contains);
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/chave_mesa_test.dart"`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/chave_mesa.dart test/mesa/chave_mesa_test.dart
git commit -m "mesa: chave de recuperacao da mesa"
```

---

### Task 3: Galeria no serviço

**Files:**
- Modify: `lib/mesa/mesa_service.dart`
- Modify: `lib/mesa/mesa_fake.dart`
- Modify: `lib/mesa/mesa_firestore.dart`
- Test: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Consumes: `SemPermissao`, `MundoFake`.
- Produces, em `MesaService`:
  - `class ItemGaleria { String id, legenda, porUid, miniaturaBase64; DateTime em; }`
  - `Future<String> guardarNaGaleria(String mesaId, String imagemBase64, String miniaturaBase64, String legenda)` — devolve o `imagemId`
  - `Future<void> apagarDaGaleria(String mesaId, String imagemId)`
  - `Stream<List<ItemGaleria>> observarGaleria(String mesaId)` — mais recente primeiro
  - `Future<String?> imagemCheia(String mesaId, String imagemId)` — null se não existe
  - `Future<void> mostrarAgora(String mesaId, String imagemId)`
- `ItemMural` passa a ter `imagemId` no lugar de `imagemBase64`.

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar em `test/mesa/mesa_fake_test.dart` (o arquivo já tem os helpers
`mesaPronta()` e `jogadorNa()`):

```dart
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
```

Os testes de mural que hoje usam `mostrarNoMural(mesa.id, 'AAAA', 'legenda')` e
`visto.imagemBase64` mudam para o par `guardarNaGaleria` + `mostrarAgora` e para
`visto.imagemId`, como nos exemplos acima.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — `guardarNaGaleria` não definido.

- [ ] **Step 3: Interface e modelo**

Em `lib/mesa/mesa_service.dart`, acrescentar:

```dart
/// Uma imagem na galeria da mesa, do jeito leve: sem a imagem cheia.
class ItemGaleria {
  final String id;
  final String legenda;
  final String porUid;
  final String miniaturaBase64;
  final DateTime em;

  const ItemGaleria({
    required this.id,
    required this.legenda,
    required this.porUid,
    required this.miniaturaBase64,
    required this.em,
  });

  factory ItemGaleria.fromJson(String id, Map<String, dynamic> j) => ItemGaleria(
        id: id,
        legenda: (j['legenda'] ?? '') as String,
        porUid: (j['porUid'] ?? '') as String,
        miniaturaBase64: (j['miniatura'] ?? '') as String,
        em: DateTime.parse(j['em'] as String),
      );

  Map<String, dynamic> toJson() => {
        'legenda': legenda,
        'porUid': porUid,
        'miniatura': miniaturaBase64,
        'em': em.toIso8601String(),
      };
}
```

Trocar `ItemMural` para apontar em vez de carregar:

```dart
/// O que está em destaque no mural agora. Aponta para uma imagem da galeria —
/// carregar a imagem aqui faria todo aparelho baixá-la de novo a cada mudança.
class ItemMural {
  final String imagemId;
  final DateTime em;

  const ItemMural({required this.imagemId, required this.em});

  factory ItemMural.fromJson(Map<String, dynamic> j) => ItemMural(
        imagemId: (j['imagemId'] ?? '') as String,
        em: DateTime.parse(j['em'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'imagemId': imagemId, 'em': em.toIso8601String()};
}
```

Na interface `MesaService`, trocar `mostrarNoMural` por:

```dart
  /// Só o mestre. Guarda a imagem na galeria e devolve o id dela.
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda);

  /// Só o mestre. Tira a imagem da galeria, junto com a imagem cheia.
  Future<void> apagarDaGaleria(String mesaId, String imagemId);

  /// Mais recente primeiro. Só miniaturas.
  Stream<List<ItemGaleria>> observarGaleria(String mesaId);

  /// A imagem cheia, buscada só quando alguém abre. Null se não existe.
  Future<String?> imagemCheia(String mesaId, String imagemId);

  /// Só o mestre. Põe a imagem em destaque: abre na tela de todos.
  Future<void> mostrarAgora(String mesaId, String imagemId);
```

`limparMural` e `observarMural` continuam como estão.

- [ ] **Step 4: Implementar no fake**

Em `MundoFake`, trocar `mural` e acrescentar a galeria:

```dart
  final Map<String, Map<String, ItemGaleria>> galeria = {};
  final Map<String, Map<String, String>> cheias = {};
  final Map<String, ItemMural> mural = {};

  final Map<String, StreamController<int>> _galeriaCtrl = {};
```

`notificar` emite também `_galeriaCtrl[mesaId]?.add(++_versao);`, e existe um
`streamGaleria(String id)` igual ao `streamFichas`.

Em `MesaFake`:

```dart
  @override
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    final id = 'img-${mundo.galeria[mesaId]?.length ?? 0}-${relogio()
        .microsecondsSinceEpoch}';
    (mundo.cheias[mesaId] ??= {})[id] = imagemBase64;
    (mundo.galeria[mesaId] ??= {})[id] = ItemGaleria(
      id: id,
      legenda: legenda,
      porUid: _uid!,
      miniaturaBase64: miniaturaBase64,
      em: relogio(),
    );
    mundo.notificar(mesaId);
    return id;
  }

  @override
  Future<void> apagarDaGaleria(String mesaId, String imagemId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.cheias[mesaId]?.remove(imagemId);
    mundo.galeria[mesaId]?.remove(imagemId);
    // a imagem em destaque acabou de sumir: o mural não pode apontar para ela
    if (mundo.mural[mesaId]?.imagemId == imagemId) {
      mundo.mural.remove(mesaId);
    }
    mundo.notificar(mesaId);
  }

  @override
  Stream<List<ItemGaleria>> observarGaleria(String mesaId) =>
      mundo.streamGaleria(mesaId).map((_) {
        final itens = mundo.galeria[mesaId]?.values.toList() ??
            const <ItemGaleria>[];
        final ordenados = [...itens]..sort((a, b) => b.em.compareTo(a.em));
        return ordenados;
      });

  @override
  Future<String?> imagemCheia(String mesaId, String imagemId) async =>
      mundo.cheias[mesaId]?[imagemId];

  @override
  Future<void> mostrarAgora(String mesaId, String imagemId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mural[mesaId] = ItemMural(imagemId: imagemId, em: relogio());
    mundo.notificar(mesaId);
  }
```

`fecharMesa` do fake também limpa `galeria` e `cheias`.

- [ ] **Step 5: Implementar no Firestore**

Em `lib/mesa/mesa_firestore.dart`:

```dart
  CollectionReference<Map<String, dynamic>> _galeria(String mesaId) =>
      _mesa(mesaId).collection('galeria');

  CollectionReference<Map<String, dynamic>> _imagens(String mesaId) =>
      _mesa(mesaId).collection('imagens');

  @override
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda) async {
    final meuUid = uid;
    if (meuUid == null) throw SemPermissao();
    final ref = _galeria(mesaId).doc();
    try {
      // a imagem cheia primeiro: a entrada da galeria só aparece quando há o
      // que abrir, e não fica item pela metade se a rede cair no meio
      await _imagens(mesaId).doc(ref.id).set({'imagem': imagemBase64});
      await ref.set(ItemGaleria(
        id: ref.id,
        legenda: legenda,
        porUid: meuUid,
        miniaturaBase64: miniaturaBase64,
        em: DateTime.now(),
      ).toJson());
      return ref.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> apagarDaGaleria(String mesaId, String imagemId) async {
    try {
      // pesado primeiro: se o segundo delete falhar, o item continua na
      // galeria e ninguém fica com imagem grande órfã ocupando espaço
      await _imagens(mesaId).doc(imagemId).delete();
      await _galeria(mesaId).doc(imagemId).delete();
      final atual = await _mural(mesaId).get();
      if (atual.exists && atual.data()!['imagemId'] == imagemId) {
        await _mural(mesaId).delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Stream<List<ItemGaleria>> observarGaleria(String mesaId) => _galeria(mesaId)
      .orderBy('em', descending: true)
      .snapshots()
      .map((q) =>
          q.docs.map((d) => ItemGaleria.fromJson(d.id, d.data())).toList());

  @override
  Future<String?> imagemCheia(String mesaId, String imagemId) async {
    final doc = await _imagens(mesaId).doc(imagemId).get();
    if (!doc.exists) return null;
    return doc.data()!['imagem'] as String?;
  }

  @override
  Future<void> mostrarAgora(String mesaId, String imagemId) async {
    try {
      await _mural(mesaId).set(
          ItemMural(imagemId: imagemId, em: DateTime.now()).toJson());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }
```

Apagar o `mostrarNoMural` antigo. Em `fecharMesa`, apagar também os documentos
de `galeria` e `imagens`, no mesmo laço dos outros.

- [ ] **Step 6: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (29 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/mesa/ test/mesa/mesa_fake_test.dart
git commit -m "mesa: galeria que acumula, com miniatura separada da imagem cheia"
```

---

### Task 4: Encerrar sessão separado de apagar mesa

**Files:**
- Modify: `lib/mesa/mesa_service.dart`
- Modify: `lib/mesa/mesa_fake.dart`
- Modify: `lib/mesa/mesa_firestore.dart`
- Test: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Produces, em `MesaService` (substituindo `fecharMesa`):
  - `Future<void> encerrarSessao(String mesaId)` — tira todos os membros e as fichas publicadas; mesa, código, chave e galeria continuam
  - `Future<void> apagarMesa(String mesaId)` — apaga a mesa inteira

- [ ] **Step 1: Escrever os testes que falham**

```dart
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

  test('apagar mesa leva tudo junto', () async {
    final (mestre, mesa) = await mesaPronta();
    await mestre.guardarNaGaleria(mesa.id, 'CHEIA', 'MINI', 'mapa');

    await mestre.apagarMesa(mesa.id);

    expect(await mestre.observarMesa(mesa.id).first, isNull);
    expect(mestre.mundo.galeria[mesa.id], isNull);
  });

  test('só o mestre encerra e só o mestre apaga', () async {
    final (mestre, mesa) = await mesaPronta();
    final kaue = await jogadorNa(mestre, mesa);

    expect(() => kaue.encerrarSessao(mesa.id), throwsA(isA<SemPermissao>()));
    expect(() => kaue.apagarMesa(mesa.id), throwsA(isA<SemPermissao>()));
  });
```

Os testes existentes que chamam `fecharMesa` passam a chamar `apagarMesa`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — `encerrarSessao` não definido.

- [ ] **Step 3: Implementar no fake**

```dart
  @override
  Future<void> encerrarSessao(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.membros.remove(mesaId);
    mundo.fichas.remove(mesaId);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> apagarMesa(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mesas.remove(mesaId);
    mundo.membros.remove(mesaId);
    mundo.fichas.remove(mesaId);
    mundo.galeria.remove(mesaId);
    mundo.cheias.remove(mesaId);
    mundo.mural.remove(mesaId);
    mundo.chaves.remove(mesaId);
    mundo.notificar(mesaId);
  }
```

Apagar `fecharMesa` do fake. `_exigeMestre` usa `mundo.mesas[mesaId].mestreUid`,
que continua existindo depois de `encerrarSessao` — é por isso que o mestre
consegue encerrar e ainda mandar na mesa depois.

- [ ] **Step 4: Implementar no Firestore**

```dart
  @override
  Future<void> encerrarSessao(String mesaId) async {
    try {
      final fichas = await _mesa(mesaId).collection('fichas').get();
      for (final f in fichas.docs) {
        await f.reference.delete();
      }
      final membros = await _mesa(mesaId).collection('membros').get();
      for (final m in membros.docs) {
        await m.reference.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> apagarMesa(String mesaId) async {
    final doc = await _mesa(mesaId).get();
    if (!doc.exists) return;
    final codigo = doc.data()!['codigo'] as String;
    try {
      for (final c in ['galeria', 'imagens', 'fichas', 'membros', 'privado']) {
        final docs = await _mesa(mesaId).collection(c).get();
        for (final d in docs.docs) {
          await d.reference.delete();
        }
      }
      await _mural(mesaId).delete();
      await _db.collection('codigos').doc(codigo).delete();
      await _mesa(mesaId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }
```

Apagar o `fecharMesa` antigo.

- [ ] **Step 5: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (33 testes)

- [ ] **Step 6: Commit**

```bash
git add lib/mesa/ test/mesa/mesa_fake_test.dart
git commit -m "mesa: encerrar sessao sem apagar a mesa"
```

---

### Task 5: Chave no serviço e recuperação da mesa

**Files:**
- Modify: `lib/mesa/mesa_service.dart`
- Modify: `lib/mesa/mesa_fake.dart`
- Modify: `lib/mesa/mesa_firestore.dart`
- Test: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Consumes: `ChaveMesa.gerar()`, `ChaveMesa.normalizar(String)`.
- Produces:
  - `criarMesa` passa a devolver `(Mesa, String chave)` — o segundo é a chave de recuperação, mostrada uma vez
  - `Future<Mesa> reassumirMesa(String codigo, String chave, String meuNome)` — lança `ChaveErrada` se não bater
  - `class ChaveErrada implements Exception` com `toString()` = `'Chave não confere.'`

- [ ] **Step 1: Escrever os testes que falham**

```dart
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
```

Todos os testes que fazem `final mesa = await mestre.criarMesa(...)` passam a
fazer `final (mesa, _) = await mestre.criarMesa(...)`, inclusive dentro do
helper `mesaPronta()`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — `reassumirMesa` não definido.

- [ ] **Step 3: Interface**

Em `lib/mesa/mesa_service.dart`:

```dart
/// A chave de recuperação informada não é a da mesa.
class ChaveErrada implements Exception {
  @override
  String toString() => 'Chave não confere.';
}
```

e na interface:

```dart
  /// Cria a mesa e devolve, junto, a chave de recuperação. A chave é mostrada
  /// uma vez: quem a tem manda na mesa.
  Future<(Mesa, String)> criarMesa(String nome, String meuNome);

  /// Volta a ser o mestre de uma mesa provando a chave. Lança [ChaveErrada]
  /// se não bater, [MesaNaoEncontrada] se o código não existir.
  Future<Mesa> reassumirMesa(String codigo, String chave, String meuNome);
```

- [ ] **Step 4: Implementar no fake**

Em `MundoFake`: `final Map<String, String> chaves = {};`

Em `MesaFake`, `criarMesa` gera e guarda a chave:

```dart
    final chave = ChaveMesa.gerar();
    mundo.chaves[id] = chave;
    ...
    return (mesa, chave);
```

e:

```dart
  @override
  Future<Mesa> reassumirMesa(
      String codigo, String chave, String meuNome) async {
    _exigeLogin();
    final alvo = CodigoMesa.normalizar(codigo);
    Mesa? mesa;
    for (final m in mundo.mesas.values) {
      if (m.codigo == alvo) mesa = m;
    }
    if (mesa == null) throw MesaNaoEncontrada();
    if (mundo.chaves[mesa.id] != ChaveMesa.normalizar(chave)) {
      throw ChaveErrada();
    }

    final nova = Mesa(
      id: mesa.id,
      nome: mesa.nome,
      codigo: mesa.codigo,
      mestreUid: _uid!,
      criadaEm: mesa.criadaEm,
    );
    mundo.mesas[mesa.id] = nova;
    (mundo.membros[mesa.id] ??= {})[_uid!] = Membro(
      uid: _uid!,
      nome: meuNome,
      papel: PapelMesa.mestre,
      entrouEm: relogio(),
      visto: relogio(),
    );
    mundo.notificar(mesa.id);
    return nova;
  }
```

- [ ] **Step 5: Implementar no Firestore**

Em `criarMesa`, depois de criar a mesa e antes de devolver:

```dart
    final chave = ChaveMesa.gerar();
    // documento que ninguém lê: só as regras enxergam, com get()
    await ref.collection('privado').doc('chave').set({'chave': chave});
```

e devolver `(mesa, chave)`.

```dart
  @override
  Future<Mesa> reassumirMesa(
      String codigo, String chave, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final alvo = CodigoMesa.normalizar(codigo);
    final atalho = await _db.collection('codigos').doc(alvo).get();
    if (!atalho.exists) throw MesaNaoEncontrada();
    final mesaId = atalho.data()!['mesaId'] as String;

    try {
      // a tentativa vai num documento ilegível; a regra do update compara os
      // dois com get() e só deixa passar se baterem
      await _mesa(mesaId).collection('privado').doc('pedido').set({
        'chave': ChaveMesa.normalizar(chave),
        'uid': meuUid,
      });
      await _mesa(mesaId).update({'mestreUid': meuUid});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw ChaveErrada();
      rethrow;
    }

    await _mesa(mesaId).collection('membros').doc(meuUid).set({
      'nome': meuNome,
      'papel': 'mestre',
      'entrouEm': DateTime.now().toIso8601String(),
      'visto': DateTime.now().toIso8601String(),
    });

    final doc = await _mesa(mesaId).get();
    if (!doc.exists) throw MesaNaoEncontrada();
    return Mesa.fromJson(mesaId, doc.data()!);
  }
```

- [ ] **Step 6: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (37 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/mesa/ test/mesa/mesa_fake_test.dart
git commit -m "mesa: recuperar a mesa com a chave"
```

---

### Task 6: Regras de segurança

**Files:**
- Modify: `firestore.rules`
- Modify: `docs/mesa-verificacao-manual.md`

**Interfaces:**
- Consumes: as coleções criadas nas Tasks 3 a 5.

- [ ] **Step 1: Escrever as regras**

Dentro de `match /mesas/{mesaId}`, trocar a linha de `update` e acrescentar os
blocos novos:

```
      // O mestre manda na mesa. A outra metade é a recuperação: quem prova a
      // chave vira mestre, e SÓ isso — nenhum outro campo pode mudar por aqui.
      allow update: if souMestre(mesaId) || reassumindo(mesaId);
      allow delete: if souMestre(mesaId);

      // A galeria da crônica: todo membro vê, só o mestre mexe.
      match /galeria/{imagemId} {
        allow read:  if souMembro(mesaId);
        allow write: if souMestre(mesaId);
      }

      // A imagem cheia, buscada só quando alguém abre.
      match /imagens/{imagemId} {
        allow read:  if souMembro(mesaId);
        allow write: if souMestre(mesaId);
      }

      // Ninguém lê estes dois: só as regras, com get(). É o que permite
      // guardar a chave sem entregá-la a quem entra na mesa.
      match /privado/chave {
        allow read: if false;
        allow create: if souMestre(mesaId);
        allow update, delete: if false;
      }
      match /privado/pedido {
        allow read: if false;
        allow create, update: if logado();
        allow delete: if souMestre(mesaId);
      }
```

e a função, junto das outras no topo:

```
    function reassumindo(id) {
      let pedido = get(/databases/$(db)/documents/mesas/$(id)/privado/pedido).data;
      let guardada = get(/databases/$(db)/documents/mesas/$(id)/privado/chave).data;
      return logado() &&
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['mestreUid']) &&
        request.resource.data.mestreUid == uid() &&
        pedido.uid == uid() &&
        pedido.chave == guardada.chave;
    }
```

- [ ] **Step 2: Publicar no console**

O container não tem a CLI do Firebase. Publicar pelo console:
**Firestore Database → Regras**, colar o arquivo inteiro e **Publicar**. Colar
pelo teclado quebra: o editor fecha chaves sozinho. Usar a área de
transferência — `navigator.clipboard.writeText(...)`, depois Ctrl+A e Ctrl+V.

- [ ] **Step 3: Acrescentar ao roteiro manual**

Em `docs/mesa-verificacao-manual.md`, na seção nova "Fase 4":

```markdown
| 23 | B tenta `create` em `mesas/{id}/galeria/{x}` (simulador) | **negado** | |
| 24 | B tenta `get` em `mesas/{id}/privado/chave` (simulador) | **negado** | |
| 25 | B tenta `update` em `mesas/{id}` trocando `mestreUid` sem pedido válido | **negado** | |
| 26 | A põe imagem, encerra a sessão, fecha o app; no dia seguinte volta pela lista de mesas | a imagem continua na galeria | |
| 27 | A limpa os dados do app e usa código + chave em "já sou o mestre desta mesa" | volta a ser mestre, galeria intacta | |
| 28 | A apaga a mesa digitando o nome | some para todos; a mesa sai da lista de mesas conhecidas | |
```

- [ ] **Step 4: Commit**

```bash
git add firestore.rules docs/mesa-verificacao-manual.md
git commit -m "mesa: regras da galeria e da chave de recuperacao"
```

---

### Task 7: Mesas conhecidas no aparelho

**Files:**
- Modify: `lib/mesa/mesa_store.dart`
- Create: `test/mesa/mesa_store_test.dart`

**Interfaces:**
- Produces:
  - `class MesaConhecida { String mesaId, nome; PapelMesa papel; String? chave; }` com `fromJson`/`toJson`
  - `MesaStore.conhecidas()` → `List<MesaConhecida>`
  - `MesaStore.lembrar(MesaConhecida)` → `Future<void>` (substitui a de mesmo `mesaId`)
  - `MesaStore.esquecer(String mesaId)` → `Future<void>`
  - `MesaStore.chaveDe(String mesaId)` → `String?`
  - `EstadoMesa` ganha `String? chave`, preservado por `comFicha`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/mesa_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-store');
    await MesaStore.init();
  });

  setUp(() async => Hive.box<String>(MesaStore.boxName).clear());

  test('lembrar guarda a mesa e sobrevive a sair dela', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.mestre, chave: 'K'));
    await MesaStore.entrar(const EstadoMesa(
        mesaId: 'm1', nome: 'Sombras', uid: 'u1', papel: PapelMesa.mestre));

    await MesaStore.limpar();

    expect(MesaStore.atual, isNull);
    expect(MesaStore.conhecidas().single.nome, 'Sombras');
    expect(MesaStore.chaveDe('m1'), 'K');
  });

  test('lembrar a mesma mesa duas vezes não duplica', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.jogador));
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras de SP', papel: PapelMesa.jogador));

    expect(MesaStore.conhecidas().length, 1);
    expect(MesaStore.conhecidas().single.nome, 'Sombras de SP');
  });

  test('esquecer tira da lista', () async {
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm1', nome: 'Sombras', papel: PapelMesa.mestre));
    await MesaStore.lembrar(const MesaConhecida(
        mesaId: 'm2', nome: 'Outra', papel: PapelMesa.jogador));

    await MesaStore.esquecer('m1');

    expect(MesaStore.conhecidas().map((m) => m.mesaId), ['m2']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_store_test.dart"`
Expected: FAIL — `MesaConhecida` não definido.

- [ ] **Step 3: Implementar**

Em `lib/mesa/mesa_store.dart`:

```dart
/// Uma mesa em que este aparelho já entrou. Fica guardada mesmo depois de sair:
/// jogamos todo sábado, e ninguém quer ditar o código toda semana.
class MesaConhecida {
  final String mesaId;
  final String nome;
  final PapelMesa papel;

  /// Só o mestre tem. É o que permite reassumir a mesa noutro aparelho — e é
  /// justamente o que se perde ao limpar os dados do app.
  final String? chave;

  const MesaConhecida({
    required this.mesaId,
    required this.nome,
    required this.papel,
    this.chave,
  });

  factory MesaConhecida.fromJson(Map<String, dynamic> j) => MesaConhecida(
        mesaId: j['mesaId'] as String,
        nome: (j['nome'] ?? '') as String,
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        chave: j['chave'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'nome': nome,
        'papel': papel.name,
        if (chave != null) 'chave': chave,
      };
}
```

e, na classe `MesaStore`:

```dart
  static const String _chaveConhecidas = 'conhecidas';

  static List<MesaConhecida> conhecidas() {
    final s = _box.get(_chaveConhecidas);
    if (s == null) return const [];
    final lista = jsonDecode(s) as List;
    return [
      for (final m in lista)
        MesaConhecida.fromJson((m as Map).cast<String, dynamic>())
    ];
  }

  static Future<void> lembrar(MesaConhecida mesa) async {
    final atuais = conhecidas().where((m) => m.mesaId != mesa.mesaId).toList();
    await _box.put(_chaveConhecidas,
        jsonEncode([mesa, ...atuais].map((m) => m.toJson()).toList()));
  }

  static Future<void> esquecer(String mesaId) async {
    final restantes =
        conhecidas().where((m) => m.mesaId != mesaId).map((m) => m.toJson());
    await _box.put(_chaveConhecidas, jsonEncode(restantes.toList()));
  }

  static String? chaveDe(String mesaId) {
    for (final m in conhecidas()) {
      if (m.mesaId == mesaId) return m.chave;
    }
    return null;
  }
```

Em `EstadoMesa`, acrescentar `final String? chave;` ao construtor, ao
`fromJson` (`chave: j['chave'] as String?`), ao `toJson`
(`if (chave != null) 'chave': chave`) e repassá-lo em `comFicha`.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_store_test.dart"`
Expected: PASS (3 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/mesa_store.dart test/mesa/mesa_store_test.dart
git commit -m "mesa: o aparelho lembra as mesas em que ja entrou"
```

---

### Task 8: Tela da galeria

**Files:**
- Create: `lib/mesa/telas/galeria_mesa.dart`
- Modify: `lib/mesa/telas/mural_da_mesa.dart`
- Create: `test/mesa/galeria_mesa_tela_test.dart`

**Interfaces:**
- Consumes: `MesaService.observarGaleria`, `imagemCheia`, `mostrarAgora`, `apagarDaGaleria`, `ImagemMural.preparar`, `ImagemMural.miniatura`, `escolherRetrato`, `VisualizadorImagens`.
- Produces: `GaleriaMesa({required MesaService servico, required String mesaId, required bool souMestre})`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/galeria_mesa_tela_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/galeria_mesa.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

String _img() {
  final im = img.Image(width: 40, height: 30);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return base64Encode(Uint8List.fromList(img.encodeJpg(im)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;
  late String codigo;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-galeria-tela');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  setUp(() async {
    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, _) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;
    codigo = mesa.codigo;
  });

  Future<void> abrir(WidgetTester t, MesaFake servico,
      {required bool souMestre}) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GaleriaMesa(
            servico: servico, mesaId: mesaId, souMestre: souMestre),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('mostra as imagens guardadas, da mais nova para a mais velha',
      (t) async {
    mestre.relogio = () => DateTime(2026, 8, 1, 20);
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa antigo');
    mestre.relogio = () => DateTime(2026, 8, 8, 20);
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa novo');

    await abrir(t, mestre, souMestre: true);

    expect(find.text('mapa antigo'), findsOneWidget);
    expect(find.text('mapa novo'), findsOneWidget);
    final novo = t.getTopLeft(find.text('mapa novo'));
    final antigo = t.getTopLeft(find.text('mapa antigo'));
    expect(novo.dy, lessThan(antigo.dy));
  });

  testWidgets('tocar numa imagem abre em tela cheia', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    await abrir(t, mestre, souMestre: true);

    await t.tap(find.text('mapa'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });

  testWidgets('galeria vazia explica o que fazer', (t) async {
    await abrir(t, mestre, souMestre: true);

    expect(find.textContaining('Nenhuma imagem'), findsOneWidget);
  });

  testWidgets('jogador não vê apagar nem mostrar agora', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(codigo, 'Kaue');

    await abrir(t, kaue, souMestre: false);

    expect(find.text('mapa'), findsOneWidget);
    expect(find.byTooltip('Mostrar agora'), findsNothing);
    expect(find.byTooltip('Apagar da galeria'), findsNothing);
  });

  testWidgets('mestre apaga e a imagem some da grade', (t) async {
    await mestre.guardarNaGaleria(mesaId, _img(), _img(), 'mapa');
    await abrir(t, mestre, souMestre: true);

    await t.tap(find.byTooltip('Apagar da galeria'));
    await t.pump();
    await t.tap(find.text('Apagar'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('mapa'), findsNothing);
    expect(find.textContaining('Nenhuma imagem'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/galeria_mesa_tela_test.dart"`
Expected: FAIL — `galeria_mesa.dart` não existe.

- [ ] **Step 3: Implementar a galeria**

Criar `lib/mesa/telas/galeria_mesa.dart`: um `StatefulWidget` com
`StreamBuilder<List<ItemGaleria>>` sobre `servico.observarGaleria(mesaId)`.

- Vazia: `Card` com "Nenhuma imagem nesta mesa ainda." e, para o mestre, o
  complemento "Use *Mostrar imagem para a mesa* acima."
- Com itens: `GridView.builder` com `SliverGridDelegateWithMaxCrossAxisExtent`
  (`maxCrossAxisExtent: 160`, `childAspectRatio: 0.8`), cada célula com
  `Image.memory(base64Decode(item.miniaturaBase64), fit: BoxFit.cover)` e
  `errorBuilder` devolvendo `Icon(Icons.broken_image_outlined)`, a legenda em
  `maxLines: 1` com `TextOverflow.ellipsis`, e — só quando `souMestre` — dois
  `IconButton` com `tooltip: 'Mostrar agora'` (`Icons.present_to_all`) e
  `tooltip: 'Apagar da galeria'` (`Icons.delete_outline`).
- Tocar na célula chama `_abrir(item)`:

```dart
  Future<void> _abrir(ItemGaleria item) async {
    setState(() => _carregando = item.id);
    final cheia = await widget.servico.imagemCheia(widget.mesaId, item.id);
    if (!mounted) return;
    setState(() => _carregando = null);
    if (cheia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui carregar a imagem.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': base64Decode(cheia)},
        legendas: {'mural': item.legenda},
      ),
    ));
  }
```

  Enquanto `_carregando == item.id`, a célula mostra um
  `CircularProgressIndicator` por cima da miniatura.
- Apagar pede confirmação num `AlertDialog` com os botões `Cancelar` e
  `Apagar`, e só então chama `servico.apagarDaGaleria`.

- [ ] **Step 4: Adaptar o envio**

Em `lib/mesa/telas/mural_da_mesa.dart`, `_mostrarImagem` passa a gerar os dois
tamanhos e a perguntar o destino:

```dart
      final bytes = ImagemStore.bytes(id);
      if (bytes == null) throw Exception('Não consegui ler a imagem.');
      final imagemId = await servico.guardarNaGaleria(
        mesaId,
        ImagemMural.preparar(bytes),
        ImagemMural.miniatura(bytes),
        legenda ?? '',
      );
      if (mostrarAgora) await servico.mostrarAgora(mesaId, imagemId);
      await ImagemStore.excluir(id);
```

O diálogo de legenda ganha os dois botões no lugar de "Mostrar":
`Guardar na galeria` (devolve `(legenda, false)`) e `Mostrar agora` (devolve
`(legenda, true)`), com `Cancelar` devolvendo null.

- [ ] **Step 5: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/galeria_mesa_tela_test.dart test/mesa/mural_mestre_test.dart"`
Expected: PASS nos dois arquivos.

- [ ] **Step 6: Commit**

```bash
git add lib/mesa/telas/ test/mesa/galeria_mesa_tela_test.dart
git commit -m "mesa: galeria da cronica na tela"
```

---

### Task 9: Aba Mesa com mesas conhecidas, encerrar e apagar

**Files:**
- Modify: `lib/mesa/telas/mesa_aba.dart`
- Modify: `lib/mesa/telas/entrar_mesa_dialogo.dart`
- Create: `test/mesa/mesa_aba_conhecidas_test.dart`

**Interfaces:**
- Consumes: `MesaStore.conhecidas/lembrar/esquecer/chaveDe`, `MesaService.encerrarSessao/apagarMesa/reassumirMesa`, `GaleriaMesa`.
- Produces:
  - `pedirChaveDeMesa(BuildContext)` → `Future<(String codigo, String chave)?>` em `entrar_mesa_dialogo.dart`
  - `MesaService.entrarPorId(String mesaId, String meuNome)` → `Future<Mesa>` — irmão de `entrarPorCodigo` sem a etapa do código, na interface, no fake e no Firestore

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/mesa_aba_conhecidas_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

/// Sozinho no arquivo: entrar grava no Hive de dentro do fake-async.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-conhecidas');
    await MesaStore.init();
  });

  setUp(() async {
    await Hive.box<String>(MesaStore.boxName).clear();

    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final (mesa, chave) = await mestre.criarMesa('Sombras', 'Gabriel');
    mesaId = mesa.id;

    // já esteve nesta mesa, mas não está dentro dela agora
    await MesaStore.lembrar(MesaConhecida(
        mesaId: mesaId,
        nome: 'Sombras',
        papel: PapelMesa.mestre,
        chave: chave));
  });

  testWidgets('fora de mesa, a mesa conhecida aparece para voltar', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsOneWidget);
    expect(find.text('Criar mesa'), findsOneWidget);
    expect(find.text('Entrar com código'), findsOneWidget);
  });

  testWidgets('esquecer tira a mesa da lista', (t) async {
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MesaAba(servico: mestre))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.byTooltip('Esquecer esta mesa'));
    await t.pump();
    await t.tap(find.text('Esquecer'));
    await t.pump();
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('Sombras'), findsNothing);
    expect(MesaStore.conhecidas(), isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_aba_conhecidas_test.dart"`
Expected: FAIL — a lista de mesas conhecidas não existe na tela.

- [ ] **Step 3: Implementar**

Em `_semMesa()`, acima dos botões, listar `MesaStore.conhecidas()`: para cada
uma, um `ListTile` com o nome, o papel como subtítulo, `onTap` chamando
`_voltarPara(m)` e um `IconButton` com `tooltip: 'Esquecer esta mesa'` que pede
confirmação (`Cancelar` / `Esquecer`) e chama `MesaStore.esquecer`.

```dart
  /// Voltar sem código: o registro de membro vem antes de ler a mesa, porque
  /// depois de encerrada a sessão ninguém é membro — e a regra só libera a
  /// leitura para quem já é.
  Future<void> _voltarPara(MesaConhecida m) async {
    await _comEspera(() async {
      final uid = await _servico.entrarAnonimo();
      final mesa = await _servico.entrarPorId(m.mesaId, m.nome);
      await MesaStore.entrar(EstadoMesa(
        mesaId: mesa.id,
        nome: mesa.nome,
        uid: uid,
        papel: mesa.mestreUid == uid ? PapelMesa.mestre : PapelMesa.jogador,
        chave: m.chave,
      ));
      _ligarPonto();
      _sessaoPronta = true;
    });
  }
```

`entrarPorId(String mesaId, String meuNome)` é irmão de `entrarPorCodigo`, sem a
etapa do código: grava o membro e depois lê a mesa. Acrescentar à interface, ao
fake e ao Firestore, com o mesmo corpo de `entrarPorCodigo` a partir da linha do
`membros.set`.

Ao criar mesa e ao entrar por código, chamar `MesaStore.lembrar(...)` com o
papel e — no caso do mestre — a chave.

Depois de criar a mesa, mostrar a chave num `AlertDialog` intransponível
(`barrierDismissible: false`) com o texto: "Guarde esta chave. É com ela que
você recupera a mesa se trocar de celular ou limpar os dados do app. Quem tem a
chave manda na mesa." — com botão de copiar e `Já guardei`.

Na mesa, para o mestre: `Encerrar sessão` no rodapé (confirmação: "Todo mundo
sai da mesa. A mesa, o código e a galeria continuam.") e, no menu ⋮ da tela,
`Apagar mesa`, cuja confirmação exige digitar o nome da mesa — o botão só
habilita quando o texto bate.

Em `entrar_mesa_dialogo.dart`, acrescentar `pedirChaveDeMesa`, com dois campos
(código e chave) e botão `Reassumir`, ligado a um `TextButton`
"Já sou o mestre desta mesa" abaixo de *Entrar com código*.

Quando o stream da mesa emitir null, distinguir os dois casos: se a mesa ainda
está em `MesaStore.conhecidas()`, a mensagem é "A sessão foi encerrada."; se
não, "Esta mesa foi apagada." e `MesaStore.esquecer(mesaId)`.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/"`
Expected: PASS em todos os arquivos de `test/mesa/`.

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/telas/ test/mesa/mesa_aba_conhecidas_test.dart
git commit -m "mesa: voltar sem codigo, encerrar sessao e apagar mesa"
```

---

### Task 10: Ouvinte do mural busca a imagem cheia

**Files:**
- Modify: `lib/mesa/ouvinte_mural.dart`
- Modify: `test/mesa/ouvinte_mural_test.dart`

**Interfaces:**
- Consumes: `MesaService.observarMural` (agora com `imagemId`), `imagemCheia`.

- [ ] **Step 1: Ajustar o teste**

Em `test/mesa/ouvinte_mural_test.dart`, trocar as chamadas de
`mostrarNoMural(mesaId, _imagemBase64(), 'mapa')` por:

```dart
    final id = await mestre.guardarNaGaleria(
        mesaId, _imagemBase64(), _imagemBase64(), 'mapa');
    await mestre.mostrarAgora(mesaId, id);
```

e acrescentar:

```dart
  testWidgets('ponteiro para imagem que sumiu não abre nada', (t) async {
    final (mestre, mesaId) = await mesaAberta(t);
    final id = await mestre.guardarNaGaleria(
        mesaId, _imagemBase64(), _imagemBase64(), 'mapa');
    await mestre.mostrarAgora(mesaId, id);
    await mestre.apagarDaGaleria(mesaId, id);

    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsNothing);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ouvinte_mural_test.dart"`
Expected: FAIL — `item.imagemBase64` não existe mais.

- [ ] **Step 3: Implementar**

Em `lib/mesa/ouvinte_mural.dart`, `_aoMudar` passa a buscar a imagem antes de
abrir:

```dart
  Future<void> _aoMudar(ItemMural? item) async {
    if (item == null || item.imagemId.isEmpty) return;
    if (_ultimoAberto != null && !item.em.isAfter(_ultimoAberto!)) return;
    _ultimoAberto = item.em;

    // o mural só aponta: a imagem cheia é buscada agora, uma vez
    final cheia =
        await widget.servico.imagemCheia(widget.mesaId, item.imagemId);
    if (cheia == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': base64Decode(cheia)},
        legendas: const {'mural': ''},
      ),
    ));
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ouvinte_mural_test.dart"`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/ouvinte_mural.dart test/mesa/ouvinte_mural_test.dart
git commit -m "mesa: ouvinte busca a imagem cheia pelo ponteiro do mural"
```

---

### Task 11: Fechamento da fase

- [ ] **Step 1: Suíte e analyze**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter analyze && flutter test"`
Expected: `No issues found!` e todos os testes passando.

- [ ] **Step 2: README**

Na seção "Mesa online (opcional)", trocar o parágrafo do mural por um que
descreva a galeria (acumula, miniatura separada, *Guardar* vs *Mostrar agora*),
e acrescentar dois parágrafos: mesas conhecidas (voltar sem código, encerrar
sessão contra apagar mesa) e chave de recuperação (o que é, por que existe,
que quem a tem manda na mesa).

- [ ] **Step 3: Beta no aparelho**

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter clean && flutter pub get"
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta --dart-define=CANAL=beta"
unzip -p build/app/outputs/flutter-apk/app-beta-release.apk lib/arm64-v8a/libapp.so \
  | strings -a | grep -c 'Nenhuma imagem'   # 0 = APK velho, refazer
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb \
  -v /home/gabriel/Documentos/rpg/fichas/MagoAAssencao:/app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "adb install -r /app/build/app/outputs/flutter-apk/app-beta-release.apk"
```

Rodar os itens 23 a 28 do roteiro manual.

- [ ] **Step 4: Commit final**

```bash
git add -A
git commit -m "fase 4: mesa permanente e galeria da cronica"
```
