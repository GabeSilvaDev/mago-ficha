# Mesa online · Fase 2 — Ficha espelhada — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O jogador publica uma ficha na mesa e tudo que ele muda aparece para o mestre em segundos — sem que o mestre consiga editar nada.

**Architecture:** A ficha continua vivendo no Hive; a cópia na nuvem é projeção. `FichaStore.salvar` ganha um observador; o `EspelhoFicha` escuta, agrupa as escritas numa janela de 2 segundos e envia o mesmo JSON do export. O mestre lê por um `Stream` e abre a `FichaViewScreen` em modo somente leitura.

**Tech Stack:** Flutter 3.44, `cloud_firestore`, Hive, `flutter_test`, `fake_async` (já vem com `flutter_test`).

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`, branch `mesa-online`.
- Flutter roda por Docker: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter <cmd>"`.
- Depende da Fase 1 concluída (`MesaService`, `MesaFake`, `MesaStore`, aba Mesa).
- Código, comentários e textos de UI em português do Brasil.
- **Um único escritor por ficha: o dono.** O mestre nunca escreve na ficha alheia. Se algum passo deste plano parecer pedir escrita do mestre, o passo está errado.
- Gravação no Hive nunca dentro de `testWidgets`.
- `flutter analyze` limpo antes de cada commit. Não rodar `dart format`.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: O serviço aprende a publicar ficha

**Files:**
- Modify: `lib/mesa/mesa_service.dart`
- Modify: `lib/mesa/mesa_fake.dart`
- Modify: `lib/mesa/mesa_firestore.dart`
- Modify: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Consumes: `MesaService`, `MundoFake`, `SemPermissao`.
- Produces, em `MesaService`:
  - `Future<void> publicarFicha(String mesaId, Map<String, dynamic> ficha, String nome)`
  - `Future<void> despublicarFicha(String mesaId)`
  - `Stream<List<FichaNaMesa>> observarFichas(String mesaId)` — o mestre vê todas
  - `Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid)`
  - `class FichaNaMesa { String donoUid, nome; DateTime atualizadaEm; Map<String, dynamic> ficha; }`

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar em `test/mesa/mesa_fake_test.dart`:

```dart
  test('publicar ficha: o mestre vê, o outro jogador não', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    final erik = MesaFake('u-erik', mundo: mestre.mundo);
    await erik.entrarAnonimo();
    await erik.entrarPorCodigo(mesa.codigo, 'Erik');

    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    // mestre enxerga
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
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia', 'arete': 1}, 'Cotoia');
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia', 'arete': 2}, 'Cotoia');

    final fichas = await mestre.observarFichas(mesa.id).first;
    expect(fichas.length, 1);
    expect(fichas.single.ficha['arete'], 2);
  });

  test('mestre não escreve na ficha do jogador', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    // não existe API para isso; a garantia é o dono do documento
    expect(() => mestre.despublicarFichaDe(mesa.id, 'u-kaue'),
        throwsA(isA<SemPermissao>()));
  });

  test('despublicar tira a ficha da mesa', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    await kaue.despublicarFicha(mesa.id);

    expect(await mestre.observarFichas(mesa.id).first, isEmpty);
  });

  test('sair da mesa despublica a ficha', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');
    await kaue.publicarFicha(mesa.id, {'nome': 'Cotoia'}, 'Cotoia');

    await kaue.sair(mesa.id);

    expect(await mestre.observarFichas(mesa.id).first, isEmpty);
  });
```

O quarto teste usa `despublicarFichaDe`, que existe **só no fake**, como
afirmação executável de que o mestre não tem esse poder.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — `publicarFicha` não definido.

- [ ] **Step 3: Acrescentar à interface**

Em `lib/mesa/mesa_service.dart`:

```dart
/// Uma ficha publicada numa mesa. É uma cópia: a verdade continua no Hive do
/// dono. Só o dono escreve; o mestre lê.
class FichaNaMesa {
  final String donoUid;
  final String nome;
  final DateTime atualizadaEm;
  final Map<String, dynamic> ficha;

  const FichaNaMesa({
    required this.donoUid,
    required this.nome,
    required this.atualizadaEm,
    required this.ficha,
  });

  factory FichaNaMesa.fromJson(String donoUid, Map<String, dynamic> j) =>
      FichaNaMesa(
        donoUid: donoUid,
        nome: (j['nome'] ?? '') as String,
        atualizadaEm: DateTime.parse(j['atualizadaEm'] as String),
        ficha: (j['ficha'] as Map).cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'dono': donoUid,
        'nome': nome,
        'atualizadaEm': atualizadaEm.toIso8601String(),
        'ficha': ficha,
      };
}
```

