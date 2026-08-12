# Fase 4 — Backup em massa (.zip) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exportar todas as fichas de uma vez num `.zip` e importar de volta, com resumo e escolha do que fazer quando a ficha já existe no aparelho.

**Architecture:** Um serviço novo (`lib/services/backup_io.dart`) monta e lê o zip; cada ficha vira um arquivo em `fichas/` no mesmo formato do export individual (self-contained, com o retrato embutido), então dá para pescar uma ficha sozinha do zip. Um `manifest.json` identifica o formato e alimenta o resumo mostrado antes de gravar. A leitura é separada da gravação (`lerZip` devolve um resumo; `aplicar` grava) — é isso que torna o fluxo testável e permite pedir confirmação ao usuário no meio.

**Tech Stack:** Flutter, pacote `archive`, `share_plus` e `file_picker` (já são dependências), Hive, `flutter_test`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`.
- Código, comentários e textos em português do Brasil.
- Depende das Fases 1–3 (usa `FichaIO.paraJson` / `FichaIO.deJson`).
- O zip desta fase leva `manifest.json` e `fichas/`. A pasta `narrador/` entra na Fase 5 — a leitura já ignora pasta desconhecida, então um zip da Fase 5 continua importável aqui e vice-versa.
- Import nunca grava sem confirmação do usuário.
- Zip sem `manifest.json`, ou com `versao` maior que a suportada, é recusado com mensagem clara — não tenta adivinhar.
- Testes de store usam `Hive.init('build/test-hive-<nome>')`.
- Rodar `flutter analyze` antes de cada commit; zero warning novo.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: Montar o zip

**Files:**
- Create: `lib/services/backup_io.dart`
- Modify: `pubspec.yaml` (dependência `archive`)
- Modify: `lib/services/ficha_io.dart` (extrair o nome de arquivo)
- Test: `test/backup_io_test.dart` (criar)

**Interfaces:**
- Consumes: `FichaIO.paraJson`, `FichaStore.todas()`.
- Produces:
  - `FichaIO.nomeArquivo(Ficha f)` → `String` (slug sem extensão)
  - `BackupIO.versao` → `int` (`1`)
  - `BackupIO.montarZip(List<Ficha> fichas)` → `Uint8List`

- [ ] **Step 1: Acrescentar a dependência**

Run: `flutter pub add archive`
Expected: `pubspec.yaml` ganha `archive: ^<versão>`.

- [ ] **Step 2: Escrever o teste que falha**

Criar `test/backup_io_test.dart`:

```dart
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/services/backup_io.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:mago_a_ascensao/store/imagem_store.dart';

