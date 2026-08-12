# Fase 3 — Retrato do personagem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cada ficha pode ter um retrato escolhido da galeria do aparelho, que aparece na lista, na ficha e no anexo do PDF, e viaja junto no export JSON.

**Architecture:** Imagem mora numa box Hive própria (`imagens`, id → JPEG em base64), não dentro da ficha: a ficha é reescrita inteira a cada `salvar()` e um retrato embutido viraria centenas de KB reescritos a cada toque numa bolinha. A ficha guarda só `retratoId`. O `ImagemStore` reduz para no máximo 1024px e recomprime em JPEG q80 na entrada, então o tamanho é limitado na origem. No export JSON o retrato é embutido em base64 para o arquivo continuar self-contained.

**Tech Stack:** Flutter, Hive (`hive_flutter`), pacote `image` (redimensionar/recomprimir, Dart puro — funciona na web), `file_picker` (já é dependência), pacote `pdf`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`.
- Código, comentários e textos em português do Brasil.
- Nenhum campo obrigatório novo: ficha sem `retratoId` funciona igual.
- Retrato guardado sempre como JPEG, no máximo 1024px no maior lado, qualidade 80.
- Testes de store usam `Hive.init('build/test-hive-<nome>')` e limpam a box no `tearDown` — não usar o diretório do usuário.
- Rodar `flutter analyze` antes de cada commit; zero warning novo.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: `ImagemStore`

**Files:**
- Create: `lib/store/imagem_store.dart`
- Modify: `pubspec.yaml` (dependência `image`)
- Modify: `lib/main.dart:7-12`
- Test: `test/imagem_store_test.dart` (criar)

**Interfaces:**
- Consumes: nada.
- Produces:
  - `ImagemStore.boxName` → `String` (`'imagens'`)
  - `ImagemStore.init()` → `Future<void>`
  - `ImagemStore.reduzir(Uint8List bytes)` → `Uint8List` (JPEG, máx 1024px, q80)
  - `ImagemStore.salvar(Uint8List bytes)` → `Future<String>` (id novo)
  - `ImagemStore.salvarBase64(String base64)` → `Future<String>`
  - `ImagemStore.bytes(String id)` → `Uint8List?`
  - `ImagemStore.base64De(String id)` → `String?`
  - `ImagemStore.excluir(String id)` → `Future<void>`
  - `ImagemStore.limpar(Set<String> usados)` → `Future<int>` (quantas apagou)

- [ ] **Step 1: Acrescentar a dependência**

Run: `flutter pub add image`
Expected: `pubspec.yaml` ganha `image: ^<versão>` em `dependencies` e `flutter pub get` roda sozinho.

- [ ] **Step 2: Escrever o teste que falha**

Criar `test/imagem_store_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/store/imagem_store.dart';