e, dentro de `abstract class MesaService`:

```dart
  /// Publica (ou atualiza) a MINHA ficha nesta mesa.
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome);

  /// Tira a minha ficha da mesa.
  Future<void> despublicarFicha(String mesaId);

  /// Mestre: todas as fichas publicadas. Jogador: só a dele (uma ou nenhuma).
  Stream<List<FichaNaMesa>> observarFichas(String mesaId);

  /// Uma ficha específica. Null se não existe ou se você não pode ver.
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid);
```

- [ ] **Step 4: Implementar no fake**

Em `MundoFake`, acrescentar `final Map<String, Map<String, FichaNaMesa>> fichas = {};`
e emitir por um `StreamController` próprio em `notificar`.

Em `MesaFake`:

```dart
  @override
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome) async {
    _exigeLogin();
    _exigeMesa(mesaId);
    (mundo.fichas[mesaId] ??= {})[_uid!] = FichaNaMesa(
      donoUid: _uid!,
      nome: nome,
      atualizadaEm: relogio(),
      ficha: Map<String, dynamic>.from(ficha),
    );
    mundo.notificar(mesaId);
  }

  @override
  Future<void> despublicarFicha(String mesaId) async {
    _exigeLogin();
    mundo.fichas[mesaId]?.remove(_uid);
    mundo.notificar(mesaId);
  }

  /// Só existe no fake, para provar nos testes que o mestre NÃO pode.
  Future<void> despublicarFichaDe(String mesaId, String donoUid) async {
    if (donoUid != _uid) throw SemPermissao();
    await despublicarFicha(mesaId);
  }

  bool _souMestreDe(String mesaId) =>
      mundo.mesas[mesaId]?.mestreUid == _uid;

  List<FichaNaMesa> _visiveis(String mesaId) {
    final todas = mundo.fichas[mesaId]?.values.toList() ?? const <FichaNaMesa>[];
    if (_souMestreDe(mesaId)) return todas;
    return todas.where((f) => f.donoUid == _uid).toList();
  }

  @override
  Stream<List<FichaNaMesa>> observarFichas(String mesaId) =>
      mundo.streamFichas(mesaId).map((_) => _visiveis(mesaId));

  @override
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid) =>
      observarFichas(mesaId).map((lista) => lista
          .cast<FichaNaMesa?>()
          .firstWhere((f) => f!.donoUid == donoUid, orElse: () => null));
```

E em `sair`, antes de remover o membro: `mundo.fichas[mesaId]?.remove(_uid);`.

- [ ] **Step 5: Implementar no Firestore**

Em `lib/mesa/mesa_firestore.dart`:

```dart
  @override
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome) async {
    final meuUid = uid;
    if (meuUid == null) throw SemPermissao();
    await _mesa(mesaId).collection('fichas').doc(meuUid).set({
      'dono': meuUid,
      'nome': nome,
      'atualizadaEm': DateTime.now().toIso8601String(),
      'ficha': ficha,
    });
  }

  @override
  Future<void> despublicarFicha(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    await _mesa(mesaId).collection('fichas').doc(meuUid).delete();
  }

  @override
  Stream<List<FichaNaMesa>> observarFichas(String mesaId) => _mesa(mesaId)
      .collection('fichas')
      .snapshots()
      .map((q) =>
          q.docs.map((d) => FichaNaMesa.fromJson(d.id, d.data())).toList());

  @override
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid) =>
      _mesa(mesaId).collection('fichas').doc(donoUid).snapshots().map(
          (d) => d.exists ? FichaNaMesa.fromJson(d.id, d.data()!) : null);
```

E em `sair`, antes de apagar o membro, chamar `await despublicarFicha(mesaId);`.

**A regra do Firestore já cobre a privacidade** (`fichas/{donoUid}` só abre para
o dono e para o mestre): a query de `observarFichas` feita por um jogador comum
devolve só o documento dele. Nenhuma filtragem no cliente protege nada — a
filtragem no `MesaFake` existe apenas para o fake imitar o comportamento real.

- [ ] **Step 6: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (15 testes)

