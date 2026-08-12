# Fase 2 — Anexo do PDF — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nada mais se perde na exportação: texto e listas que não cabem na ficha oficial saem em páginas de anexo depois da página 2, e o lugar do corte fica marcado.

**Architecture:** `paragrafo()` para de descartar o texto que sobra e passa a avisar quem chamou; cada bloco cortado é registrado numa lista estática `FichaPdf.anexoGerado` (mesmo padrão do `_sobrasPg2` que já existe no arquivo). No fim de `gerar()`, se a lista não estiver vazia, um `pw.MultiPage` acrescenta as páginas de anexo. A lista pública também é o gancho de teste.

**Tech Stack:** Flutter, Dart, pacote `pdf` (`pw.MultiPage`, `pw.Font.helvetica`/`helveticaBold`), `flutter_test`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao`.
- Código, comentários e textos em português do Brasil.
- As duas páginas oficiais (`assets/ficha/pg-1.png`, `pg-2.png`) continuam idênticas — o anexo só acrescenta páginas no fim.
- Ficha pequena continua gerando exatamente 2 páginas: anexo só existe se houver excedente.
- Depende da Fase 1 (o parâmetro `fonte` de `fileira` já existe).
- Rodar `flutter analyze` antes de cada commit; zero warning novo.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: `paragrafo()` avisa quando corta

**Files:**
- Modify: `lib/services/ficha_pdf.dart:117-128` (`paragrafo`) e as chamadas em `:345-353`
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `quebra()`, `texto()` (já existem no arquivo).
- Produces:
  - `FichaPdf.anexoGerado` → `List<ItemAnexo>`, reiniciada a cada `gerar()`
  - `class ItemAnexo { final String titulo; final String texto; }` — exportada por `lib/services/ficha_pdf.dart`
  - `paragrafo(...)` com parâmetro nomeado `String? anexo` (título do bloco); devolve `bool cortou`

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar em `test/ficha_pdf_test.dart`:

```dart
  test('história longa vai para o anexo e a ficha marca o corte', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Tagarela';
    f.data['historia'] = List.filled(120,
        'Despertou numa noite de tempestade e desde então persegue o mesmo sonho.')
        .join(' ');

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('História'));
    final item = FichaPdf.anexoGerado.firstWhere((e) => e.titulo == 'História');
    expect(item.texto, f.data['historia']);
  });

  test('ficha curta não gera anexo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Sucinto';
    f.data['historia'] = 'Nasceu, Despertou, seguiu.';

    await FichaPdf.gerar(f);

    expect(FichaPdf.anexoGerado, isEmpty);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: FAIL — `The getter 'anexoGerado' isn't defined for the type 'FichaPdf'`.

- [ ] **Step 3: Implementar**

No topo de `lib/services/ficha_pdf.dart`, antes da classe `FichaPdf`:

```dart
/// Um bloco que não coube na ficha oficial e vai para as páginas de anexo.
class ItemAnexo {
  final String titulo;
  final String texto;
  const ItemAnexo(this.titulo, this.texto);
}
```

Dentro de `FichaPdf`, junto de `_sobrasPg2`:

```dart
  /// Blocos que não couberam na ficha oficial na última geração.
  /// Reiniciada no começo de `gerar()`; também usada nos testes.
  static final List<ItemAnexo> anexoGerado = [];
```

No começo de `gerar()`, logo depois de `await _carregar();`:

```dart
    anexoGerado.clear();
```

Trocar `paragrafo` por:

```dart
    /// Escreve o parágrafo nas linhas disponíveis da ficha oficial.
    /// Se o texto não couber inteiro, marca o corte e registra o bloco
    /// completo no anexo (o leitor recebe o texto todo, não só a sobra).
    /// Devolve `true` quando cortou.
    bool paragrafo(PdfGraphics g, PdfFont fonte, String t, List linhasY,
        num x0, num x1, {double tam = 7.3, String? anexo}) {
      if (t.trim().isEmpty) return false;
      const marca = ' (continua no anexo)';
      final largura = (x1 - x0).toDouble();
      final ls = quebra(fonte, t.trim(), largura, tam);
      final n = linhasY.length;
      final cortou = ls.length > n;
      for (var i = 0; i < ls.length && i < n; i++) {
        var linha = ls[i];
        if (cortou && i == n - 1) {
          // encurta a última linha até a marca caber
          while (linha.isNotEmpty &&
              larguraTexto(fonte, '$linha$marca', tam) > largura * s) {
            final corte = linha.lastIndexOf(' ');
            if (corte <= 0) break;
            linha = linha.substring(0, corte);
          }
          linha = '$linha$marca';
        }
        texto(g, fonte, linha, x0, (linhasY[i] as num) - 4,
            tam: tam, maxPx: largura + 10);
      }
      if (cortou && anexo != null) anexoGerado.add(ItemAnexo(anexo, t.trim()));
      return cortou;
    }
```

Passar o título do bloco em cada chamada da página 2:

```dart
      void bloco(String chave, String valor, String titulo) {
        final b = p2[chave] as Map<String, dynamic>;
        paragrafo(g, fonte, valor, b['linhas'] as List, b['x0'] as num,
            b['x1'] as num, anexo: titulo);
      }

      bloco('historia', sTxt('historia'), 'História');
      bloco('objetivos', sTxt('objetivosDestino'), 'Objetivos e Destino');
      bloco('rotinas', sTxt('rotinas'), 'Rotinas');
      bloco('focos', sTxt('focos'), 'Focos');
      bloco('itens', sTxt('itensEquipamentos'), 'Itens e Equipamentos');
```

E na Aparência:

```dart
      paragrafo(g, fonte, (f.aparencia['descricao'] ?? '').toString(),
          ap['livres'] as List, ap['x0'] as num, ap['x1'] as num,
          anexo: 'Aparência');
```

Nas Maravilhas, a continuação do bloco também ganha título:

```dart
            paragrafo(g, fonte, ls.skip(1).join(' '), m['linhas'] as List,
                m['x0'] as num, m['x1'] as num,
                anexo: 'Maravilha — ${nome.isEmpty ? 'sem nome' : nome}');
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: paragrafo avisa o corte e registra o bloco no anexo"
```

---

### Task 2: Listas que estouram vão para o anexo

**Files:**
- Modify: `lib/services/ficha_pdf.dart:206-237` (antecedentes e outras), `:288-336` (outras pg2, qualidades, defeitos), `:379-397` (combate)
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `ItemAnexo`, `FichaPdf.anexoGerado` da Task 1.
- Produces: nada novo.

- [ ] **Step 1: Escrever o teste que falha**

```dart
  test('listas que passam das linhas da ficha vão para o anexo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Colecionador';
    for (var i = 0; i < 14; i++) {
      f.adicionar('positivos', {
        'classe': 'qualidade', 'nome': 'Sentidos Aguçados',
        'sel': 3, 'detalhe': 'variante $i'});
    }
    for (var i = 0; i < 12; i++) {
      f.adicionar('combate', {
        'Arma/Manobra': 'Arma $i', 'Dif.': '6', 'Dano': '4',
        'Tipo': 'Letal', 'Alcance': '10m', 'Cadência': '1'});
    }

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('Qualidades (continuação)'));
    expect(titulos, contains('Combate (continuação)'));
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: FAIL — `anexoGerado` não contém esses títulos (hoje o excedente é descartado em silêncio).

- [ ] **Step 3: Implementar**

Em cada lista, depois do laço que desenha as linhas disponíveis, registrar o resto. Página 1, depois do laço de `sobras`:

```dart
      final restoPg1 = sobras.skip(out1Filas.length).toList();
      _sobrasPg2 = restoPg1;
```

(igual ao que já existe — só nomeado).

Página 2, depois do laço de `_sobrasPg2`:

```dart
      final sobrouOutras = _sobrasPg2.skip(out2Filas.length).toList();
      if (sobrouOutras.isNotEmpty) {
        anexoGerado.add(ItemAnexo('Outras Características (continuação)',
            sobrouOutras.map((e) => '${e.key}: ${e.value}').join('\n')));
      }
```

Qualidades:

```dart
      if (quals.length > qY.length) {
        anexoGerado.add(ItemAnexo('Qualidades (continuação)',
            quals.skip(qY.length).map((q) => '${q[0]} — ${q[1]}').join('\n')));
      }
```

Defeitos:

```dart
      if (defs.length > dY.length) {
        anexoGerado.add(ItemAnexo('Defeitos (continuação)',
            defs.skip(dY.length).map((d) => '${d[0]} — ${d[1]}').join('\n')));
      }
```

Maravilhas que nem começaram:

```dart
      if (f.maravilhas.length > mars.length) {
        anexoGerado.add(ItemAnexo(
            'Maravilhas (continuação)',
            f.maravilhas
                .skip(mars.length)
                .map((m) => '${m['Nome'] ?? ''}: ${m['Descrição'] ?? ''}')
                .join('\n\n')));
      }
```

Combate:

```dart
      if (f.combate.length > cbY.length) {
        anexoGerado.add(ItemAnexo(
            'Combate (continuação)',
            f.combate.skip(cbY.length).map((c) =>
                '${c['Arma/Manobra'] ?? ''} — dif ${c['Dif.'] ?? ''}, '
                'dano ${c['Dano'] ?? ''} ${c['Tipo'] ?? ''}, '
                'alcance ${c['Alcance'] ?? ''}, cadência ${c['Cadência'] ?? ''}')
                .join('\n')));
      }
```

Antecedentes que passaram das 6 linhas já caem em "Outras Características" da página 1 e, se ainda sobrarem, no bloco acima — nada extra a fazer.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS (5 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: listas excedentes registradas no anexo"
```

---

### Task 3: Especializações de Esfera e valores acima de 5 no anexo

**Files:**
- Modify: `lib/services/ficha_pdf.dart` (fim de `gerar()`, antes de montar as páginas de anexo)
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `Ficha.especEsferaDe`, `Ficha.esferaFinal`, `Ficha.areteFinal` (Fase 1); `ItemAnexo`.
- Produces: nada novo.

- [ ] **Step 1: Escrever o teste que falha**

```dart
  test('especializações de Esfera e valores acima de 5 saem no anexo', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Andarilho';
    f.setEsfera('correspondence', 7);
    f.addEspecEsfera('correspondence', 'Teleportes');
    f.data['arete'] = 8;

    await FichaPdf.gerar(f);

    final titulos = FichaPdf.anexoGerado.map((e) => e.titulo).toList();
    expect(titulos, contains('Especializações de Esfera'));
    expect(titulos, contains('Valores acima de cinco'));
    final vals = FichaPdf.anexoGerado
        .firstWhere((e) => e.titulo == 'Valores acima de cinco').texto;
    expect(vals, contains('Correspondência: 7'));
    expect(vals, contains('Arete: 8'));
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: FAIL — títulos ausentes.

- [ ] **Step 3: Implementar**

No fim de `gerar()`, depois de desenhar a página 2 e antes do `return doc.save();`:

```dart
    // ---- coleta o que a ficha oficial não consegue mostrar ----
    final specs = <String>[
      for (final e in GameData.esferas)
        if (f.especEsferaDe(e.chave).isNotEmpty)
          '${e.nome}: ${f.especEsferaDe(e.chave).join(', ')}'
          '${f.especEsferaAtiva(e.chave) ? '' : '  (sem efeito até a Esfera chegar em 4)'}',
    ];
    if (specs.isNotEmpty) {
      anexoGerado.add(ItemAnexo('Especializações de Esfera', specs.join('\n')));
    }

    final acima = <String>[
      for (final e in GameData.esferas)
        if (f.esferaFinal(e.chave) > 5) '${e.nome}: ${f.esferaFinal(e.chave)}',
      if (f.areteFinal > 5) 'Arete: ${f.areteFinal}',
      if (f.forcaVontadeFinal > 5) 'Força de Vontade: ${f.forcaVontadeFinal}',
    ];
    if (acima.isNotEmpty) {
      anexoGerado.add(ItemAnexo('Valores acima de cinco', acima.join('\n')));
    }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS (6 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: especializacoes de Esfera e valores acima de 5 no anexo"
```

---

### Task 4: Desenhar as páginas de anexo

**Files:**
- Modify: `lib/services/ficha_pdf.dart` (fim de `gerar()`)
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `anexoGerado`.
- Produces: nada novo.

- [ ] **Step 1: Escrever o teste que falha**

```dart
  test('PDF com anexo tem mais páginas que o sem anexo', () async {
    final curta = Ficha.criar();
    curta.data['nome'] = 'Curta';
    final bytesCurta = await FichaPdf.gerar(curta);

    final longa = Ficha.criar();
    longa.data['nome'] = 'Longa';
    longa.data['historia'] = List.filled(200,
        'Uma linha inteira de história que não cabe na ficha oficial.').join(' ');
    final bytesLonga = await FichaPdf.gerar(longa);

    expect(bytesLonga.length, greaterThan(bytesCurta.length));

    final out = File('build/ficha_test_anexo.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytesLonga);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: FAIL — as duas fichas geram PDFs do mesmo tamanho (as páginas de fundo dominam o arquivo e o texto extra não existe ainda). Se passar por acaso, conferir `build/ficha_test_anexo.pdf`: hoje ele tem 2 páginas.

- [ ] **Step 3: Implementar**

No fim de `gerar()`, depois da coleta da Task 3 e antes do `return doc.save();`:

```dart
    if (anexoGerado.isNotEmpty) {
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

`helv` já existe no escopo de `gerar()` (`final helv = pw.Font.helvetica();`).

- [ ] **Step 4: Rodar e conferir**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS (7 testes)

Abrir `build/ficha_test_anexo.pdf`: 3 páginas, a terceira com o título "Anexo — Longa" e a história inteira. Abrir `build/ficha_test.pdf` (do teste que já existia): continua com 2 páginas.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: paginas de anexo depois da ficha oficial"
```

---

### Task 5: Fechamento da fase

- [ ] **Step 1: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Analisar**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Conferir no app**

Run: `flutter run -d chrome`; numa ficha com história longa, exportar PDF e conferir a marca "(continua no anexo)" na página 2 e o texto completo na página 3.

- [ ] **Step 4: Commit final**

```bash
git add -A
git commit -m "fase 2: anexo do PDF concluido"
```