Uint8List _pngGrande() {
  final im = img.Image(width: 2400, height: 1600);
  img.fill(im, color: img.ColorRgb8(120, 40, 160));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-imagem');
    await ImagemStore.init();
  });

  tearDown(() async => Hive.box<String>(ImagemStore.boxName).clear());

  test('reduzir: encolhe para 1024px no maior lado e devolve JPEG', () {
    final saida = ImagemStore.reduzir(_pngGrande());
    final decodificada = img.decodeImage(saida)!;
    expect(decodificada.width, 1024);
    expect(decodificada.height, lessThanOrEqualTo(1024));
    // assinatura JPEG
    expect(saida[0], 0xFF);
    expect(saida[1], 0xD8);
    expect(saida.length, lessThan(_pngGrande().length));
  });

  test('salvar e ler de volta', () async {
    final id = await ImagemStore.salvar(_pngGrande());
    expect(id, isNotEmpty);
    expect(ImagemStore.bytes(id), isNotNull);
    expect(ImagemStore.base64De(id), isNotNull);
    expect(ImagemStore.bytes('inexistente'), isNull);
  });

  test('excluir remove a imagem', () async {
    final id = await ImagemStore.salvar(_pngGrande());
    await ImagemStore.excluir(id);
    expect(ImagemStore.bytes(id), isNull);
  });

  test('limpar apaga órfã e preserva a que está em uso', () async {
    final usada = await ImagemStore.salvar(_pngGrande());
    final orfa = await ImagemStore.salvar(_pngGrande());

    final apagadas = await ImagemStore.limpar({usada});

    expect(apagadas, 1);
    expect(ImagemStore.bytes(usada), isNotNull);
    expect(ImagemStore.bytes(orfa), isNull);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/imagem_store_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mago_a_ascensao/store/imagem_store.dart'`.

- [ ] **Step 4: Implementar**

Criar `lib/store/imagem_store.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// Guarda as imagens do app (retratos das fichas e imagens dos cadernos do
/// narrador) numa box própria: a ficha é reescrita inteira a cada `salvar()`,
/// então um retrato embutido nela seria copiado a cada toque numa bolinha.
///
/// Toda imagem entra reduzida para no máximo [maxLado] px no maior lado e
/// recomprimida em JPEG [qualidade] — o tamanho fica limitado na origem.
class ImagemStore {
  static const String boxName = 'imagens';
  static const int maxLado = 1024;
  static const int qualidade = 80;

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  /// Reduz e recomprime. Imagem menor que [maxLado] só é recomprimida.
  static Uint8List reduzir(Uint8List bytes) {
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Não foi possível ler a imagem.');
    }
    final maior = original.width > original.height
        ? original.width
        : original.height;
    final ajustada = maior > maxLado
        ? img.copyResize(
            original,
            width: original.width >= original.height ? maxLado : null,
            height: original.height > original.width ? maxLado : null,
            interpolation: img.Interpolation.average,
          )
        : original;
    return Uint8List.fromList(img.encodeJpg(ajustada, quality: qualidade));
  }

  /// Guarda a imagem e devolve o id.
  static Future<String> salvar(Uint8List bytes) async {
    final id = const Uuid().v4();
    await _box.put(id, base64Encode(reduzir(bytes)));
    return id;
  }

  /// Guarda uma imagem que veio em base64 (import de ficha/backup).
  static Future<String> salvarBase64(String b64) async =>
      salvar(base64Decode(b64.contains(',') ? b64.split(',').last : b64));

  static Uint8List? bytes(String id) {
    final s = _box.get(id);
    return s == null ? null : base64Decode(s);
  }

  static String? base64De(String id) => _box.get(id);

  static Future<void> excluir(String id) async => _box.delete(id);

  /// Apaga as imagens que ninguém mais referencia. Devolve quantas saíram.
  static Future<int> limpar(Set<String> usados) async {
    final orfas = _box.keys.cast<String>().where((k) => !usados.contains(k)).toList();
    await _box.deleteAll(orfas);
    return orfas.length;
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/imagem_store_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 6: Abrir a box na inicialização**

Em `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'data/game_data.dart';
import 'store/ficha_store.dart';
import 'store/imagem_store.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameData.carregar();
  await FichaStore.init();
  await ImagemStore.init();
  await FichaStore.limparImagensOrfas();
  runApp(const AppMagoAscensao());
}
```

`FichaStore.limparImagensOrfas()` entra na Task 2.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/store/imagem_store.dart lib/main.dart test/imagem_store_test.dart
git commit -m "store: guarda imagens reduzidas em box propria"
```

---

### Task 2: `retratoId` na ficha e faxina de órfãs

**Files:**
- Modify: `lib/models/ficha.dart` (bloco de Identidade)
- Modify: `lib/store/ficha_store.dart`
- Test: `test/ficha_test.dart`, `test/imagem_store_test.dart`

**Interfaces:**
- Consumes: `ImagemStore`.
- Produces:
  - `Ficha.retratoId` → `String?` (getter e setter)
  - `Ficha.temRetrato` → `bool`
  - `FichaStore.imagensUsadas()` → `Set<String>`
  - `FichaStore.limparImagensOrfas()` → `Future<int>`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ficha_test.dart`:

```dart
  test('retratoId: ausente é null e aceita atribuição', () {
    final f = Ficha.criar();
    expect(f.retratoId, isNull);
    expect(f.temRetrato, isFalse);
    f.retratoId = 'img-1';
    expect(f.retratoId, 'img-1');
    expect(f.temRetrato, isTrue);
    f.retratoId = null;
    expect(f.retratoId, isNull);
  });
```

Em `test/imagem_store_test.dart`, acrescentar (com `FichaStore` e `Ficha` importados e a box `fichas` aberta no `setUpAll`):

```dart
  test('faxina preserva o retrato em uso e apaga o resto', () async {
    final usada = await ImagemStore.salvar(_pngGrande());
    await ImagemStore.salvar(_pngGrande()); // órfã

    final f = Ficha.criar();
    f.retratoId = usada;
    await FichaStore.salvar(f);

    final apagadas = await FichaStore.limparImagensOrfas();

    expect(apagadas, 1);
    expect(ImagemStore.bytes(usada), isNotNull);
  });
```

Ajustar o `setUpAll` desse arquivo para abrir também a box de fichas:

```dart
  setUpAll(() async {
    Hive.init('build/test-hive-imagem');
    await ImagemStore.init();
    await Hive.openBox<String>(FichaStore.boxName);
  });

  tearDown(() async {
    await Hive.box<String>(ImagemStore.boxName).clear();
    await Hive.box<String>(FichaStore.boxName).clear();
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_test.dart test/imagem_store_test.dart`
Expected: FAIL — `retratoId` e `limparImagensOrfas` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/models/ficha.dart`, junto dos getters de identidade:

```dart
  /// Id do retrato no `ImagemStore` (null = ficha sem retrato).
  String? get retratoId {
    final v = data['retratoId'];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  set retratoId(String? v) {
    if (v == null || v.isEmpty) {
      data.remove('retratoId');
    } else {
      data['retratoId'] = v;
    }
  }

  bool get temRetrato => retratoId != null;
```

Em `lib/store/ficha_store.dart`:

```dart
import '../store/imagem_store.dart';
```
(no topo, junto dos outros imports — ajustar para `import 'imagem_store.dart';` já que estão na mesma pasta)

```dart
  /// Ids de imagem referenciados por alguma ficha.
  static Set<String> imagensUsadas() =>
      {for (final f in todas()) if (f.retratoId != null) f.retratoId!};

  /// Apaga imagens que nenhuma ficha usa mais. Devolve quantas saíram.
  static Future<int> limparImagensOrfas() =>
      ImagemStore.limpar(imagensUsadas());
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_test.dart test/imagem_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/ficha.dart lib/store/ficha_store.dart test/ficha_test.dart test/imagem_store_test.dart
git commit -m "ficha: campo retratoId e faxina de imagens orfas"
```

---

### Task 3: Retrato embutido no export/import JSON

**Files:**
- Modify: `lib/services/ficha_io.dart`
- Test: `test/ficha_io_test.dart` (criar)

**Interfaces:**
- Consumes: `ImagemStore.base64De`, `ImagemStore.salvarBase64`, `Ficha.retratoId`.
- Produces:
  - `FichaIO.paraJson(Ficha f)` → `Map<String, dynamic>` (cópia com `retrato` embutido, sem `retratoId`)
  - `FichaIO.deJson(Map<String, dynamic> json)` → `Future<Ficha>` (extrai `retrato` para o store, resolve id repetido)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/ficha_io_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/ficha_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

Uint8List _png() {
  final im = img.Image(width: 300, height: 200);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-io');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();
  });

  test('export embute o retrato e import extrai para o store', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Com foto';
    f.retratoId = await ImagemStore.salvar(_png());
    await FichaStore.salvar(f);

    final json = FichaIO.paraJson(f);
    expect(json['retrato'], isA<String>());
    expect(json.containsKey('retratoId'), isFalse);

    await Hive.box<String>(ImagemStore.boxName).clear();
    final volta = await FichaIO.deJson(json);

    expect(volta.nome, 'Com foto');
    expect(volta.retratoId, isNotNull);
    expect(ImagemStore.bytes(volta.retratoId!), isNotNull);
  });

  test('ficha sem retrato não ganha o campo', () {
    final f = Ficha.criar();
    expect(FichaIO.paraJson(f).containsKey('retrato'), isFalse);
  });

  test('import de id já existente gera id novo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Original';
    await FichaStore.salvar(f);

    final volta = await FichaIO.deJson(FichaIO.paraJson(f));
    expect(volta.id, isNot(f.id));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_io_test.dart`
Expected: FAIL — `The method 'paraJson' isn't defined for the type 'FichaIO'`.

- [ ] **Step 3: Implementar**

Em `lib/services/ficha_io.dart`, acrescentar os dois métodos e usá-los no export/import que já existem:

```dart
  /// Ficha em JSON pronta para virar arquivo: o retrato vai embutido em
  /// base64 para o arquivo ser self-contained em qualquer aparelho.
  static Map<String, dynamic> paraJson(Ficha f) {
    final copia = Map<String, dynamic>.from(f.data);
    final id = f.retratoId;
    final b64 = id == null ? null : ImagemStore.base64De(id);
    copia.remove('retratoId');
    if (b64 != null) copia['retrato'] = b64;
    return copia;
  }

  /// Caminho inverso: extrai o retrato para o `ImagemStore` e resolve
  /// colisão de id com uma ficha já existente.
  static Future<Ficha> deJson(Map<String, dynamic> json) async {
    final data = Map<String, dynamic>.from(json);
    final b64 = data.remove('retrato');
    if (b64 is String && b64.isNotEmpty) {
      data['retratoId'] = await ImagemStore.salvarBase64(b64);
    }
    final id = data['id'];
    if (id is! String || id.isEmpty || FichaStore.porId(id) != null) {
      data['id'] = const Uuid().v4();
    }
    return Ficha(data);
  }
```

No `exportarJson`, trocar a linha que serializa:

```dart
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(paraJson(f))));
```

No `importarJson`, trocar o trecho final por:

```dart
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Arquivo não é uma ficha válida.');
    }
    return deJson(decoded);
```

E importar o store no topo: `import '../store/imagem_store.dart';`

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_io_test.dart`
Expected: PASS (3 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_io.dart test/ficha_io_test.dart
git commit -m "io: retrato embutido no JSON exportado"
```

---

### Task 4: Escolher o retrato e mostrar no app

**Files:**
- Create: `lib/widgets/retrato.dart`
- Modify: `lib/screens/home_screen.dart:199-206` (avatar do card)
- Modify: `lib/screens/ficha_view_screen.dart` (cabeçalho da aba Personagem, `_cardIdentidade` em `:216`)
- Modify: `lib/screens/wizard_screen.dart` (passo Identidade)
- Test: `test/retrato_test.dart` (criar)

**Interfaces:**
- Consumes: `ImagemStore.bytes`, `Ficha.retratoId`.
- Produces:
  - `RetratoAvatar({required String? retratoId, double tamanho})` — círculo com a imagem ou o ícone padrão
  - `escolherRetrato(BuildContext context)` → `Future<String?>` (abre o seletor, salva no store, devolve o id novo; `null` se cancelar)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/retrato_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/widgets/retrato.dart';

Uint8List _png() {
  final im = img.Image(width: 120, height: 120);
  img.fill(im, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('build/test-hive-retrato');
    await ImagemStore.init();
  });

  tearDown(() async => Hive.box<String>(ImagemStore.boxName).clear());

  testWidgets('sem retrato mostra o ícone padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: null, tamanho: 40)),
    ));
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('com retrato mostra a imagem', (tester) async {
    final id = await ImagemStore.salvar(_png());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: id, tamanho: 40)),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
  });

  testWidgets('id inexistente cai no ícone padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RetratoAvatar(retratoId: 'nao-existe', tamanho: 40)),
    ));
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/retrato_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mago_a_ascensao/widgets/retrato.dart'`.