- [ ] **Step 7: Commit**

```bash
git add lib/mesa/ test/mesa/mesa_fake_test.dart
git commit -m "mesa: publicar e observar ficha, com o dono como unico escritor"
```

---

### Task 2: Espelho com agrupamento de escritas

**Files:**
- Create: `lib/mesa/espelho_ficha.dart`
- Modify: `lib/store/ficha_store.dart`
- Create: `test/mesa/espelho_ficha_test.dart`

**Interfaces:**
- Consumes: `MesaService`, `MesaStore`, `FichaIO.paraJson`, `Ficha`.
- Produces:
  - `FichaStore.observador` → `void Function(Ficha)?` (chamado ao fim de `salvar`)
  - `class EspelhoFicha { EspelhoFicha(MesaService, {Duration janela}); void ligar(String mesaId, String fichaId); void desligar(); void aoSalvar(Ficha); Future<void> enviarAgora(); }`
  - `EspelhoFicha.janelaPadrao` → `Duration` (2s)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/espelho_ficha_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/espelho_ficha.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/models/ficha.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  test('rajada de toques vira uma escrita só', () {
    fakeAsync((async) {
      final servico = MesaFake('u-kaue');
      servico.entrarAnonimo();
      late String mesaId;
      servico.criarMesa('Sombras', 'Kaue').then((m) => mesaId = m.id);
      async.flushMicrotasks();

      final espelho = EspelhoFicha(servico);
      final f = Ficha.criar();
      f.data['nome'] = 'Cotoia';
      espelho.ligar(mesaId, f.id);

      // dez toques em menos de dois segundos
      for (var i = 0; i < 10; i++) {
        f.setEsfera('forces', i % 5);
        espelho.aoSalvar(f);
        async.elapse(const Duration(milliseconds: 100));
      }
      // ainda não enviou: a janela não fechou
      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));

      async.elapse(const Duration(seconds: 3));
      final publicada = servico.mundo.fichas[mesaId]!['u-kaue']!;
      expect(publicada.ficha['nome'], 'Cotoia');
      // o valor que foi para a nuvem é o ÚLTIMO, não o primeiro
      expect((publicada.ficha['esferas'] as Map)['forces'], 4);
    });
  });

  test('desligado não envia nada', () {
    fakeAsync((async) {
      final servico = MesaFake('u-kaue');
      servico.entrarAnonimo();
      late String mesaId;
      servico.criarMesa('Sombras', 'Kaue').then((m) => mesaId = m.id);
      async.flushMicrotasks();

      final espelho = EspelhoFicha(servico);
      final f = Ficha.criar();
      espelho.ligar(mesaId, f.id);
      espelho.desligar();

      espelho.aoSalvar(f);
      async.elapse(const Duration(seconds: 5));

      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));
    });
  });

  test('só espelha a ficha publicada, não as outras', () {
    fakeAsync((async) {
      final servico = MesaFake('u-kaue');
      servico.entrarAnonimo();
      late String mesaId;
      servico.criarMesa('Sombras', 'Kaue').then((m) => mesaId = m.id);
      async.flushMicrotasks();

      final espelho = EspelhoFicha(servico);
      final publicada = Ficha.criar();
      final outra = Ficha.criar();
      outra.data['nome'] = 'Outra';
      espelho.ligar(mesaId, publicada.id);

      espelho.aoSalvar(outra);
      async.elapse(const Duration(seconds: 5));

      expect(servico.mundo.fichas[mesaId], anyOf(isNull, isEmpty));
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/espelho_ficha_test.dart"`
Expected: FAIL — `espelho_ficha.dart` não existe.

- [ ] **Step 3: Implementar o espelho**

Criar `lib/mesa/espelho_ficha.dart`:

```dart
import 'dart:async';

import '../models/ficha.dart';
import '../services/ficha_io.dart';
import 'mesa_service.dart';

/// Manda para a mesa a ficha que o jogador publicou, agrupando as escritas.
///
/// O app salva a cada toque numa bolinha. Espelhar toque a toque seria uma
/// escrita por toque; a janela junta a rajada e envia só o estado final.
class EspelhoFicha {
  static const Duration janelaPadrao = Duration(seconds: 2);

  final MesaService _servico;
  final Duration janela;

  String? _mesaId;
  String? _fichaId;
  Ficha? _pendente;
  Timer? _timer;

  EspelhoFicha(this._servico, {this.janela = janelaPadrao});

  bool get ligado => _mesaId != null;

  void ligar(String mesaId, String fichaId) {
    _mesaId = mesaId;
    _fichaId = fichaId;
  }

  void desligar() {
    _timer?.cancel();
    _timer = null;
    _pendente = null;
    _mesaId = null;
    _fichaId = null;
  }

  /// Chamado a cada `FichaStore.salvar`.
  void aoSalvar(Ficha f) {
    if (!ligado || f.id != _fichaId) return;
    _pendente = f;
    _timer ??= Timer(janela, () {
      _timer = null;
      enviarAgora();
    });
  }

  /// Envia o que estiver pendente sem esperar a janela (ao sair da tela, por
  /// exemplo).
  Future<void> enviarAgora() async {
    final f = _pendente;
    final mesaId = _mesaId;
    if (f == null || mesaId == null) return;
    _pendente = null;
    await _servico.publicarFicha(
      mesaId,
      FichaIO.paraJson(f),
      f.nome.isEmpty ? 'Sem nome' : f.nome,
    );
  }
}
```

- [ ] **Step 4: Dar um observador ao `FichaStore`**

Em `lib/store/ficha_store.dart`:

```dart
  /// Avisado ao fim de cada `salvar`. A mesa online usa isso para espelhar a
  /// ficha publicada; fora de mesa é null e nada acontece.
  static void Function(Ficha)? observador;
```

e, no fim de `salvar`:

```dart
  static Future<void> salvar(Ficha f) async {
    f.data['atualizadoEm'] = DateTime.now().toIso8601String();
    await _box.put(f.id, jsonEncode(f.data));
    observador?.call(f);
  }
```

- [ ] **Step 5: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/espelho_ficha_test.dart && flutter test test/ficha_test.dart"`
Expected: PASS nos dois.

- [ ] **Step 6: Commit**

```bash
git add lib/mesa/espelho_ficha.dart lib/store/ficha_store.dart test/mesa/espelho_ficha_test.dart
git commit -m "mesa: espelho da ficha com escrita agrupada"
```

---

### Task 3: Publicar ficha pela aba Mesa

**Files:**
- Modify: `lib/mesa/telas/mesa_aba.dart`
- Modify: `test/mesa/mesa_aba_test.dart`

**Interfaces:**
- Consumes: `EspelhoFicha`, `FichaStore`, `MesaStore.atual`, `EstadoMesa.comFicha`.
- Produces: nenhuma nova; a aba passa a ligar/desligar o espelho.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar em `test/mesa/mesa_aba_test.dart` (com uma ficha semeada em `setUp`,
fora do `testWidgets`):

```dart
  testWidgets('jogador publica uma ficha e ela aparece como publicada',
      (t) async {
    final dono = MesaFake('u-mestre');
    await dono.entrarAnonimo();
    final mesa = await dono.criarMesa('Sombras', 'Gabriel');

    final eu = MesaFake('u-kaue', mundo: dono.mundo);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: MesaAba(servico: eu))));
    await t.pump();

    await t.tap(find.text('Entrar com código'));
    await t.pump();
    await t.enterText(find.byType(TextField).first, mesa.codigo);
    await t.tap(find.widgetWithText(TextButton, 'Entrar'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Publicar uma ficha'), findsOneWidget);
    await t.tap(find.text('Publicar uma ficha'));
    await t.pump();
    await t.tap(find.text('Cassandra Vex')); // ficha semeada no setUp
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.textContaining('Cassandra Vex'), findsWidgets);
    expect(find.text('Publicar uma ficha'), findsNothing);
    expect(find.text('Tirar da mesa'), findsOneWidget);

    final naMesa = await dono.observarFichas(mesa.id).first;
    expect(naMesa.single.nome, 'Cassandra Vex');
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_aba_test.dart"`
Expected: FAIL — não existe "Publicar uma ficha".

- [ ] **Step 3: Implementar**

Na `MesaAba`, quando há mesa e o papel é jogador (ou mestre — o mestre também
pode publicar a ficha dele, se jogar com uma):

- Sem ficha publicada (`MesaStore.atual!.fichaPublicadaId == null`): botão
  `Publicar uma ficha`, que abre um `SimpleDialog` listando
  `FichaStore.todas().where((f) => !f.ehNpc)` com `RetratoAvatar` e nome.
- Ao escolher: `await _servico.publicarFicha(mesaId, FichaIO.paraJson(f), f.nome)`,
  grava `MesaStore.entrar(estado.comFicha(f.id))`, e liga o espelho:

```dart
    _espelho = EspelhoFicha(_servico)..ligar(mesaId, f.id);
    FichaStore.observador = _espelho!.aoSalvar;
```

- Com ficha publicada: mostra o nome dela e um botão `Tirar da mesa`, que chama
  `despublicarFicha`, `MesaStore.entrar(estado.comFicha(null))`,
  `_espelho?.desligar()` e `FichaStore.observador = null`.
- Em `sair` e ao detectar mesa fechada: desligar o espelho e limpar o observador
  também. **Deixar `FichaStore.observador` apontando para um espelho morto faz
  o app escrever numa mesa que não existe mais.**
- No `initState`, se `MesaStore.atual` já tem `fichaPublicadaId`, religar o
  espelho — o app pode ter sido reaberto dentro da mesa.
- No `dispose`, `FichaStore.observador = null` e `_espelho?.desligar()`.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_aba_test.dart"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/telas/mesa_aba.dart test/mesa/mesa_aba_test.dart
git commit -m "mesa: publicar ficha e ligar o espelho"
```

---

### Task 4: Ficha em modo somente leitura

**Files:**
- Modify: `lib/screens/ficha_view_screen.dart`
- Create: `test/mesa/ficha_leitura_test.dart`

**Interfaces:**
- Produces: `FichaViewScreen({String? fichaId, Ficha? fichaDireta, bool somenteLeitura = false})`.

Hoje a tela carrega do `FichaStore` por id. O mestre precisa exibir uma ficha
que **não está** no Hive dele — vem da mesa. Daí o `fichaDireta`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/ficha_leitura_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/ficha_view_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-leitura');
    await Hive.openBox<String>(FichaStore.boxName);
    await NarradorStore.init();
  });

  testWidgets('ficha vinda da mesa abre sem estar no Hive', (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(
        home: FichaViewScreen(fichaDireta: f, somenteLeitura: true)));
    await t.pump();

    expect(find.text('Cotoia'), findsWidgets);
    expect(FichaStore.porId(f.id), isNull); // nunca foi gravada aqui
  });

  testWidgets('somente leitura esconde editar e trava os trackers', (t) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';

    await t.pumpWidget(MaterialApp(
        home: FichaViewScreen(fichaDireta: f, somenteLeitura: true)));
    await t.pump();

    // sem lápis de editar a ficha inteira
    expect(find.byTooltip('Editar ficha inteira (todas as etapas)'),
        findsNothing);
    // trackers desabilitados
    await t.tap(find.text('Status'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final mais = t.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    expect(mais.every((b) => b.onPressed == null), isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ficha_leitura_test.dart"`
Expected: FAIL — `fichaDireta` não é parâmetro conhecido.

- [ ] **Step 3: Implementar**

Em `FichaViewScreen`:

- `fichaId` passa a ser opcional; acrescentar `final Ficha? fichaDireta;` e
  `final bool somenteLeitura;` com `assert(fichaId != null || fichaDireta != null)`.
- `_recarregar()`: se `widget.fichaDireta != null`, usa ela e **não** consulta o
  store.
- `_salvarQuieto()`: se `somenteLeitura`, retorna sem gravar.
- Todos os `onPressed` dos trackers (`_mais`, `_menos`, vitalidade, XP,
  campos do narrador, `SegmentedButton` de tipo) passam a receber `null` quando
  `somenteLeitura`. O jeito mais simples e menos invasivo é um helper no state:

```dart
  /// Em modo leitura todo controle nasce desabilitado — é o que garante que a
  /// tela do mestre não vira tela de edição com botão escondido.
  VoidCallback? _acao(VoidCallback? f) => widget.somenteLeitura ? null : f;
```

  e envolver cada callback existente com `_acao(...)`.
- As ações da `AppBar`: o lápis (`_editar`) só aparece se `!somenteLeitura`. O
  download do PDF continua — o mestre poder baixar o PDF da ficha é útil e não
  escreve nada.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ficha_leitura_test.dart && flutter test test/ficha_view_test.dart"`
Expected: PASS nos dois — o segundo garante que a tela normal não regrediu.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/ficha_view_screen.dart test/mesa/ficha_leitura_test.dart
git commit -m "ficha: modo somente leitura e exibicao de ficha externa"
```

---

### Task 5: Painel do mestre

**Files:**
- Create: `lib/mesa/telas/painel_mestre.dart`
- Modify: `lib/mesa/telas/mesa_aba.dart`
- Create: `test/mesa/painel_mestre_test.dart`

**Interfaces:**
- Consumes: `MesaService.observarFichas`, `FichaNaMesa`, `FichaViewScreen(fichaDireta:, somenteLeitura:)`.
- Produces: `PainelMestre({required MesaService servico, required String mesaId})`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/painel_mestre_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/painel_mestre.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-painel');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  setUp(() async {
    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    mesaId = (await mestre.criarMesa('Sombras', 'Gabriel')).id;

    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo('MAGO-XXXX', 'Kaue').catchError((_) {});
  });

  testWidgets('lista as fichas publicadas com o estado de jogo', (t) async {
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    final mesa = (await mestre.observarMesa(mesaId).first)!;
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    final f = Ficha.criar();
    f.data['nome'] = 'Cotoia';
    f.vitalidadeDano = 2;
    await kaue.publicarFicha(mesaId, FichaIO.paraJson(f), 'Cotoia');

    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Cotoia'), findsOneWidget);
    expect(find.textContaining('Ferido'), findsOneWidget); // 2 de dano
  });

  testWidgets('sem fichas publicadas, explica o que fazer', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.textContaining('Ninguém publicou ficha'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/painel_mestre_test.dart"`
Expected: FAIL — `painel_mestre.dart` não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/telas/painel_mestre.dart`: `StreamBuilder` sobre
`servico.observarFichas(mesaId)` com um `Card` por ficha, cada um mostrando:

- `RetratoAvatar(retratoId: null)` — o retrato vem embutido no JSON como
  `retrato` (base64), então decodifique com `Image.memory(base64Decode(...))`
  quando existir, e caia no ícone padrão quando não;
- o nome, e o nível de vitalidade pelo nome do livro
  (`GameData.niveisVitalidade[dano - 1][0]`, com "Ileso" quando o dano é zero);
- uma linha compacta: `Arete`, `FdV atual/total`, `Quintessência`, `Paradoxo`,
  `XP`, lida do JSON via `Ficha(f.ficha)` — reaproveite o próprio model, que já
  tem todos os getters;
- `subtitle` com "atualizada há X" a partir de `atualizadaEm`.

Tocar no card empurra
`FichaViewScreen(fichaDireta: Ficha(f.ficha), somenteLeitura: true)`.

Lista vazia: texto "Ninguém publicou ficha nesta mesa ainda. Peça para o pessoal
entrar e publicar na aba Mesa."

Na `MesaAba`, quando `papel == PapelMesa.mestre`, mostrar o `PainelMestre`
abaixo da lista de membros.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/painel_mestre_test.dart"`
Expected: PASS (2 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/telas/ test/mesa/painel_mestre_test.dart
git commit -m "mesa: painel do mestre com as fichas publicadas ao vivo"
```

---

### Task 6: Fechamento da fase

- [ ] **Step 1: Suíte e analyze**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test && flutter analyze"`
Expected: tudo verde, `No issues found!`.

- [ ] **Step 2: Acrescentar ao roteiro manual**

Em `docs/mesa-verificacao-manual.md`, incluir:

9. **Espelho** — B publica a ficha; A vê na lista. B marca dano; em poucos segundos A vê o nível mudar sem tocar em nada.
10. **Privacidade** — C (outro jogador) entra na mesma mesa e publica a ficha dele. C **não** vê a ficha de B em lugar nenhum.
11. **Somente leitura** — A abre a ficha de B: não há lápis, e os `+`/`−` dos trackers não respondem.
12. **Sair** — B sai da mesa; a ficha some do painel de A, e no aparelho de B a ficha local continua com o dano marcado.

- [ ] **Step 3: Beta no aparelho e roteiro**

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta"
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb \
  -v /home/gabriel/Documentos/rpg/fichas/MagoAAssencao:/app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "adb install -r /app/build/app/outputs/flutter-apk/app-beta-release.apk"
```

Rodar os itens 9 a 12 com dois aparelhos.

- [ ] **Step 4: Commit final**

```bash
git add -A
git commit -m "fase 2: ficha espelhada concluida"
```
