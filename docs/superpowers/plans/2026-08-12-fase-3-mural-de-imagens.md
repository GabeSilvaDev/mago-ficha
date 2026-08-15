# Mesa online · Fase 3 — Mural de imagens — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) ou superpowers:executing-plans para implementar task a task. Steps usam checkbox (`- [ ]`).

**Goal:** O mestre escolhe uma imagem e ela abre no celular de todo mundo na mesa, em tela cheia.

**Architecture:** A imagem vai no próprio documento do Firestore, em base64 — sem Firebase Storage. O app já reduz imagens para 1024px JPEG q80 no `ImagemStore`; uma etapa de garantia encolhe mais se o base64 passar de 700 KB, para caber com folga no limite de 1 MiB por documento. Todo aparelho na mesa escuta `mural/atual` e abre o `VisualizadorImagens` que já existe.

**Tech Stack:** Flutter 3.44, `cloud_firestore`, pacote `image`, `flutter_test`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`, branch `mesa-online`.
- Flutter roda por Docker: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter <cmd>"`.
- Depende das Fases 1 e 2 concluídas.
- Código, comentários e textos de UI em português do Brasil.
- **Só o mestre escreve no mural.** Jogador só lê.
- Nenhum documento do Firestore pode passar de 1 MiB — daí o teto de 700 KB em base64.
- Gravação no Hive nunca dentro de `testWidgets`.
- `flutter analyze` limpo antes de cada commit. Não rodar `dart format`.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: Preparar a imagem para caber no documento

**Files:**
- Create: `lib/mesa/imagem_mural.dart`
- Create: `test/mesa/imagem_mural_test.dart`

**Interfaces:**
- Consumes: pacote `image`, `ImagemStore.reduzir`.
- Produces:
  - `ImagemMural.tetoBase64` → `int` (700 * 1024)
  - `ImagemMural.preparar(Uint8List original)` → `String` (base64 de JPEG que cabe)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/imagem_mural_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/mesa/imagem_mural.dart';