Ficha _ficha(String nome) {
  final f = Ficha.criar();
  f.data['nome'] = nome;
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-backup');
    await Hive.openBox<String>(FichaStore.boxName);
    await ImagemStore.init();
  });

  tearDown(() async {
    await Hive.box<String>(FichaStore.boxName).clear();
    await Hive.box<String>(ImagemStore.boxName).clear();
  });

  test('zip tem manifesto e uma entrada por ficha', () {
    final fichas = [_ficha('Cassandra Vex'), _ficha('João da Silva')];
    final bytes = BackupIO.montarZip(fichas);

    final zip = ZipDecoder().decodeBytes(bytes);
    final nomes = zip.files.map((f) => f.name).toList();

    expect(nomes, contains('manifest.json'));
    expect(nomes.where((n) => n.startsWith('fichas/')).length, 2);
    expect(nomes.any((n) => n.contains('Cassandra-Vex')), isTrue);

    final man = jsonDecode(utf8.decode(
        zip.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>));
    expect(man['versao'], BackupIO.versao);
    expect(man['app'], 'mago-a-ascensao');
    expect(man['fichas'], 2);
  });

  test('cada arquivo de ficha é um JSON importável sozinho', () {
    final bytes = BackupIO.montarZip([_ficha('Solitária')]);
    final zip = ZipDecoder().decodeBytes(bytes);
    final arq = zip.files.firstWhere((f) => f.name.startsWith('fichas/'));
    final json = jsonDecode(utf8.decode(arq.content as List<int>));
    expect(json['nome'], 'Solitária');
    expect(json['id'], isA<String>());
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/backup_io_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mago_a_ascensao/services/backup_io.dart'`.

- [ ] **Step 4: Extrair o nome de arquivo do `FichaIO`**

Em `lib/services/ficha_io.dart`, trocar o trecho inicial de `exportarJson` por uma chamada ao método novo:

```dart
  /// Nome de arquivo (sem extensão) a partir do nome do personagem.
  static String nomeArquivo(Ficha f) => f.nome.trim().isEmpty
      ? 'ficha-mago'
      : f.nome
          .trim()
          .replaceAll(RegExp(r'[^\w\- À-ÿ]'), '')
          .replaceAll(RegExp(r'\s+'), '-');

  static Future<void> exportarJson(Ficha f) async {
    final nome = nomeArquivo(f);
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(paraJson(f))));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: '$nome.json', mimeType: 'application/json')],
      subject: 'Ficha ${f.nome.isEmpty ? 'de Mago' : f.nome}',
      fileNameOverrides: ['$nome.json'],
    );
  }
```

- [ ] **Step 5: Implementar `montarZip`**

Criar `lib/services/backup_io.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/ficha.dart';
import 'ficha_io.dart';

/// Backup de tudo em um `.zip`. Cada ficha vira um arquivo dentro de
/// `fichas/`, no mesmo formato do export individual — dá para tirar uma
/// ficha só do zip e importar sozinha.
class BackupIO {
  /// Formato do backup. Sobe quando a estrutura do zip mudar de um jeito
  /// que uma versão antiga do app não consiga ler.
  static const int versao = 1;
  static const String app = 'mago-a-ascensao';

  static Uint8List montarZip(List<Ficha> fichas) {
    final arquivo = Archive();
    final json = const JsonEncoder.withIndent('  ');

    void add(String caminho, String conteudo) {
      final dados = utf8.encode(conteudo);
      arquivo.addFile(ArchiveFile(caminho, dados.length, dados));
    }

    final usados = <String>{};
    for (final f in fichas) {
      var nome = FichaIO.nomeArquivo(f);
      // dois personagens com o mesmo nome não podem virar o mesmo arquivo
      if (!usados.add(nome)) {
        nome = '$nome-${f.id.substring(0, 8)}';
        usados.add(nome);
      }
      add('fichas/$nome.json', json.convert(FichaIO.paraJson(f)));
    }

    add(
      'manifest.json',
      json.convert({
        'versao': versao,
        'app': app,
        'fichas': fichas.length,
      }),
    );

    return Uint8List.fromList(ZipEncoder().encode(arquivo)!);
  }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/backup_io_test.dart`
Expected: PASS (2 testes)

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/backup_io.dart lib/services/ficha_io.dart test/backup_io_test.dart
git commit -m "backup: monta zip com manifesto e uma ficha por arquivo"
```

---

### Task 2: Ler o zip e aplicar

**Files:**
- Modify: `lib/services/backup_io.dart`
- Test: `test/backup_io_test.dart`

**Interfaces:**
- Consumes: `FichaIO.deJson`, `FichaStore.porId`, `FichaStore.salvar`.
- Produces:
  - `enum PoliticaColisao { duplicar, substituir, pular }`
  - `class ResumoBackup { int versao; List<Map<String, dynamic>> fichas; List<String> colidem; int get total; }`
  - `BackupIO.lerZip(Uint8List bytes)` → `ResumoBackup` (lança `Exception` com mensagem em português se o formato não bater)
  - `BackupIO.aplicar(ResumoBackup r, PoliticaColisao politica)` → `Future<int>` (quantas fichas gravou)

- [ ] **Step 1: Escrever os testes que falham**

```dart
  test('leitura devolve resumo com as fichas e as colisões', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);

    final bytes = BackupIO.montarZip([existente, _ficha('Nova')]);
    final resumo = BackupIO.lerZip(bytes);

    expect(resumo.versao, BackupIO.versao);
    expect(resumo.total, 2);
    expect(resumo.colidem, ['Repetida']);
  });

  test('aplicar duplicar mantém a existente e grava uma cópia', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    final resumo = BackupIO.lerZip(BackupIO.montarZip([existente]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.duplicar);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 2);
    expect(FichaStore.porId(existente.id), isNotNull);
  });

  test('aplicar substituir sobrescreve a existente', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    existente.data['nome'] = 'Repetida (editada no backup)';
    final resumo = BackupIO.lerZip(BackupIO.montarZip([existente]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.substituir);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 1);
    expect(FichaStore.porId(existente.id)!.nome, 'Repetida (editada no backup)');
  });

  test('aplicar pular ignora a colidente', () async {
    final existente = _ficha('Repetida');
    await FichaStore.salvar(existente);
    final resumo = BackupIO.lerZip(BackupIO.montarZip([existente, _ficha('Nova')]));

    final gravadas = await BackupIO.aplicar(resumo, PoliticaColisao.pular);

    expect(gravadas, 1);
    expect(FichaStore.todas().length, 2);
  });

  test('roundtrip: exporta, limpa e importa de volta', () async {
    for (final n in ['Um', 'Dois', 'Três']) {
      await FichaStore.salvar(_ficha(n));
    }
    final bytes = BackupIO.montarZip(FichaStore.todas());
    await Hive.box<String>(FichaStore.boxName).clear();

    await BackupIO.aplicar(BackupIO.lerZip(bytes), PoliticaColisao.duplicar);

    final nomes = FichaStore.todas().map((f) => f.nome).toList()..sort();
    expect(nomes, ['Dois', 'Três', 'Um']);
  });

  test('zip sem manifesto é recusado', () {
    final vazio = Archive();
    final bytes = ZipEncoder().encode(vazio)!;
    expect(() => BackupIO.lerZip(Uint8List.fromList(bytes)),
        throwsA(isA<Exception>()));
  });

  test('versão futura é recusada', () {
    final arquivo = Archive();
    final man = utf8.encode('{"versao": 99, "app": "mago-a-ascensao"}');
    arquivo.addFile(ArchiveFile('manifest.json', man.length, man));
    final bytes = ZipEncoder().encode(arquivo)!;
    expect(() => BackupIO.lerZip(Uint8List.fromList(bytes)),
        throwsA(isA<Exception>()));
  });
