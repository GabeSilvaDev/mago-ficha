# Mesa online · Fase 1 — Mesa e identidade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar e entrar numa mesa por código curto, ver quem está online e sair — sem que nada disso afete quem nunca usar mesa.

**Architecture:** Firebase Auth anônimo + Cloud Firestore, isolados atrás da interface `MesaService` (implementação Firestore em produção, fake em memória nos testes). `Firebase.initializeApp` só roda quando o usuário entra numa mesa. O estado local ("estou na mesa X como Y") mora numa box Hive própria, seguindo o padrão dos outros stores do projeto.

**Tech Stack:** Flutter 3.44, `firebase_core`, `firebase_auth`, `cloud_firestore`, Hive, `flutter_test`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`, branch `mesa-online`.
- Flutter roda por Docker: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter <cmd>"`. Não existe `flutter` no host.
- Build de APK exige canal: `--flavor estavel` ou `--flavor beta`. Todo teste em aparelho usa `beta`.
- Código, comentários e textos de UI em português do Brasil.
- **O app precisa continuar 100% offline para quem não entra em mesa.** Nenhuma chamada de rede pode acontecer na inicialização.
- Gravação no Hive **nunca** dentro de `testWidgets` — o fake-async trava a suíte. Semear em `setUp`, fora do teste de widget (padrão já usado em `test/narrador_ui_test.dart`).
- `flutter analyze` limpo antes de cada commit. Não rodar `dart format` (o projeto não segue esse estilo e a reformatação polui o diff).
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: Dependências e inicialização preguiçosa do Firebase

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/mesa/firebase_app.dart`
- Create: `test/mesa/firebase_app_test.dart`

**Interfaces:**
- Produces:
  - `FirebaseApp.pronto` → `bool` (já inicializado?)
  - `FirebaseApp.garantir()` → `Future<void>` (idempotente; inicializa na primeira chamada)
  - `FirebaseApp.configurado` → `bool` (existe `firebase_options.dart`?)

- [ ] **Step 1: Passo humano — criar o projeto Firebase**

Este passo é do Gabriel, não do agente. Peça a ele:

1. Abrir <https://console.firebase.google.com> e criar um projeto (ex.: `mago-mesa`).
2. Em **Authentication → Sign-in method**, habilitar **Anônimo**.
3. Em **Firestore Database**, criar banco em modo **produção**, região `southamerica-east1`.
4. No terminal do host, com Node instalado:

```bash
npm i -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
cd /home/gabriel/Documentos/rpg/fichas/MagoAAssencao
flutterfire configure \
  --project=<id-do-projeto> \
  --platforms=android,web \
  --android-package-name=com.kodem.mago_a_ascensao
```

5. Repetir o `flutterfire configure` com `--android-package-name=com.kodem.mago_a_ascensao.beta` para registrar o canal de teste no mesmo projeto.

Isso gera `lib/firebase_options.dart`. O arquivo **pode ser versionado**: chave de cliente Firebase é pública por desenho; quem protege é a regra de segurança (Task 8).

Se ele ainda não fez isso, siga o plano assim mesmo — `FirebaseApp.configurado` devolve `false` e o app continua offline.

- [ ] **Step 2: Acrescentar as dependências**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter pub add firebase_core firebase_auth cloud_firestore"`
Expected: três dependências novas em `pubspec.yaml`.

- [ ] **Step 3: Escrever o teste que falha**

Criar `test/mesa/firebase_app_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/firebase_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sem configuração, o app não tenta inicializar', () async {
    // o projeto pode ainda não ter firebase_options.dart; nesse caso
    // `garantir` precisa falhar de forma controlada, não explodir
    if (FirebaseApp.configurado) {
      return; // já configurado: este teste não se aplica
    }
    expect(FirebaseApp.pronto, isFalse);
    expect(() => FirebaseApp.garantir(), throwsA(isA<MesaIndisponivel>()));
  });
}
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/firebase_app_test.dart"`
Expected: FAIL — `Target of URI doesn't exist: 'package:mago_a_ascensao/mesa/firebase_app.dart'`.

- [ ] **Step 5: Implementar**

Criar `lib/mesa/firebase_app.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';

// Gerado pelo `flutterfire configure`. Enquanto não existir, a mesa fica
// indisponível e o resto do app segue offline, como sempre foi.
// ignore: uri_does_not_exist
import '../firebase_options.dart';

/// A mesa online depende de configuração que pode não existir neste build.
class MesaIndisponivel implements Exception {
  final String mensagem;
  const MesaIndisponivel(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Liga o Firebase só quando alguém entra numa mesa.
///
/// O app é offline por padrão: quem nunca abre a aba Mesa não faz uma única
/// chamada de rede. Por isso a inicialização não mora no `main()`.
class FirebaseApp {
  static bool _pronto = false;
  static bool get pronto => _pronto;

  /// Existe `firebase_options.dart` com um projeto de verdade?
  static bool get configurado {
    try {
      return DefaultFirebaseOptions.currentPlatform.apiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Inicializa uma vez só. Chamar de novo é barato e seguro.
  static Future<void> garantir() async {
    if (_pronto) return;
    if (!configurado) {
      throw const MesaIndisponivel(
          'Este build não tem a mesa online configurada.');
    }
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _pronto = true;
  }
}
```

**Atenção:** se `lib/firebase_options.dart` ainda não existir, o import quebra a
compilação inteira. Enquanto o passo humano não estiver feito, crie um
`lib/firebase_options.dart` mínimo com `apiKey` vazio para o projeto compilar:

```dart
// Substituído pelo `flutterfire configure`. Vazio = mesa indisponível.
class DefaultFirebaseOptions {
  static _Op get currentPlatform => const _Op();
}

class _Op {
  const _Op();
  String get apiKey => '';
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/firebase_app_test.dart"`
Expected: PASS