- [ ] **Step 3: Implementar o widget e o seletor**

Criar `lib/widgets/retrato.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../store/imagem_store.dart';
import '../theme.dart';

/// Retrato circular da ficha. Sem imagem (ou com id que não existe mais),
/// cai no ícone padrão do app.
class RetratoAvatar extends StatelessWidget {
  final String? retratoId;
  final double tamanho;
  const RetratoAvatar({super.key, required this.retratoId, this.tamanho = 40});

  @override
  Widget build(BuildContext context) {
    final bytes = retratoId == null ? null : ImagemStore.bytes(retratoId!);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Cores.indigo,
        border: Border.all(color: Cores.dourado, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(Icons.auto_awesome,
              color: Cores.dourado, size: tamanho * 0.55)
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

/// Abre a galeria, guarda a imagem escolhida e devolve o id.
/// Devolve null se o usuário cancelar.
Future<String?> escolherRetrato(BuildContext context) async {
  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final bytes = res.files.single.bytes;
    if (bytes == null) throw Exception('Não foi possível ler a imagem.');
    return await ImagemStore.salvar(bytes);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao abrir a imagem: $e')));
    }
    return null;
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/retrato_test.dart`
Expected: PASS (3 testes)

- [ ] **Step 5: Usar o retrato no card da home**