/// Imagem com ruído: cor sólida comprime demais e não testa nada.
Uint8List _ruido(int largura, int altura) {
  final im = img.Image(width: largura, height: altura);
  for (var y = 0; y < altura; y++) {
    for (var x = 0; x < largura; x++) {
      im.setPixelRgb(x, y, (x * 7 + y * 13) % 256, (x * 3) % 256,
          (y * 11) % 256);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imagem normal passa e continua legível', () {
    final b64 = ImagemMural.preparar(_ruido(800, 600));
    final bytes = base64Decode(b64);
    expect(bytes[0], 0xFF); // JPEG
    expect(bytes[1], 0xD8);
    expect(b64.length, lessThan(ImagemMural.tetoBase64));
    final decodificada = img.decodeImage(bytes)!;
    expect(decodificada.width, greaterThan(200));
  });

  test('imagem enorme é encolhida até caber', () {
    final b64 = ImagemMural.preparar(_ruido(4000, 3000));
    expect(b64.length, lessThan(ImagemMural.tetoBase64));
    final decodificada = img.decodeImage(base64Decode(b64))!;
    expect(decodificada.width, lessThanOrEqualTo(1024));
  });

  test('teto tem folga real dentro do limite de 1 MiB do Firestore', () {
    expect(ImagemMural.tetoBase64, lessThan(1024 * 1024));
  });

  test('bytes que não são imagem falham com mensagem clara', () {
    expect(() => ImagemMural.preparar(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/imagem_mural_test.dart"`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/imagem_mural.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deixa a imagem no tamanho que cabe dentro de um documento do Firestore.
///
/// O mural não usa Firebase Storage: uma foto de 1024px em JPEG q80 dá
/// 150–250 KB, que em base64 vira 200–330 KB — bem dentro do limite de 1 MiB
/// por documento. Só o caso extremo precisa encolher mais, e é o que esta
/// classe garante.
class ImagemMural {
  /// Teto do base64. Deixa folga para o resto do documento (legenda, uid,
  /// data) e para o overhead do próprio Firestore.
  static const int tetoBase64 = 700 * 1024;

  static const List<int> _larguras = [1024, 800, 640];
  static const List<int> _qualidades = [80, 70, 60];

  static String preparar(Uint8List original) {
    final imagem = img.decodeImage(original);
    if (imagem == null) {
      throw Exception('Não foi possível ler a imagem.');
    }

    for (final largura in _larguras) {
      final ajustada = imagem.width > largura
          ? img.copyResize(imagem,
              width: largura, interpolation: img.Interpolation.average)
          : imagem;
      for (final q in _qualidades) {
        final b64 = base64Encode(img.encodeJpg(ajustada, quality: q));
        if (b64.length <= tetoBase64) return b64;
      }
    }

    // Último recurso: bem pequena, mas o mural nunca falha por tamanho.
    final mini = img.copyResize(imagem, width: 480);
    return base64Encode(img.encodeJpg(mini, quality: 55));
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/imagem_mural_test.dart"`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/imagem_mural.dart test/mesa/imagem_mural_test.dart
git commit -m "mesa: prepara imagem do mural para caber no documento"
```

---

### Task 2: O serviço aprende o mural

**Files:**
- Modify: `lib/mesa/mesa_service.dart`
- Modify: `lib/mesa/mesa_fake.dart`
- Modify: `lib/mesa/mesa_firestore.dart`
- Modify: `test/mesa/mesa_fake_test.dart`

**Interfaces:**
- Produces, em `MesaService`:
  - `Future<void> mostrarNoMural(String mesaId, String imagemBase64, String legenda)`
  - `Future<void> limparMural(String mesaId)`
  - `Stream<ItemMural?> observarMural(String mesaId)`
  - `class ItemMural { String imagemBase64, legenda, porUid; DateTime em; }`

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar em `test/mesa/mesa_fake_test.dart`:

```dart
  test('mestre mostra no mural e todos veem', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    await mestre.mostrarNoMural(mesa.id, 'AAAA', 'mapa da estação');

    final visto = await kaue.observarMural(mesa.id).first;
    expect(visto!.imagemBase64, 'AAAA');
    expect(visto.legenda, 'mapa da estação');
    expect(visto.porUid, 'u-mestre');
  });

  test('jogador não escreve no mural', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    final kaue = MesaFake('u-kaue', mundo: mestre.mundo);
    await kaue.entrarAnonimo();
    await kaue.entrarPorCodigo(mesa.codigo, 'Kaue');

    expect(() => kaue.mostrarNoMural(mesa.id, 'AAAA', 'tentativa'),
        throwsA(isA<SemPermissao>()));
    expect(() => kaue.limparMural(mesa.id), throwsA(isA<SemPermissao>()));
  });

  test('limpar mural: volta a ser null', () async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');
    await mestre.mostrarNoMural(mesa.id, 'AAAA', '');

    await mestre.limparMural(mesa.id);

    expect(await mestre.observarMural(mesa.id).first, isNull);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: FAIL — `mostrarNoMural` não definido.

- [ ] **Step 3: Implementar**

Em `lib/mesa/mesa_service.dart`:

```dart
/// O que está no mural da mesa agora.
class ItemMural {
  final String imagemBase64;
  final String legenda;
  final String porUid;
  final DateTime em;

  const ItemMural({
    required this.imagemBase64,
    required this.legenda,
    required this.porUid,
    required this.em,
  });

  factory ItemMural.fromJson(Map<String, dynamic> j) => ItemMural(
        imagemBase64: (j['imagem'] ?? '') as String,
        legenda: (j['legenda'] ?? '') as String,
        porUid: (j['porUid'] ?? '') as String,
        em: DateTime.parse(j['em'] as String),
      );

  Map<String, dynamic> toJson() => {
        'imagem': imagemBase64,
        'legenda': legenda,
        'porUid': porUid,
        'em': em.toIso8601String(),
      };
}
```

e na interface:

```dart
  /// Só o mestre. Põe a imagem no mural da mesa.
  Future<void> mostrarNoMural(
      String mesaId, String imagemBase64, String legenda);

  /// Só o mestre. Tira o que estiver no mural.
  Future<void> limparMural(String mesaId);

  /// Null quando não há nada no mural.
  Stream<ItemMural?> observarMural(String mesaId);
```

No `MesaFake`, guardar em `mundo.mural[mesaId]`, exigindo `_exigeMestre(mesaId)`
em `mostrarNoMural` e `limparMural`, e emitindo pelo mesmo `notificar`.

No `MesaFirestore`:

```dart
  DocumentReference<Map<String, dynamic>> _mural(String mesaId) =>
      _mesa(mesaId).collection('mural').doc('atual');

  @override
  Future<void> mostrarNoMural(
      String mesaId, String imagemBase64, String legenda) async {
    try {
      await _mural(mesaId).set(ItemMural(
        imagemBase64: imagemBase64,
        legenda: legenda,
        porUid: uid ?? '',
        em: DateTime.now(),
      ).toJson());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> limparMural(String mesaId) async {
    try {
      await _mural(mesaId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Stream<ItemMural?> observarMural(String mesaId) => _mural(mesaId)
      .snapshots()
      .map((d) => d.exists ? ItemMural.fromJson(d.data()!) : null);
```

E em `fecharMesa`, apagar `mural/atual` junto dos membros — subcoleção não some
sozinha.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mesa_fake_test.dart"`
Expected: PASS (18 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/ test/mesa/mesa_fake_test.dart
git commit -m "mesa: mural de imagens no servico"
```

---

### Task 3: O mestre põe imagem no mural

**Files:**
- Modify: `lib/mesa/telas/painel_mestre.dart`
- Create: `test/mesa/mural_mestre_test.dart`

**Interfaces:**
- Consumes: `ImagemMural.preparar`, `escolherRetrato` (o seletor de imagem que já existe em `lib/widgets/retrato.dart`), `ImagemStore.bytes`, `MesaService.mostrarNoMural`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/mural_mestre_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/telas/painel_mestre.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';
import 'package:mago_a_ascensao/store/narrador_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MesaFake mestre;
  late String mesaId;

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-mural');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
    await NarradorStore.init();
  });

  setUp(() async {
    mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    mesaId = (await mestre.criarMesa('Sombras', 'Gabriel')).id;
  });

  testWidgets('mural vazio oferece mostrar imagem', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Mostrar imagem para a mesa'), findsOneWidget);
  });

  testWidgets('com imagem no mural, oferece tirar', (t) async {
    await mestre.mostrarNoMural(mesaId, 'AAAA', 'mapa da estação');

    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PainelMestre(servico: mestre, mesaId: mesaId))));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.text('mapa da estação'), findsOneWidget);
    expect(find.text('Tirar do mural'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mural_mestre_test.dart"`
Expected: FAIL — não existe "Mostrar imagem para a mesa".

- [ ] **Step 3: Implementar**

No `PainelMestre`, acrescentar uma seção **Mural** acima da lista de fichas,
com `StreamBuilder` sobre `servico.observarMural(mesaId)`:

- vazio → `TextButton.icon(Icons.image_outlined, 'Mostrar imagem para a mesa')`,
  que chama `escolherRetrato(context)` (devolve o id no `ImagemStore`), lê os
  bytes com `ImagemStore.bytes(id)`, passa por `ImagemMural.preparar`, pergunta
  a legenda num `AlertDialog` (pode ficar vazia) e chama `mostrarNoMural`.
- com item → miniatura (`Image.memory(base64Decode(item.imagemBase64), height: 90)`),
  a legenda, e `TextButton('Tirar do mural')` chamando `limparMural`.

Enquanto prepara e envia, mostrar um `CircularProgressIndicator` no lugar do
botão: uma foto grande leva alguns segundos entre reduzir e subir, e sem retorno
visual o mestre toca duas vezes.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/mural_mestre_test.dart"`
Expected: PASS (2 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/telas/painel_mestre.dart test/mesa/mural_mestre_test.dart
git commit -m "mesa: mestre poe e tira imagem do mural"
```

---

### Task 4: A imagem abre sozinha no celular de todos

**Files:**
- Create: `lib/mesa/ouvinte_mural.dart`
- Modify: `lib/screens/home_screen.dart`
- Create: `test/mesa/ouvinte_mural_test.dart`

**Interfaces:**
- Consumes: `MesaService.observarMural`, `MesaStore.atual`, `VisualizadorImagens`.
- Produces: `OuvinteMural({required MesaService servico, required String mesaId, required Widget child})` — envolve a home e abre a imagem quando o mural muda.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/mesa/ouvinte_mural_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/mesa/mesa_fake.dart';
import 'package:mago_a_ascensao/mesa/ouvinte_mural.dart';
import 'package:mago_a_ascensao/screens/narrador/visualizador_imagens.dart';

String _imagemBase64() {
  final im = img.Image(width: 60, height: 40);
  img.fill(im, color: img.ColorRgb8(10, 20, 30));
  return base64Encode(Uint8List.fromList(img.encodeJpg(im)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('imagem nova no mural abre em tela cheia', (t) async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    await t.pumpWidget(MaterialApp(
      home: OuvinteMural(
        servico: mestre,
        mesaId: mesa.id,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await t.pump();
    expect(find.byType(VisualizadorImagens), findsNothing);

    await mestre.mostrarNoMural(mesa.id, _imagemBase64(), 'mapa');
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsOneWidget);
  });

  testWidgets('mural limpo não reabre nada', (t) async {
    final mestre = MesaFake('u-mestre');
    await mestre.entrarAnonimo();
    final mesa = await mestre.criarMesa('Sombras', 'Gabriel');

    await t.pumpWidget(MaterialApp(
      home: OuvinteMural(
        servico: mestre,
        mesaId: mesa.id,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await t.pump();
    await mestre.limparMural(mesa.id);
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    expect(find.byType(VisualizadorImagens), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ouvinte_mural_test.dart"`
Expected: FAIL — `ouvinte_mural.dart` não existe.

- [ ] **Step 3: Implementar**

Criar `lib/mesa/ouvinte_mural.dart`: `StatefulWidget` que assina
`servico.observarMural(mesaId)` no `initState` e, a cada item **novo** (comparar
o `em` com o último visto — sem isso a tela reabre a cada rebuild), empurra:

```dart
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisualizadorImagens(
          imagens: const ['mural'],
          bytesDiretos: {'mural': base64Decode(item.imagemBase64)},
          legendas: {'mural': item.legenda},
        ),
      ));
```

`VisualizadorImagens` hoje só lê do `ImagemStore`. Acrescente o parâmetro
opcional `Map<String, Uint8List>? bytesDiretos` e, no `itemBuilder`, prefira
`bytesDiretos?[id]` antes de `ImagemStore.bytes(id)` — assim a imagem da mesa
não precisa ser gravada no aparelho de quem só vai olhar.

Cancelar a assinatura no `dispose`. Não abrir se o app não estiver em primeiro
plano é refinamento — fica de fora.

Em `lib/screens/home_screen.dart`, envolver o `Scaffold` com o `OuvinteMural`
**apenas quando `MesaStore.atual != null`**, usando o `mesaId` de lá. Fora de
mesa, nada é assinado.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test test/mesa/ouvinte_mural_test.dart && flutter test test/caderno_ui_test.dart"`
Expected: PASS nos dois — o segundo garante que o visualizador dos cadernos não
regrediu com o parâmetro novo.

- [ ] **Step 5: Commit**

```bash
git add lib/mesa/ouvinte_mural.dart lib/screens/narrador/visualizador_imagens.dart lib/screens/home_screen.dart test/mesa/ouvinte_mural_test.dart
git commit -m "mesa: imagem do mural abre sozinha no celular de todos"
```

---

### Task 5: Fechamento da fase

- [ ] **Step 1: Suíte e analyze**

Run: `docker exec mago-ascensao-flutter sh -c "cd /app && flutter test && flutter analyze"`
Expected: tudo verde, `No issues found!`.

- [ ] **Step 2: Acrescentar ao roteiro manual**

Em `docs/mesa-verificacao-manual.md`:

13. **Mural** — A põe uma foto; em segundos ela abre em tela cheia no aparelho de B.
14. **Modo mostrar** — no aparelho de B, o modo mostrar continua funcionando na imagem da mesa.
15. **Foto grande** — A escolhe uma foto direto da câmera (vários MB); o app reduz e envia sem erro.
16. **Tirar do mural** — A tira; B fecha a tela e não reabre sozinha.
17. **Permissão** — no simulador de regras do console, B tentando `set` em `mesas/{id}/mural/atual` → **negado**.

- [ ] **Step 3: Beta no aparelho e roteiro**

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta"
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb \
  -v /home/gabriel/Documentos/rpg/fichas/MagoAAssencao:/app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "adb install -r /app/build/app/outputs/flutter-apk/app-beta-release.apk"
```

Rodar os itens 13 a 17 com dois aparelhos.

- [ ] **Step 4: Atualizar o README**

Acrescentar a seção "Mesa online" descrevendo: entrar por código, publicar
ficha, o mestre acompanha ao vivo sem editar, mural de imagens, e que tudo isso
é opcional — sem mesa o app segue offline.

- [ ] **Step 5: Commit final**

```bash
git add -A
git commit -m "fase 3: mural de imagens concluido"
```