- [ ] **Step 7: Confirmar que o app continua offline**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test && flutter analyze"`
Expected: todos os testes existentes passam; `No issues found!`. `lib/main.dart` **não** foi tocado — é a garantia de que nada de rede entrou na inicialização.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/mesa/firebase_app.dart lib/firebase_options.dart test/mesa/firebase_app_test.dart
git commit -m "mesa: firebase inicializado sob demanda, nunca na abertura do app"
```

---

### Task 2: Código da mesa

**Files:**
- Create: `lib/mesa/codigo.dart`
- Create: `test/mesa/codigo_test.dart`

**Interfaces:**
- Produces:
  - `CodigoMesa.gerar()` → `String` (ex.: `MAGO-4K7P`)
  - `CodigoMesa.normalizar(String)` → `String` (aceita minúscula, espaço, sem hífen)
  - `CodigoMesa.valido(String)` → `bool`
  - `CodigoMesa.alfabeto` → `String`

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/codigo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/codigo.dart';

void main() {
  test('formato MAGO-XXXX', () {
    for (var i = 0; i < 50; i++) {
      final c = CodigoMesa.gerar();
      expect(RegExp(r'^MAGO-[A-Z0-9]{4}$').hasMatch(c), isTrue, reason: c);
    }
  });

  test('alfabeto não tem caractere ambíguo (o código é ditado em voz alta)',
      () {
    for (final proibido in ['O', '0', 'I', '1', 'L', 'S', '5']) {
      expect(CodigoMesa.alfabeto, isNot(contains(proibido)));
    }
  });

  test('normalizar aceita o que a pessoa digita de verdade', () {
    expect(CodigoMesa.normalizar('mago-4k7p'), 'MAGO-4K7P');
    expect(CodigoMesa.normalizar(' MAGO 4K7P '), 'MAGO-4K7P');
    expect(CodigoMesa.normalizar('4k7p'), 'MAGO-4K7P'); // só a parte variável
    expect(CodigoMesa.normalizar('MAGO4K7P'), 'MAGO-4K7P');
  });

  test('valido rejeita o que não dá para existir', () {
    expect(CodigoMesa.valido(CodigoMesa.gerar()), isTrue);
    expect(CodigoMesa.valido('MAGO-4K7'), isFalse); // curto
    expect(CodigoMesa.valido('MAGO-4K7PP'), isFalse); // longo
    expect(CodigoMesa.valido('MAGO-4K7O'), isFalse); // letra fora do alfabeto
    expect(CodigoMesa.valido(''), isFalse);
  });

  test('gera códigos diferentes', () {
    final vistos = {for (var i = 0; i < 200; i++) CodigoMesa.gerar()};
    expect(vistos.length, greaterThan(190)); // colisão é rara, não impossível
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/codigo_test.dart"`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/codigo.dart`:

```dart
import 'dart:math';

/// Código curto da mesa, feito para ser **ditado em voz alta** numa sala:
/// prefixo fixo `MAGO-` e quatro caracteres de um alfabeto sem nada que se
/// confunda ao falar ou ao ler (sem O/0, I/1/L, S/5).
class CodigoMesa {
  static const String alfabeto = 'ABCDEFGHJKMNPQRTUVWXYZ23467892';
  static const String _prefixo = 'MAGO-';
  static const int _tamanho = 4;

  static final Random _sorte = Random.secure();

  static String gerar() {
    final b = StringBuffer(_prefixo);
    for (var i = 0; i < _tamanho; i++) {
      b.write(alfabeto[_sorte.nextInt(alfabeto.length)]);
    }
    return b.toString();
  }