```

Acrescentar `import 'dart:typed_data';` no topo do arquivo de teste.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/backup_io_test.dart`
Expected: FAIL — `Undefined name 'PoliticaColisao'` e `lerZip` não definido.

- [ ] **Step 3: Implementar**

Acrescentar em `lib/services/backup_io.dart`:

```dart
import '../store/ficha_store.dart';

/// O que fazer quando a ficha do backup já existe no aparelho.
enum PoliticaColisao { duplicar, substituir, pular }

/// O que veio no zip, antes de qualquer gravação.
class ResumoBackup {
  final int versao;
  final List<Map<String, dynamic>> fichas;

  /// Nomes das fichas cujo id já existe neste aparelho.
  final List<String> colidem;

  const ResumoBackup(this.versao, this.fichas, this.colidem);

  int get total => fichas.length;
}
```

e, dentro da classe `BackupIO`:

```dart
  /// Lê o zip sem gravar nada. Lança `Exception` com mensagem em português
  /// quando o arquivo não é um backup do app.
  static ResumoBackup lerZip(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw Exception('Arquivo não é um .zip válido.');
    }

    final man = zip.files.where((f) => f.name == 'manifest.json').toList();
    if (man.isEmpty) {
      throw Exception('Zip sem manifest.json — não é um backup do app.');
    }
    final dados =
        jsonDecode(utf8.decode(man.first.content as List<int>)) as Map;
    final v = (dados['versao'] as num?)?.toInt() ?? 0;
    if (dados['app'] != app) {
      throw Exception('Backup de outro aplicativo.');
    }
    if (v > versao) {
      throw Exception(
          'Backup na versão $v; este app lê até a $versao. Atualize o app.');
    }

    final fichas = <Map<String, dynamic>>[];
    for (final arq in zip.files) {
      if (!arq.name.startsWith('fichas/') || !arq.name.endsWith('.json')) {
        continue;
      }
      final j = jsonDecode(utf8.decode(arq.content as List<int>));
      if (j is Map<String, dynamic>) fichas.add(j);
    }

    final colidem = <String>[
      for (final j in fichas)
        if (j['id'] is String && FichaStore.porId(j['id'] as String) != null)
          '${j['nome'] ?? 'Sem nome'}',
    ];

    return ResumoBackup(v, fichas, colidem);
  }

  /// Grava as fichas do resumo. Devolve quantas foram gravadas.
  static Future<int> aplicar(ResumoBackup r, PoliticaColisao politica) async {
    var gravadas = 0;
    for (final j in r.fichas) {
      final id = j['id'];
      final existe = id is String && FichaStore.porId(id) != null;

      if (existe && politica == PoliticaColisao.pular) continue;

      if (existe && politica == PoliticaColisao.substituir) {
        // `deJson` trocaria o id para não sobrescrever; aqui a intenção é
        // justamente sobrescrever, então o id do backup é preservado.
        final copia = Map<String, dynamic>.from(j);
        final ficha = await FichaIO.deJson(copia);
        ficha.data['id'] = id;
        await FichaStore.salvar(ficha);
        gravadas++;
        continue;
      }

      // não existe, ou existe e a política é duplicar: `deJson` resolve o id
      await FichaStore.salvar(await FichaIO.deJson(Map<String, dynamic>.from(j)));
      gravadas++;
    }
    return gravadas;
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/backup_io_test.dart`
Expected: PASS (9 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/services/backup_io.dart test/backup_io_test.dart
git commit -m "backup: leitura do zip com resumo e politicas de colisao"
```

---

### Task 3: Exportar e importar pela home

**Files:**
- Modify: `lib/services/backup_io.dart` (compartilhar e escolher arquivo)
- Modify: `lib/screens/home_screen.dart:25-56` (importar/exportar), `:63-83` (menu)
- Test: conferência manual (o seletor de arquivo e o compartilhamento são do sistema)

**Interfaces:**
- Consumes: `montarZip`, `lerZip`, `aplicar`, `FichaStore.todas`.
- Produces:
  - `BackupIO.exportarTudo()` → `Future<void>` (compartilha o zip)
  - `BackupIO.escolherArquivo()` → `Future<(String nome, Uint8List bytes)?>` (aceita `.json` e `.zip`)

- [ ] **Step 1: Implementar o compartilhamento e a escolha**

Acrescentar em `lib/services/backup_io.dart` (imports `package:file_picker/file_picker.dart` e `package:share_plus/share_plus.dart`):

```dart
  /// Compartilha o backup de todas as fichas.
  static Future<void> exportarTudo() async {
    final fichas = FichaStore.todas();
    if (fichas.isEmpty) throw Exception('Não há fichas para exportar.');
    final bytes = montarZip(fichas);
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final nome = 'magos-backup-$hoje.zip';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: nome, mimeType: 'application/zip')],
      subject: 'Backup das fichas de Mago',
      fileNameOverrides: [nome],
    );
  }

  /// Abre o seletor aceitando ficha única (.json) ou backup (.zip).
  static Future<(String, Uint8List)?> escolherArquivo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final arq = res.files.single;
    final bytes = arq.bytes;
    if (bytes == null) throw Exception('Não foi possível ler o arquivo.');
    return (arq.name, bytes);
  }