Em `lib/screens/home_screen.dart`, trocar o `leading` do `ListTile` de `_CartaoFicha`:

```dart
        leading: RetratoAvatar(retratoId: ficha.retratoId, tamanho: 44),
```

e importar `../widgets/retrato.dart`.

- [ ] **Step 6: Botão de retrato no wizard**

No passo Identidade de `lib/screens/wizard_screen.dart`, antes dos campos de texto, acrescentar:

```dart
        Center(
          child: Column(
            children: [
              RetratoAvatar(retratoId: f.retratoId, tamanho: 96),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(f.temRetrato ? 'Trocar retrato' : 'Escolher retrato'),
                    onPressed: () async {
                      final id = await escolherRetrato(context);
                      if (id == null) return;
                      setState(() => f.retratoId = id);
                    },
                  ),
                  if (f.temRetrato)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                      onPressed: () => setState(() => f.retratoId = null),
                    ),
                ],
              ),
            ],
          ),
        ),
```

e importar `../widgets/retrato.dart`.

- [ ] **Step 7: Retrato no topo da ficha**

Em `lib/screens/ficha_view_screen.dart`, dentro de `_cardIdentidade`, colocar o retrato à esquerda do nome — envolver o conteúdo atual do `Card` numa `Row` com:

```dart
            RetratoAvatar(retratoId: ficha.retratoId, tamanho: 72),
            const SizedBox(width: 12),
            Expanded(child: /* conteúdo atual da coluna de identidade */),
```