  /// Aceita o que a pessoa digita: minúscula, com espaço, sem hífen, ou só a
  /// parte variável.
  static String normalizar(String bruto) {
    var t = bruto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.startsWith('MAGO')) t = t.substring(4);
    return '$_prefixo$t';
  }

  static bool valido(String codigo) {
    final c = codigo.toUpperCase();
    if (!c.startsWith(_prefixo)) return false;
    final corpo = c.substring(_prefixo.length);
    if (corpo.length != _tamanho) return false;
    return corpo.split('').every(alfabeto.contains);
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/codigo_test.dart"`
Expected: PASS (5 testes)

Se o teste do alfabeto falhar, confira: a constante acima tem `2` duplicado no
fim — remova a duplicata em vez de mexer no teste.

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/codigo.dart test/mesa/codigo_test.dart
git commit -m "mesa: codigo curto ditavel em voz alta"
```

---

### Task 3: Modelos da mesa

**Files:**
- Create: `lib/mesa/modelos.dart`
- Create: `test/mesa/modelos_test.dart`

**Interfaces:**
- Produces:
  - `enum PapelMesa { mestre, jogador }`
  - `class Membro { String uid, nome; PapelMesa papel; DateTime entrouEm, visto; bool onlineEm(DateTime agora); }`
  - `Membro.fromJson(String uid, Map<String, dynamic>)`, `Membro.toJson()`
  - `class Mesa { String id, nome, codigo, mestreUid; DateTime criadaEm; }`
  - `Mesa.fromJson(String id, Map<String, dynamic>)`, `Mesa.toJson()`
  - `Membro.janelaOnline` → `Duration` (90s)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/modelos_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  final agora = DateTime.utc(2026, 8, 12, 20, 0, 0);

  Membro comVisto(Duration atras) => Membro(
        uid: 'u1',
        nome: 'Kaue',
        papel: PapelMesa.jogador,
        entrouEm: agora.subtract(const Duration(hours: 1)),
        visto: agora.subtract(atras),
      );

  test('online é quem bateu ponto há menos de 90s', () {
    expect(comVisto(const Duration(seconds: 5)).onlineEm(agora), isTrue);
    expect(comVisto(const Duration(seconds: 89)).onlineEm(agora), isTrue);
    expect(comVisto(const Duration(seconds: 91)).onlineEm(agora), isFalse);
    expect(comVisto(const Duration(minutes: 30)).onlineEm(agora), isFalse);
    expect(Membro.janelaOnline, const Duration(seconds: 90));
  });

  test('membro: roundtrip de json', () {
    final m = comVisto(const Duration(seconds: 10));
    final volta = Membro.fromJson('u1', m.toJson());
    expect(volta.uid, 'u1');
    expect(volta.nome, 'Kaue');
    expect(volta.papel, PapelMesa.jogador);
    expect(volta.visto, m.visto);
  });

  test('papel desconhecido cai em jogador, nunca em mestre', () {
    final m = Membro.fromJson('u2', {
      'nome': 'Estranho',
      'papel': 'sei-la',
      'entrouEm': agora.toIso8601String(),
      'visto': agora.toIso8601String(),
    });
    expect(m.papel, PapelMesa.jogador);
  });

  test('mesa: roundtrip de json', () {
    final mesa = Mesa(
      id: 'm1',
      nome: 'Sombras de SP',
      codigo: 'MAGO-4K7P',
      mestreUid: 'u9',
      criadaEm: agora,
    );
    final volta = Mesa.fromJson('m1', mesa.toJson());
    expect(volta.nome, 'Sombras de SP');
    expect(volta.codigo, 'MAGO-4K7P');
    expect(volta.mestreUid, 'u9');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/modelos_test.dart"`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/modelos.dart`:

```dart
enum PapelMesa { mestre, jogador }

/// Quem está na mesa. `visto` é o batimento de presença: o app regrava
/// enquanto está aberto na mesa, e quem parou de bater aparece offline.
class Membro {
  /// Presença vale por 90s — três batimentos de 30s. Uma perda pontual de
  /// rede não derruba o membro da lista.
  static const Duration janelaOnline = Duration(seconds: 90);

  final String uid;
  final String nome;
  final PapelMesa papel;
  final DateTime entrouEm;
  final DateTime visto;

  const Membro({
    required this.uid,
    required this.nome,
    required this.papel,
    required this.entrouEm,
    required this.visto,
  });

  bool onlineEm(DateTime agora) => agora.difference(visto) < janelaOnline;

  factory Membro.fromJson(String uid, Map<String, dynamic> j) => Membro(
        uid: uid,
        nome: (j['nome'] ?? '') as String,
        // desconhecido vira jogador: nunca promover por engano
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        entrouEm: DateTime.parse(j['entrouEm'] as String),
        visto: DateTime.parse(j['visto'] as String),
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'papel': papel.name,
        'entrouEm': entrouEm.toIso8601String(),
        'visto': visto.toIso8601String(),
      };
}

class Mesa {
  final String id;
  final String nome;
  final String codigo;
  final String mestreUid;
  final DateTime criadaEm;

  const Mesa({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.mestreUid,
    required this.criadaEm,
  });

  factory Mesa.fromJson(String id, Map<String, dynamic> j) => Mesa(
        id: id,
        nome: (j['nome'] ?? '') as String,
        codigo: (j['codigo'] ?? '') as String,
        mestreUid: (j['mestreUid'] ?? '') as String,
        criadaEm: DateTime.parse(j['criadaEm'] as String),
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'codigo': codigo,
        'mestreUid': mestreUid,
        'criadaEm': criadaEm.toIso8601String(),
      };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/modelos_test.dart"`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/modelos.dart test/mesa/modelos_test.dart
git commit -m "mesa: modelos de mesa e membro com presenca por batimento"
```

---

### Task 4: Interface do serviço e fake em memória

**Files:**
- Create: `lib/mesa/mesa_service.dart`
- Create: `lib/mesa/mesa_fake.dart`
- Create: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Consumes: `Mesa`, `Membro`, `PapelMesa`, `CodigoMesa`, `MesaIndisponivel`.
- Produces:
  - `abstract class MesaService` com:
    - `Future<String> entrarAnonimo()` → uid
    - `Future<Mesa> criarMesa(String nome, String meuNome)`
    - `Future<Mesa> entrarPorCodigo(String codigo, String meuNome)`
    - `Stream<Mesa?> observarMesa(String mesaId)` (null = mesa fechada)
    - `Stream<List<Membro>> observarMembros(String mesaId)`
    - `Future<void> baterPonto(String mesaId)`
    - `Future<void> sair(String mesaId)`
    - `Future<void> removerMembro(String mesaId, String uid)`
    - `Future<void> trocarCodigo(String mesaId)`
    - `Future<void> fecharMesa(String mesaId)`
  - `class MesaNaoEncontrada implements Exception`
  - `class SemPermissao implements Exception`
  - `class MesaFake implements MesaService` (com `MesaFake(this.uidFixo)` e `relogio`)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/mesa_fake_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_service.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  test('criar mesa: quem cria é o mestre e já é membro', () async {
    final s = MesaFake('u-mestre');
    await s.entrarAnonimo();
    final mesa = await s.criarMesa('Sombras de SP', 'Gabriel');

    expect(mesa.mestreUid, 'u-mestre');
    expect(mesa.codigo, startsWith('MAGO-'));

    final membros = await s.observarMembros(mesa.id).first;
    expect(membros.single.uid, 'u-mestre');
    expect(membros.single.papel, PapelMesa.mestre);
  });

  test('entrar por código: vira jogador', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    final mesmaMesa = await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect(mesmaMesa.id, mesa.id);
    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.length, 2);
    expect(membros.firstWhere((m) => m.uid == 'u-kaue').papel,
        PapelMesa.jogador);
  });

  test('código inexistente é recusado', () async {
    final s = MesaFake('u1');
    await s.entrarAnonimo();
    expect(() => s.entrarPorCodigo('MAGO-ZZZZ', 'Fulano'),
        throwsA(isA<MesaNaoEncontrada>()));
  });

  test('entrar duas vezes não duplica o membro', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect((await mestre.observarMembros(mesa.id).first).length, 2);
  });

  test('sair remove só a si mesmo', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    await jogador.sair(mesa.id);

    final membros = await mestre.observarMembros(mesa.id).first;
    expect(membros.map((m) => m.uid), ['u-mestre']);
  });

  test('só o mestre remove os outros', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect(() => jogador.removerMembro(mesa.id, 'u-mestre'),
        throwsA(isA<SemPermissao>()));

    await mestre.removerMembro(mesa.id, 'u-kaue');
    expect((await mestre.observarMembros(mesa.id).first).length, 1);
  });

  test('trocar código: o antigo para de funcionar', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final antigo = mesa.codigo;

    await mestre.trocarCodigo(mesa.id);
    final atual = (await mestre.observarMesa(mesa.id).first)!;
    expect(atual.codigo, isNot(antigo));

    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    expect(() => jogador.entrarPorCodigo(antigo, 'Kaue'),
        throwsA(isA<MesaNaoEncontrada>()));
    await jogador.entrarPorCodigo(atual.codigo, 'Kaue'); // não lança
  });

  test('fechar mesa: quem observa recebe null', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    await mestre.fecharMesa(mesa.id);

    expect(await mestre.observarMesa(mesa.id).first, isNull);
  });

  test('só o mestre fecha', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final jogador = MesaFake('u-kaue', mundo: mestre.mundo);
    await jogador.entrarAnonimo();
    await jogador.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect(() => jogador.fecharMesa(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('bater ponto atualiza o visto', () async {
    final s = MesaFake('u1');
    await s.entrarAnonimo();
    final mesa = await s.criarMesa('Sombras', 'Gabriel');
    final antes = (await s.observarMembros(mesa.id).first).single.visto;

    s.relogio = () => antes.add(const Duration(minutes: 5));
    await s.baterPonto(mesa.id);

    final depois = (await s.observarMembros(mesa.id).first).single.visto;
    expect(depois.isAfter(antes), isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Escrever a interface**

Criar `lib/mesa/mesa_service.dart`:

```dart
import 'modelos.dart';

/// A mesa procurada não existe (ou o código foi trocado).
class MesaNaoEncontrada implements Exception {
  @override
  String toString() => 'Não encontrei essa mesa.';
}

/// A ação é só do mestre.
class SemPermissao implements Exception {
  @override
  String toString() => 'Só o mestre da mesa pode fazer isso.';
}

/// Tudo que o app precisa da mesa online.
///
/// Existe como interface para as telas serem testáveis sem rede: em produção
/// roda `MesaFirestore`, nos testes roda `MesaFake`.
abstract class MesaService {
  /// Login anônimo. Devolve o uid deste aparelho.
  Future<String> entrarAnonimo();

  /// uid da sessão atual, ou null se ainda não entrou.
  String? get uid;

  Future<Mesa> criarMesa(String nome, String meuNome);

  /// Entra pelo código. Lança [MesaNaoEncontrada] se não existir.
  /// Entrar de novo na mesma mesa é idempotente.
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome);

  /// Emite null quando a mesa deixa de existir (mestre fechou).
  Stream<Mesa?> observarMesa(String mesaId);

  Stream<List<Membro>> observarMembros(String mesaId);

  /// Batimento de presença.
  Future<void> baterPonto(String mesaId);

  /// Sai da mesa (remove só o próprio membro).
  Future<void> sair(String mesaId);

  /// Só o mestre. Lança [SemPermissao] caso contrário.
  Future<void> removerMembro(String mesaId, String uid);

  /// Só o mestre. Gera um código novo e invalida o anterior.
  Future<void> trocarCodigo(String mesaId);

  /// Só o mestre. Apaga a mesa inteira.
  Future<void> fecharMesa(String mesaId);
}
```

- [ ] **Step 4: Escrever o fake**

Criar `lib/mesa/mesa_fake.dart`:

```dart
import 'dart:async';

import 'codigo.dart';
import 'mesa_service.dart';
import 'modelos.dart';

/// Estado compartilhado entre vários `MesaFake` — é o que permite simular
/// mestre e jogador na mesma mesa dentro de um teste.
class MundoFake {
  final Map<String, Mesa> mesas = {};
  final Map<String, Map<String, Membro>> membros = {};
  final Map<String, StreamController<Mesa?>> _mesaCtrl = {};
  final Map<String, StreamController<List<Membro>>> _membrosCtrl = {};
  int _seq = 0;

  String novoId() => 'mesa-${++_seq}';

  void notificar(String mesaId) {
    _mesaCtrl[mesaId]?.add(mesas[mesaId]);
    _membrosCtrl[mesaId]?.add(membros[mesaId]?.values.toList() ?? const []);
  }

  Stream<Mesa?> streamMesa(String id) {
    final c = _mesaCtrl.putIfAbsent(
        id, () => StreamController<Mesa?>.broadcast());
    scheduleMicrotask(() => c.add(mesas[id]));
    return c.stream;
  }

  Stream<List<Membro>> streamMembros(String id) {
    final c = _membrosCtrl.putIfAbsent(
        id, () => StreamController<List<Membro>>.broadcast());
    scheduleMicrotask(
        () => c.add(membros[id]?.values.toList() ?? const []));
    return c.stream;
  }
}

/// Implementação em memória, para testes. Reproduz as mesmas permissões das
/// regras de segurança do Firestore — se elas divergirem, o teste mente.
class MesaFake implements MesaService {
  final String uidFixo;
  final MundoFake mundo;
  DateTime Function() relogio = DateTime.now;

  String? _uid;

  MesaFake(this.uidFixo, {MundoFake? mundo}) : mundo = mundo ?? MundoFake();

  @override
  String? get uid => _uid;

  @override
  Future<String> entrarAnonimo() async => _uid = uidFixo;

  void _exigeLogin() {
    if (_uid == null) throw StateError('Chame entrarAnonimo primeiro.');
  }

  Mesa _exigeMesa(String id) {
    final m = mundo.mesas[id];
    if (m == null) throw MesaNaoEncontrada();
    return m;
  }

  void _exigeMestre(String mesaId) {
    if (_exigeMesa(mesaId).mestreUid != _uid) throw SemPermissao();
  }

  @override
  Future<Mesa> criarMesa(String nome, String meuNome) async {
    _exigeLogin();
    final id = mundo.novoId();
    final mesa = Mesa(
      id: id,
      nome: nome,
      codigo: CodigoMesa.gerar(),
      mestreUid: _uid!,
      criadaEm: relogio(),
    );
    mundo.mesas[id] = mesa;
    mundo.membros[id] = {
      _uid!: Membro(
        uid: _uid!,
        nome: meuNome,
        papel: PapelMesa.mestre,
        entrouEm: relogio(),
        visto: relogio(),
      )
    };
    mundo.notificar(id);
    return mesa;
  }

  @override
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome) async {
    _exigeLogin();
    final alvo = CodigoMesa.normalizar(codigo);
    final mesa = mundo.mesas.values
        .cast<Mesa?>()
        .firstWhere((m) => m!.codigo == alvo, orElse: () => null);
    if (mesa == null) throw MesaNaoEncontrada();

    final atual = mundo.membros[mesa.id]![_uid!];
    mundo.membros[mesa.id]![_uid!] = Membro(
      uid: _uid!,
      nome: meuNome,
      // já era mestre? continua mestre
      papel: atual?.papel ?? PapelMesa.jogador,
      entrouEm: atual?.entrouEm ?? relogio(),
      visto: relogio(),
    );
    mundo.notificar(mesa.id);
    return mesa;
  }

  @override
  Stream<Mesa?> observarMesa(String mesaId) => mundo.streamMesa(mesaId);

  @override
  Stream<List<Membro>> observarMembros(String mesaId) =>
      mundo.streamMembros(mesaId);

  @override
  Future<void> baterPonto(String mesaId) async {
    _exigeLogin();
    final m = mundo.membros[mesaId]?[_uid!];
    if (m == null) return;
    mundo.membros[mesaId]![_uid!] = Membro(
      uid: m.uid,
      nome: m.nome,
      papel: m.papel,
      entrouEm: m.entrouEm,
      visto: relogio(),
    );
    mundo.notificar(mesaId);
  }

  @override
  Future<void> sair(String mesaId) async {
    _exigeLogin();
    mundo.membros[mesaId]?.remove(_uid);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> removerMembro(String mesaId, String alvo) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.membros[mesaId]?.remove(alvo);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> trocarCodigo(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    final m = _exigeMesa(mesaId);
    mundo.mesas[mesaId] = Mesa(
      id: m.id,
      nome: m.nome,
      codigo: CodigoMesa.gerar(),
      mestreUid: m.mestreUid,
      criadaEm: m.criadaEm,
    );
    mundo.notificar(mesaId);
  }

  @override
  Future<void> fecharMesa(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mesas.remove(mesaId);
    mundo.membros.remove(mesaId);
    mundo.notificar(mesaId);
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (10 testes)

- [ ] **Step 6: Commit**

```bash
git add lib/mesa/mesa_service.dart lib/mesa/mesa_fake.dart test/mesa/mesa_fake_test.dart
git commit -m "mesa: interface do servico e fake em memoria"
```

---

### Task 5: Estado local da mesa

**Files:**
- Create: `lib/mesa/mesa_store.dart`
- Create: `test/mesa/mesa_store_test.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces:
  - `MesaStore.boxName` → `'mesa'`
  - `MesaStore.init()` → `Future<void>`
  - `MesaStore.atual` → `EstadoMesa?`
  - `MesaStore.entrar(EstadoMesa)` → `Future<void>`
  - `MesaStore.limpar()` → `Future<void>`
  - `MesaStore.listenable` → `ValueListenable<Box<String>>`
  - `class EstadoMesa { String mesaId, nome, uid; PapelMesa papel; String? fichaPublicadaId; }` + `fromJson`/`toJson`

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
    Hive.init('build/test-hive-mesa');
    await MesaStore.init();
  });

  tearDown(() async => Hive.box<String>(MesaStore.boxName).clear());

  test('sem mesa, atual é null', () {
    expect(MesaStore.atual, isNull);
  });

  test('entrar e limpar', () async {
    await MesaStore.entrar(const EstadoMesa(
      mesaId: 'm1',
      nome: 'Sombras de SP',
      uid: 'u1',
      papel: PapelMesa.mestre,
    ));

    final a = MesaStore.atual!;
    expect(a.mesaId, 'm1');
    expect(a.nome, 'Sombras de SP');
    expect(a.papel, PapelMesa.mestre);
    expect(a.fichaPublicadaId, isNull);

    await MesaStore.limpar();
    expect(MesaStore.atual, isNull);
  });

  test('guarda qual ficha foi publicada', () async {
    await MesaStore.entrar(const EstadoMesa(
      mesaId: 'm1',
      nome: 'Sombras',
      uid: 'u1',
      papel: PapelMesa.jogador,
      fichaPublicadaId: 'ficha-7',
    ));
    expect(MesaStore.atual!.fichaPublicadaId, 'ficha-7');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_store_test.dart"`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/mesa_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'modelos.dart';

/// Em que mesa este aparelho está. Fica no Hive para o app reabrir já dentro
/// da mesa, sem pedir o código de novo.
class EstadoMesa {
  final String mesaId;
  final String nome;
  final String uid;
  final PapelMesa papel;

  /// Ficha local espelhada nesta mesa (Fase 2). Null = ainda não publicou.
  final String? fichaPublicadaId;

  const EstadoMesa({
    required this.mesaId,
    required this.nome,
    required this.uid,
    required this.papel,
    this.fichaPublicadaId,
  });

  EstadoMesa comFicha(String? fichaId) => EstadoMesa(
        mesaId: mesaId,
        nome: nome,
        uid: uid,
        papel: papel,
        fichaPublicadaId: fichaId,
      );

  factory EstadoMesa.fromJson(Map<String, dynamic> j) => EstadoMesa(
        mesaId: j['mesaId'] as String,
        nome: (j['nome'] ?? '') as String,
        uid: j['uid'] as String,
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        fichaPublicadaId: j['fichaPublicadaId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'nome': nome,
        'uid': uid,
        'papel': papel.name,
        if (fichaPublicadaId != null) 'fichaPublicadaId': fichaPublicadaId,
      };
}

class MesaStore {
  static const String boxName = 'mesa';
  static const String _chave = 'atual';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static EstadoMesa? get atual {
    final s = _box.get(_chave);
    if (s == null) return null;
    return EstadoMesa.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> entrar(EstadoMesa e) async =>
      _box.put(_chave, jsonEncode(e.toJson()));

  static Future<void> limpar() async => _box.delete(_chave);
}
```

- [ ] **Step 4: Abrir a box na inicialização**

Em `lib/main.dart`, junto dos outros stores:

```dart
  await MesaStore.init();
```

com `import 'mesa/mesa_store.dart';`.

Abrir a box é leitura de disco local — **não** é conexão de rede. A promessa de
offline continua valendo.

- [ ] **Step 5: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_store_test.dart && flutter test"`
Expected: PASS em tudo.

- [ ] **Step 6: Commit**

```bash
git add lib/mesa/mesa_store.dart lib/main.dart test/mesa/mesa_store_test.dart
git commit -m "mesa: estado local de qual mesa este aparelho esta"
```

---

### Task 6: Implementação Firestore

**Files:**
- Create: `lib/mesa/mesa_firestore.dart`

**Interfaces:**
- Consumes: `MesaService`, `Mesa`, `Membro`, `CodigoMesa`, `FirebaseApp.garantir()`.
- Produces: `class MesaFirestore implements MesaService`.

**Sem teste automatizado.** Firestore não roda no container sem o emulador. O
comportamento está coberto pelo `MesaFake` (Task 4), que reproduz as mesmas
regras; esta classe é a tradução para o SDK. A verificação é o roteiro manual da
Task 8.

- [ ] **Step 1: Implementar**

Criar `lib/mesa/mesa_firestore.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'codigo.dart';
import 'firebase_app.dart';
import 'mesa_service.dart';
import 'modelos.dart';

/// Mesa online de verdade. Espelha, chamada por chamada, o que `MesaFake` faz
/// em memória — se as duas divergirem, os testes passam a mentir.
class MesaFirestore implements MesaService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<String> entrarAnonimo() async {
    await FirebaseApp.garantir();
    final atual = FirebaseAuth.instance.currentUser;
    if (atual != null) return atual.uid;
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user!.uid;
  }

  DocumentReference<Map<String, dynamic>> _mesa(String id) =>
      _db.collection('mesas').doc(id);

  @override
  Future<Mesa> criarMesa(String nome, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final agora = DateTime.now();

    // A mesa vem primeiro: a regra de `codigos` consulta o mestreUid dela.
    final ref = _db.collection('mesas').doc();
    var codigo = CodigoMesa.gerar();
    await ref.set({
      'nome': nome,
      'codigo': codigo,
      'mestreUid': meuUid,
      'criadaEm': agora.toIso8601String(),
    });

    // Colisão de código é rara, mas custa pouco tentar de novo.
    for (var tentativa = 0; tentativa < 5; tentativa++) {
      final doc = _db.collection('codigos').doc(codigo);
      if (!(await doc.get()).exists) {
        await doc.set({'mesaId': ref.id});
        break;
      }
      codigo = CodigoMesa.gerar();
      await ref.update({'codigo': codigo});
    }

    await ref.collection('membros').doc(meuUid).set({
      'nome': meuNome,
      'papel': 'mestre',
      'entrouEm': agora.toIso8601String(),
      'visto': agora.toIso8601String(),
    });

    return Mesa(
      id: ref.id,
      nome: nome,
      codigo: codigo,
      mestreUid: meuUid,
      criadaEm: agora,
    );
  }

  @override
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final alvo = CodigoMesa.normalizar(codigo);

    final atalho = await _db.collection('codigos').doc(alvo).get();
    if (!atalho.exists) throw MesaNaoEncontrada();
    final mesaId = atalho.data()!['mesaId'] as String;

    final membros = _mesa(mesaId).collection('membros').doc(meuUid);
    final jaEra = await membros.get();
    final agora = DateTime.now();

    await membros.set({
      'nome': meuNome,
      // entrar de novo não rebaixa o mestre nem promove ninguém
      'papel': (jaEra.data()?['papel'] as String?) ?? 'jogador',
      'entrouEm':
          (jaEra.data()?['entrouEm'] as String?) ?? agora.toIso8601String(),
      'visto': agora.toIso8601String(),
    });

    final doc = await _mesa(mesaId).get();
    if (!doc.exists) throw MesaNaoEncontrada();
    return Mesa.fromJson(mesaId, doc.data()!);
  }

  @override
  Stream<Mesa?> observarMesa(String mesaId) => _mesa(mesaId).snapshots().map(
      (d) => d.exists ? Mesa.fromJson(mesaId, d.data()!) : null);

  @override
  Stream<List<Membro>> observarMembros(String mesaId) => _mesa(mesaId)
      .collection('membros')
      .snapshots()
      .map((q) => q.docs.map((d) => Membro.fromJson(d.id, d.data())).toList());

  @override
  Future<void> baterPonto(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    await _mesa(mesaId)
        .collection('membros')
        .doc(meuUid)
        .update({'visto': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> sair(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    await _mesa(mesaId).collection('membros').doc(meuUid).delete();
  }

  @override
  Future<void> removerMembro(String mesaId, String alvo) async {
    try {
      await _mesa(mesaId).collection('membros').doc(alvo).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> trocarCodigo(String mesaId) async {
    final doc = await _mesa(mesaId).get();
    if (!doc.exists) throw MesaNaoEncontrada();
    final antigo = doc.data()!['codigo'] as String;
    final novo = CodigoMesa.gerar();
    try {
      await _db.collection('codigos').doc(novo).set({'mesaId': mesaId});
      await _mesa(mesaId).update({'codigo': novo});
      await _db.collection('codigos').doc(antigo).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> fecharMesa(String mesaId) async {
    final doc = await _mesa(mesaId).get();
    if (!doc.exists) return;
    final codigo = doc.data()!['codigo'] as String;
    try {
      // subcoleções não somem sozinhas: apaga membros antes da mesa
      final membros = await _mesa(mesaId).collection('membros').get();
      for (final m in membros.docs) {
        await m.reference.delete();
      }
      await _db.collection('codigos').doc(codigo).delete();
      await _mesa(mesaId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }
}
```

- [ ] **Step 2: Analisar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter analyze"`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/mesa/mesa_firestore.dart
git commit -m "mesa: implementacao firestore do servico"
```

---

### Task 7: Aba Mesa

**Files:**
- Create: `lib/mesa/telas/mesa_aba.dart`
- Create: `lib/mesa/telas/entrar_mesa_dialogo.dart`
- Modify: `lib/screens/home_screen.dart` (barra de navegação: 2 → 3 abas)
- Create: `test/mesa/mesa_aba_test.dart`

**Interfaces:**
- Consumes: `MesaService`, `MesaFake`, `MesaStore`, `EstadoMesa`, `Membro`, `PapelMesa`.
- Produces: `MesaAba({MesaService? servico})` — sem acento, porque é o nome que os testes usam. Existe para o teste injetar o fake; em produção fica null e a tela usa `MesaFirestore`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/mesa_aba_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/mesa_store.dart';
import 'package:mago_a_ascensao/mesa/telas/mesa_aba.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-mesa-aba');
    await MesaStore.init();
  });

  setUp(() async => Hive.box<String>(MesaStore.boxName).clear());

  testWidgets('sem mesa: oferece criar ou entrar', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: MesaAba(servico: MesaFake('u1')))));
    await t.pump();

    expect(find.text('Criar mesa'), findsOneWidget);
    expect(find.text('Entrar com código'), findsOneWidget);
    expect(find.textContaining('Você não está em nenhuma mesa'), findsOneWidget);
  });

  testWidgets('criar mesa mostra o código e me lista como mestre', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: MesaAba(servico: MesaFake('u1')))));
    await t.pump();

    await t.tap(find.text('Criar mesa'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Sombras de SP');
    await t.tap(find.widgetWithText(TextButton, 'Criar'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Sombras de SP'), findsOneWidget);
    expect(find.textContaining('MAGO-'), findsOneWidget);
    expect(find.text('mestre'), findsOneWidget);
    // ações que só o mestre tem
    expect(find.byTooltip('Trocar código'), findsOneWidget);
    expect(find.byTooltip('Fechar mesa'), findsOneWidget);
  });

  testWidgets('jogador não vê as ações de mestre', (t) async {
    // mesa criada por outro aparelho
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

    expect(find.text('Sombras'), findsOneWidget);
    expect(find.byTooltip('Trocar código'), findsNothing);
    expect(find.byTooltip('Fechar mesa'), findsNothing);
    expect(find.text('Sair da mesa'), findsOneWidget);
  });

  testWidgets('código errado mostra recado, não quebra', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: MesaAba(servico: MesaFake('u1')))));
    await t.pump();

    await t.tap(find.text('Entrar com código'));
    await t.pump();
    await t.enterText(find.byType(TextField).first, 'MAGO-ZZZZ');
    await t.tap(find.widgetWithText(TextButton, 'Entrar'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.textContaining('Não encontrei essa mesa'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_aba_test.dart"`
Expected: FAIL — `mesa_aba.dart` não existe.

- [ ] **Step 3: Implementar a aba**

Criar `lib/mesa/telas/mesa_aba.dart` com este comportamento:

- `StatefulWidget` com `final MesaService? servico`; no `initState`,
  `_servico = widget.servico ?? MesaFirestore()`.
- Estado a partir de `MesaStore.atual`:
  - **null** → coluna centralizada com o texto "Você não está em nenhuma mesa."
    e dois botões: `Criar mesa` e `Entrar com código`, cada um abrindo o diálogo
    da Task 7 Step 4.
  - **preenchido** → `StreamBuilder` sobre `_servico.observarMesa(id)`:
    - emitiu `null` → a mesa foi fechada: chama `MesaStore.limpar()`, mostra
      "O mestre encerrou a mesa." e volta ao estado sem mesa;
    - emitiu mesa → cabeçalho com o nome, linha do código com `IconButton`
      (`tooltip: 'Copiar código'`, `Clipboard.setData`), e um
      `StreamBuilder` sobre `observarMembros(id)` listando cada membro com
      `RetratoAvatar`-like: bolinha verde se `onlineEm(DateTime.now())`, cinza
      se não, o nome e o papel em texto pequeno (`mestre` / `jogador`).
- Ações do mestre (só quando `MesaStore.atual!.papel == PapelMesa.mestre`):
  `IconButton(tooltip: 'Trocar código')`, `IconButton(tooltip: 'Fechar mesa')`
  (com `AlertDialog` de confirmação, no padrão de `_confirmarExcluir` da home),
  e uma lixeira por membro que chama `removerMembro`.
- Ação de todos: `TextButton('Sair da mesa')` → `_servico.sair(id)` +
  `MesaStore.limpar()`.
- Batimento: `Timer.periodic(const Duration(seconds: 30), ...)` chamando
  `baterPonto`, criado no `initState` quando há mesa e **cancelado no
  `dispose`** — timer vazado em teste de widget faz a suíte falhar com
  "A Timer is still pending".
- Erros de rede: `try/catch` em volta de cada chamada, mostrando o
  `e.toString()` num `SnackBar`. As exceções do domínio (`MesaNaoEncontrada`,
  `SemPermissao`, `MesaIndisponivel`) já têm mensagem em português.

- [ ] **Step 4: Implementar o diálogo de criar/entrar**

Criar `lib/mesa/telas/entrar_mesa_dialogo.dart` com duas funções:

```dart
/// Pergunta o nome da mesa e o seu nome. Devolve (nomeDaMesa, meuNome).
Future<(String, String)?> pedirDadosDaMesa(BuildContext context);

/// Pergunta o código e o seu nome. Devolve (codigo, meuNome).
Future<(String, String)?> pedirCodigo(BuildContext context);
```

Ambos são `AlertDialog` no padrão visual do app (`backgroundColor:
Cores.pergaminho`), com `TextField` autofocado. O de criar usa o botão `Criar`;
o de entrar usa `Entrar` — os testes procuram exatamente esses rótulos. O campo
de código aplica `CodigoMesa.normalizar` ao confirmar e recusa com
"Código inválido." se `CodigoMesa.valido` for falso.

- [ ] **Step 5: Terceira aba na home**

Em `lib/screens/home_screen.dart`, `IndexedStack` e `NavigationBar` passam de
dois para três itens, com a Mesa no meio:

```dart
      body: IndexedStack(
        index: _aba,
        children: const [_AbaMagosHolder(), MesaAba(), NarradorScreen()],
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
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Mesa'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Narrador'),
        ],
      ),
```

O título da `AppBar` passa a escolher entre três: `'MAGO: A ASCENSÃO'`,
`'MESA'` e `'NARRADOR'`. `_abaMagos(context)` já existe e continua igual —
extraia para um widget se o `const` da lista incomodar.

- [ ] **Step 6: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_aba_test.dart"`
Expected: PASS (4 testes)

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/narrador_ui_test.dart"`
Expected: PASS — o teste `home tem as abas Magos e Narrador` continua válido com
três abas; se ele procurar exatamente duas, atualize-o para incluir `'Mesa'`.

- [ ] **Step 7: Commit**

```bash
git add lib/mesa/telas/ lib/screens/home_screen.dart test/mesa/mesa_aba_test.dart test/narrador_ui_test.dart
git commit -m "mesa: aba propria com criar, entrar, membros e presenca"
```

---

### Task 8: Regras de segurança

**Files:**
- Create: `firestore.rules`
- Create: `docs/mesa-verificacao-manual.md`

**Interfaces:** nenhuma de código. Entrega a regra publicada e o roteiro de conferência.

**Por que sem teste automatizado:** regra de Firestore só se testa com o
emulador (`firebase emulators:exec`), que exige Node e Java no container — que
hoje só tem o SDK Flutter. Em vez de fingir cobertura, o roteiro abaixo é
executado à mão com dois aparelhos.

- [ ] **Step 1: Escrever o arquivo de regras**

Criar `firestore.rules` com exatamente o conteúdo da seção "Regras de segurança"
do spec (`docs/superpowers/specs/2026-08-12-mesa-online-design.md`), incluindo o
bloco `codigos` com `create`/`delete` condicionados ao `mestreUid`.

- [ ] **Step 2: Publicar as regras**

Passo do Gabriel, no host:

```bash
cd /home/gabriel/Documentos/rpg/fichas/MagoAAssencao
firebase deploy --only firestore:rules --project <id-do-projeto>
```

Ou colar o conteúdo em **Firestore → Regras** no console e publicar.

- [ ] **Step 3: Escrever o roteiro de verificação**

Criar `docs/mesa-verificacao-manual.md` com esta lista, para rodar com dois
aparelhos (ou um aparelho e o PWA em aba anônima):

1. **Criar e entrar** — A cria a mesa; B entra com o código. B aparece na lista de A como jogador, e A aparece como mestre.
2. **Presença** — B fecha o app; em até 90s a bolinha de B fica cinza na tela de A.
3. **Código trocado** — A troca o código; um terceiro tenta com o antigo e recebe "Não encontrei essa mesa."
4. **Remover** — A remove B; B volta sozinho ao estado sem mesa.
5. **Fechar** — A fecha a mesa; B recebe "O mestre encerrou a mesa."
6. **Permissão de escrita** — no console do Firebase, aba Firestore, tentar como B (usando o simulador de regras com o uid de B) `update` em `mesas/{id}` → deve ser **negado**.
7. **Permissão de leitura** — simulador com um uid que não é membro tentando `get` em `mesas/{id}` → **negado**.
8. **Offline** — com A na mesa, desligar o wifi, mexer no app, religar: a lista volta a atualizar sem reiniciar o app.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules docs/mesa-verificacao-manual.md
git commit -m "mesa: regras de seguranca e roteiro de verificacao"
```

---

### Task 9: QR do código (opcional)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/mesa/telas/mesa_aba.dart`
- Create: `test/mesa/qr_test.dart`

**Interfaces:**
- Produces: botão `Mostrar QR` na tela da mesa, exibindo `QrImageView` com o texto do código.

Esta task é **descartável**: o código digitado já resolve a entrada. Se o pacote
der trabalho, pule e siga para a Task 10.

- [ ] **Step 1: Acrescentar a dependência**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter pub add qr_flutter"`

- [ ] **Step 2: Escrever o teste**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('QR do código monta sem estourar', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: QrImageView(data: 'MAGO-4K7P'))),
    ));
    await t.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Ligar na tela**

Na linha do código, acrescentar `IconButton(tooltip: 'Mostrar QR')` que abre um
`AlertDialog` com `QrImageView(data: mesa.codigo, size: 220)` e o código escrito
embaixo em fonte grande.

**Não** entra leitor de QR: quem escaneia usa a câmera nativa do celular, que
mostra o texto do código para digitar. Leitor embutido exigiria permissão de
câmera e um pacote pesado, para economizar quatro caracteres.

- [ ] **Step 4: Rodar e commitar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test && flutter analyze"`

```bash
git add pubspec.yaml pubspec.lock lib/mesa/telas/mesa_aba.dart test/mesa/qr_test.dart
git commit -m "mesa: QR do codigo na tela da mesa"
```

---

### Task 10: Fechamento da fase

- [ ] **Step 1: Suíte inteira**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test"`
Expected: PASS, incluindo os 118 testes que já existiam.

- [ ] **Step 2: Analisar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter analyze"`
Expected: `No issues found!`

- [ ] **Step 3: Provar que o app segue offline**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter build web --release"`
Depois, servir `build/web` e abrir **com a rede desligada**: a lista de magos, a
criação de ficha e o PDF continuam funcionando; a aba Mesa mostra o erro de
conexão sem derrubar o resto.

- [ ] **Step 4: Instalar o canal beta no aparelho**

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta"
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb \
  -v /home/gabriel/Documentos/rpg/fichas/MagoAAssencao:/app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "adb install -r /app/build/app/outputs/flutter-apk/app-beta-release.apk"
```

O canal estável não é tocado: a mesa online só existe no beta até a fase fechar.

- [ ] **Step 5: Rodar o roteiro manual**

Executar `docs/mesa-verificacao-manual.md` inteiro, com o beta em dois
aparelhos. Anotar no próprio arquivo o que passou.

- [ ] **Step 6: Commit final**

```bash
git add -A
git commit -m "fase 1: mesa e identidade concluidas"
```