```

- [ ] **Step 2: Ligar na home**

Em `lib/screens/home_screen.dart`, substituir `_importar` e acrescentar `_exportarTudo`:

```dart
  Future<void> _importar(BuildContext context) async {
    try {
      final escolhido = await BackupIO.escolherArquivo();
      if (escolhido == null) return;
      final (nome, bytes) = escolhido;

      if (!nome.toLowerCase().endsWith('.zip')) {
        final f = await FichaIO.deJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        await FichaStore.salvar(f);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Ficha "${f.nome.isEmpty ? 'Sem nome' : f.nome}" importada.')));
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FichaViewScreen(fichaId: f.id)),
        );
        return;
      }

      final resumo = BackupIO.lerZip(bytes);
      if (!context.mounted) return;
      final politica = await _confirmarBackup(context, resumo);
      if (politica == null) return;
      final n = await BackupIO.aplicar(resumo, politica);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n ficha(s) importada(s).')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao importar: $e')),
      );
    }
  }

  /// Mostra o que vem no backup e pergunta o que fazer com as repetidas.
  Future<PoliticaColisao?> _confirmarBackup(
      BuildContext context, ResumoBackup r) {
    return showDialog<PoliticaColisao>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Importar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.total} ficha(s) no arquivo.'),
            if (r.colidem.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${r.colidem.length} já existem neste aparelho:'),
              Text(r.colidem.join(', '),
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              const Text('O que fazer com elas?'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          if (r.colidem.isNotEmpty) ...[
            TextButton(
                onPressed: () => Navigator.pop(ctx, PoliticaColisao.pular),
                child: const Text('Pular')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, PoliticaColisao.substituir),
                child: const Text('Substituir')),
          ],
          TextButton(
              onPressed: () => Navigator.pop(ctx, PoliticaColisao.duplicar),
              child: Text(r.colidem.isEmpty ? 'Importar' : 'Duplicar')),
        ],
      ),
    );
  }

  Future<void> _exportarTudo(BuildContext context) async {
    try {
      await BackupIO.exportarTudo();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar: $e')),
      );
    }
  }