e importar `../widgets/retrato.dart`.

- [ ] **Step 8: Conferir no app**

Run: `flutter run -d chrome`
Conferir: escolher uma imagem no passo Identidade, salvar, e ver o retrato no card da home e no topo da ficha.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/retrato.dart lib/screens/home_screen.dart lib/screens/wizard_screen.dart lib/screens/ficha_view_screen.dart test/retrato_test.dart
git commit -m "retrato: escolha na identidade e exibicao na lista e na ficha"
```

---

### Task 5: Retrato no anexo do PDF

**Files:**
- Modify: `lib/services/ficha_pdf.dart` (montagem do anexo, Fase 2 Task 4)
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `Ficha.retratoId`, `ImagemStore.bytes`, `anexoGerado`.
- Produces: nada novo.

- [ ] **Step 1: Escrever o teste que falha**

```dart
  test('ficha com retrato gera anexo mesmo sem texto excedente', () async {
    Hive.init('build/test-hive-pdf');
    await ImagemStore.init();
    final im = img.Image(width: 400, height: 400);
    img.fill(im, color: img.ColorRgb8(90, 30, 120));

    final f = Ficha.criar();
    f.data['nome'] = 'Retratado';
    f.retratoId = await ImagemStore.salvar(Uint8List.fromList(img.encodePng(im)));

    final bytes = await FichaPdf.gerar(f);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final out = File('build/ficha_test_retrato.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  });
```

Acrescentar os imports `package:hive_flutter/hive_flutter.dart`, `package:image/image.dart as img`, `dart:typed_data` e `package:mago_a_ascensao/store/imagem_store.dart` no arquivo de teste.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: FAIL — sem anexo, `build/ficha_test_retrato.pdf` sai com 2 páginas e nenhuma imagem. (O teste só garante que a geração não quebra; a conferência do retrato é visual no arquivo.)

- [ ] **Step 3: Implementar**

Na montagem do anexo em `gerar()`, a condição passa a considerar o retrato:

```dart
    final retrato = f.retratoId == null ? null : ImagemStore.bytes(f.retratoId!);
    if (anexoGerado.isNotEmpty || retrato != null) {
      final negrito = pw.Font.helveticaBold();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
        build: (ctx) => [
          pw.Text(
            'Anexo — ${f.nome.isEmpty ? 'ficha sem nome' : f.nome}',
            style: pw.TextStyle(font: negrito, fontSize: 15, color: _tinta),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Continuação dos campos que não couberam na ficha oficial.',
            style: pw.TextStyle(font: helv, fontSize: 9, color: _tinta),
          ),
          pw.Divider(color: _tinta, height: 16),
          if (retrato != null) ...[
            pw.Center(
              child: pw.Container(
                height: 180,
                child: pw.Image(pw.MemoryImage(retrato), fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          for (final item in anexoGerado) ...[
            pw.SizedBox(height: 8),
            pw.Text(item.titulo,
                style: pw.TextStyle(font: negrito, fontSize: 11, color: _tinta)),
            pw.SizedBox(height: 3),
            pw.Text(item.texto,
                style: pw.TextStyle(font: helv, fontSize: 9.5, color: _tinta),
                textAlign: pw.TextAlign.left),
          ],
        ],
      ));
    }
```

E importar `../store/imagem_store.dart` no topo de `ficha_pdf.dart`.

- [ ] **Step 4: Rodar e conferir**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS

Abrir `build/ficha_test_retrato.pdf`: 3 páginas, a terceira com o retrato.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: retrato do personagem na pagina de anexo"
```

---

### Task 6: Fechamento da fase

- [ ] **Step 1: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Analisar**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Conferir peso da box**

Run: `flutter run -d chrome`, adicionar retrato em 3 fichas, exportar uma em JSON e conferir que o arquivo tem menos de 400 KB (retrato 1024px q80).

- [ ] **Step 4: Commit final**

```bash
git add -A
git commit -m "fase 3: retrato do personagem concluido"
```