```

No menu ⋮ do `AppBar`, acrescentar a opção nova:

```dart
            onSelected: (v) {
              if (v == 'importar') _importar(context);
              if (v == 'exportar') _exportarTudo(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'importar',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: Cores.indigo),
                    SizedBox(width: 8),
                    Text('Importar (JSON ou ZIP)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'exportar',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Cores.indigo),
                    SizedBox(width: 8),
                    Text('Exportar tudo (.zip)'),
                  ],
                ),
              ),
            ],
```

Imports novos no arquivo: `dart:convert`, `../services/backup_io.dart`.

- [ ] **Step 3: Conferir no app**

Run: `flutter run -d chrome`
Conferir, nesta ordem:
1. Criar 2 fichas, exportar tudo → baixa `magos-backup-<data>.zip`.
2. Importar o mesmo zip → o diálogo mostra "2 ficha(s)" e "2 já existem".
3. Escolher **Duplicar** → passa a ter 4 fichas.
4. Importar de novo escolhendo **Pular** → continua com 4.
5. Abrir o zip fora do app e importar só um `fichas/*.json` → entra como ficha única.

- [ ] **Step 4: Analisar e commitar**

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add lib/services/backup_io.dart lib/screens/home_screen.dart
git commit -m "home: exportar tudo em zip e importar com confirmacao"
```

---

### Task 4: Fechamento da fase

- [ ] **Step 1: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Conferir backup com retrato**

Run: `flutter run -d chrome`; ficha com retrato → exportar tudo → limpar dados do navegador → importar o zip → o retrato volta.

- [ ] **Step 3: Commit final**

```bash
git add -A
git commit -m "fase 4: backup em massa concluido"
```
