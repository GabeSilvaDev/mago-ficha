import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/game_data.dart';
import '../models/ficha.dart';

/// Um bloco que não coube na ficha oficial e vai para as páginas de anexo.
class ItemAnexo {
  final String titulo;
  final String texto;
  const ItemAnexo(this.titulo, this.texto);
}

/// Gera o download da ficha preenchida EXATAMENTE sobre o PDF oficial
/// (ficha.pdf, 2 páginas). As páginas oficiais foram rasterizadas a 150dpi
/// (assets/ficha/pg-1.png / pg-2.png) e as coordenadas de cada campo/bolinha
/// foram calibradas automaticamente (assets/ficha/overlay.json).
class FichaPdf {
  static Map<String, dynamic>? _spec;
  static Uint8List? _png1, _png2;

  static const _tinta = PdfColor.fromInt(0xFF191434);

  /// Blocos que não couberam na ficha oficial na última geração.
  /// Reiniciada no começo de `gerar()`; também usada nos testes.
  static final List<ItemAnexo> anexoGerado = [];

  static Future<void> _carregar() async {
    _spec ??= jsonDecode(await rootBundle.loadString('assets/ficha/overlay.json'))
        as Map<String, dynamic>;
    _png1 ??= (await rootBundle.load('assets/ficha/pg-1.png')).buffer.asUint8List();
    _png2 ??= (await rootBundle.load('assets/ficha/pg-2.png')).buffer.asUint8List();
  }

  /// Monta o PDF final (A4, 2 páginas) e devolve os bytes.
  static Future<Uint8List> gerar(Ficha f) async {
    await _carregar();
    anexoGerado.clear();
    final spec = _spec!;
    final dim = (spec['dim'] as List).cast<num>();
    final pgW = dim[0].toDouble(), pgH = dim[1].toDouble();
    final s = PdfPageFormat.a4.width / pgW; // px (150dpi) -> pontos

    final doc = pw.Document();
    final helv = pw.Font.helvetica();

    void pagina(Uint8List png, void Function(PdfGraphics, PdfFont) desenha) {
      final bg = pw.MemoryImage(png);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.CustomPaint(
          size: PdfPoint(PdfPageFormat.a4.width, PdfPageFormat.a4.height),
          child: pw.Image(bg, fit: pw.BoxFit.fill),
          foregroundPainter: (canvas, size) {
            final fonte = helv.getFont(ctx);
            desenha(canvas, fonte);
          },
        ),
      ));
    }

    // ---- helpers em coordenadas do spec (px, origem topo-esquerda) ----
    double fx(num x) => x * s;
    double fy(num y) => (pgH - y) * s; // PDF tem origem embaixo

    void bola(PdfGraphics g, num x, num y, [double rPx = 7]) {
      g.setFillColor(_tinta);
      g.drawEllipse(fx(x), fy(y), rPx * s, rPx * s);
      g.fillPath();
    }

    void quadrado(PdfGraphics g, num x, num y, [double meioPx = 6]) {
      g.setFillColor(_tinta);
      g.drawRect(fx(x) - meioPx * s, fy(y) - meioPx * s, 2 * meioPx * s, 2 * meioPx * s);
      g.fillPath();
    }

    void branco(PdfGraphics g, List<num> r) {
      g.setFillColor(PdfColors.white);
      g.drawRect(fx(r[0]), fy(r[3]), fx(r[2] - r[0]), (r[3] - r[1]) * s);
      g.fillPath();
    }

    double larguraTexto(PdfFont fonte, String t, double tam) =>
        fonte.stringMetrics(t).width * tam;

    void texto(PdfGraphics g, PdfFont fonte, String t, num x, num y,
        {double tam = 8.6,
        bool centro = false,
        bool direita = false,
        double? maxPx}) {
      if (t.isEmpty) return;
      var txt = t;
      if (maxPx != null) {
        while (txt.isNotEmpty && larguraTexto(fonte, txt, tam) > maxPx * s) {
          txt = txt.substring(0, txt.length - 1);
        }
      }
      g.setFillColor(_tinta);
      var px = fx(x);
      if (centro) px -= larguraTexto(fonte, txt, tam) / 2;
      if (direita) px -= larguraTexto(fonte, txt, tam);
      g.drawString(fonte, tam, txt, px, fy(y));
    }

    List<String> quebra(PdfFont fonte, String t, double largPx, double tam) {
      final palavras = t.split(RegExp(r'\s+'));
      final linhas = <String>[];
      var cur = '';
      for (final p in palavras) {
        final tent = cur.isEmpty ? p : '$cur $p';
        if (larguraTexto(fonte, tent, tam) <= largPx * s) {
          cur = tent;
        } else {
          if (cur.isNotEmpty) linhas.add(cur);
          cur = p;
        }
      }
      if (cur.isNotEmpty) linhas.add(cur);
      return linhas;
    }

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

    /// Pinta as bolinhas da fileira. A ficha oficial tem 5 círculos impressos;
    /// quando o valor final passa disso (mesa com teto 10), escreve o número
    /// logo depois da última bolinha.
    void fileira(PdfGraphics g, Map fila, int valor,
        {double rPx = 7, PdfFont? fonte}) {
      final xs = (fila['xs'] as List).cast<num>();
      final y = fila['y'] as num;
      for (var k = 0; k < valor.clamp(0, xs.length); k++) {
        bola(g, xs[k], y, rPx);
      }
      if (fonte != null && valor > xs.length) {
        texto(g, fonte, '$valor', xs.last + 13, y + 4, tam: 7.0);
      }
    }

    // ================= PÁGINA 1 =================
    final p1 = spec['pg1'] as Map<String, dynamic>;
    pagina(_png1!, (g, fonte) {
      for (final r in (p1['brancos'] as List)) {
        branco(g, (r as List).cast<num>());
      }
      final tx = p1['textos'] as Map<String, dynamic>;
      void campo(String chave, String v) {
        final p = (tx[chave] as List).cast<num>();
        texto(g, fonte, v, p[0], p[1]);
      }

      campo('nome', f.nome);
      campo('jogador', f.jogador);
      campo('cronica', f.cronica);
      campo('natureza', f.natureza);
      campo('comportamento', f.comportamento);
      campo('essencia', f.essencia);
      campo('afiliacao', f.afiliacao);
      campo('faccao', f.faccao);
      campo('conceito', f.conceito);

      // Atributos e Habilidades (valores finais)
      for (final cat in GameData.atributos.categorias) {
        final filas = (p1['atributos'][cat.nome] as List);
        for (var i = 0; i < cat.tracos.length && i < filas.length; i++) {
          fileira(g, filas[i], f.atributoFinal(cat.tracos[i].nome),
              fonte: fonte);
        }
      }
      // especializações por habilidade (escritas na linha, antes das bolinhas)
      final especPorHab = <String, List<String>>{};
      for (final e in f.especializacoes) {
        especPorHab
            .putIfAbsent('${e['habilidade']}', () => [])
            .add('${e['nome']}');
      }
      // habilidades personalizadas: a ficha oficial não tem linha pra elas,
      // então entram em "Outras Características" (com a coluna entre parênteses)
      final habExtras = <MapEntry<String, int>>[
        for (final e in f.habilidadesExtras)
          MapEntry('${e['nome']} (${e['categoria']})',
              f.habilidadeFinal('${e['nome']}')),
      ];
      for (final cat in GameData.habilidades.categorias) {
        final filas = (p1['habilidades'][cat.nome] as List);
        for (var i = 0; i < cat.tracos.length && i < filas.length; i++) {
          final nomeHab = cat.tracos[i].nome;
          fileira(g, filas[i], f.habilidadeFinal(nomeHab), fonte: fonte);
          final specs = especPorHab[nomeHab];
          if (specs != null) {
            final fila = filas[i] as Map;
            final xs = (fila['xs'] as List).cast<num>();
            texto(g, fonte, specs.join(', '), xs.first - 14,
                (fila['y'] as num) + 5,
                tam: 6.2, direita: true, maxPx: 105);
          }
        }
      }
      // Esferas
      final esf = p1['esferas'] as Map<String, dynamic>;
      final ordem = esf['ordem'] as Map<String, dynamic>;
      for (final c in ['c1', 'c2', 'c3']) {
        final filas = (esf[c] as List);
        final chaves = (ordem[c] as List).cast<String>();
        for (var i = 0; i < chaves.length && i < filas.length; i++) {
          fileira(g, filas[i], f.esferaFinal(chaves[i]), fonte: fonte);
        }
      }
      // Antecedentes (até 6) + excedente/outras características pg1 (7)
      final antecedentes = <MapEntry<String, int>>[];
      for (final e in f.positivos) {
        if (e['classe'] == 'antecedente') {
          final det = (e['detalhe'] ?? '') as String;
          final nome = det.isEmpty ? '${e['nome']}' : '${e['nome']} ($det)';
          antecedentes.add(MapEntry(nome, (e['sel'] as num?)?.toInt() ?? 1));
        }
      }
      final antec = p1['antecedentes'] as Map<String, dynamic>;
      final antecFilas = antec['fileiras'] as List;
      final antecY = (antec['nomeY'] as List).cast<num>();
      for (var i = 0; i < antecedentes.length && i < antecFilas.length; i++) {
        texto(g, fonte, antecedentes[i].key, antec['nomeX'], antecY[i] - 3,
            tam: 7.3, maxPx: 205);
        fileira(g, antecFilas[i] as Map, antecedentes[i].value);
      }
      final sobras = <MapEntry<String, int>>[
        ...antecedentes.skip(antecFilas.length),
        ...habExtras,
        for (final o in f.outrasCaracteristicas)
          MapEntry('${o['nome']}', (o['valor'] as num?)?.toInt() ?? 0),
      ];
      final out1 = p1['outras'] as Map<String, dynamic>;
      final out1Filas = out1['fileiras'] as List;
      final out1Y = (out1['nomeY'] as List).cast<num>();
      for (var i = 0; i < sobras.length && i < out1Filas.length; i++) {
        texto(g, fonte, sobras[i].key, out1['nomeX'], out1Y[i] - 3,
            tam: 7.3, maxPx: 205);
        fileira(g, out1Filas[i] as Map, sobras[i].value);
      }
      _sobrasPg2 = sobras.skip(out1Filas.length).toList();

      // Arete / Força de Vontade / Vitalidade
      fileira(g, p1['arete'] as Map, f.areteFinal, fonte: fonte);
      fileira(g, p1['fdvCirc'] as Map, f.forcaVontadeFinal, fonte: fonte);
      final fdvQ = p1['fdvQuad'] as Map<String, dynamic>;
      final fdvXs = (fdvQ['xs'] as List).cast<num>();
      for (var k = 0; k < f.fdvAtual.clamp(0, fdvXs.length); k++) {
        quadrado(g, fdvXs[k], fdvQ['y'] as num);
      }
      final vit = (p1['vitalidade'] as List);
      for (var k = 0; k < f.vitalidadeDano.clamp(0, vit.length); k++) {
        final v = vit[k] as Map;
        quadrado(g, v['x'] as num, v['y'] as num);
      }
      // Roda Quintessência (horário) / Paradoxo (anti-horário)
      final roda = p1['roda'] as Map<String, dynamic>;
      final cx = roda['cx'] as num, cy = roda['cy'] as num;
      final slots = (roda['slots'] as List).cast<Map>();
      double angulo(Map sl) =>
          (math.atan2((sl['y'] as num) - cy, (sl['x'] as num) - cx) *
                  180 /
                  math.pi +
              360) %
          360;
      final orden = [...slots]..sort((a, b) => angulo(a).compareTo(angulo(b)));
      var i0 = 0;
      var melhor = 999.0;
      for (var i = 0; i < orden.length; i++) {
        final d = (angulo(orden[i]) - 180).abs();
        if (d < melhor) {
          melhor = d;
          i0 = i;
        }
      }
      final n = orden.length;
      for (var k = 0; k < f.quintAtual.clamp(0, n); k++) {
        final sl = orden[(i0 + k) % n];
        bola(g, sl['x'] as num, sl['y'] as num, 6);
      }
      for (var k = 0; k < f.paradoxoAtual.clamp(0, n); k++) {
        final sl = orden[(i0 - 1 - k + 2 * n) % n];
        quadrado(g, sl['x'] as num, sl['y'] as num, 5);
      }
      // Experiência
      final xp = (tx['experiencia'] as List).cast<num>();
      texto(g, fonte, '${f.experiencia}', xp[0], xp[1], tam: 10, centro: true);
    });

    // ================= PÁGINA 2 =================
    final p2 = spec['pg2'] as Map<String, dynamic>;
    pagina(_png2!, (g, fonte) {
      // Outras características (continuação, 9 linhas)
      final out2 = p2['outras'] as Map<String, dynamic>;
      final out2Filas = out2['fileiras'] as List;
      final out2Y = (out2['nomeY'] as List).cast<num>();
      for (var i = 0; i < _sobrasPg2.length && i < out2Filas.length; i++) {
        texto(g, fonte, _sobrasPg2[i].key, out2['nomeX'], out2Y[i] - 3,
            tam: 7.3, maxPx: 225);
        final fila = out2Filas[i] as Map;
        final xs = (fila['xs'] as List).cast<num>();
        for (var k = 0; k < _sobrasPg2[i].value.clamp(0, xs.length); k++) {
          bola(g, xs[k], fila['y'] as num, 6);
        }
      }
      final sobrouOutras = _sobrasPg2.skip(out2Filas.length).toList();
      if (sobrouOutras.isNotEmpty) {
        anexoGerado.add(ItemAnexo('Outras Características (continuação)',
            sobrouOutras.map((e) => '${e.key}: ${e.value}').join('\n')));
      }
      // Qualidades / Defeitos
      final quals = <List<String>>[];
      for (final e in f.positivos) {
        if (e['classe'] == 'qualidade') {
          final det = (e['detalhe'] ?? '') as String;
          final nome = det.isEmpty ? '${e['nome']}' : '${e['nome']}: $det';
          quals.add([nome, '${GameData.custoPositivo(e)}']);
        }
      }
      final defs = <List<String>>[];
      for (final e in f.defeitos) {
        final sub = (e['subtipo'] ?? '') as String;
        final det = (e['detalhe'] ?? '') as String;
        var nome = '${e['nome']}';
        if (sub.isNotEmpty) nome = '$nome — $sub';
        if (det.isNotEmpty) nome = '$nome ($det)';
        defs.add([nome, '${GameData.custoDefeito(e)}']);
      }
      for (final e in f.defeitosGeneticos) {
        defs.add(['${e['nome']} (genético)', '0']);
      }
      final q = p2['qualidades'] as Map<String, dynamic>;
      final qY = (q['linhas'] as List).cast<num>();
      for (var i = 0; i < quals.length && i < qY.length; i++) {
        texto(g, fonte, quals[i][0], q['nomeX'], qY[i] - 3, tam: 7.3, maxPx: 218);
        texto(g, fonte, quals[i][1], q['custoX'], qY[i] - 3,
            tam: 7.3, centro: true);
      }
      if (quals.length > qY.length) {
        anexoGerado.add(ItemAnexo('Qualidades (continuação)',
            quals.skip(qY.length).map((q) => '${q[0]} — ${q[1]}').join('\n')));
      }
      final df = p2['defeitos'] as Map<String, dynamic>;
      final dY = (df['linhas'] as List).cast<num>();
      for (var i = 0; i < defs.length && i < dY.length; i++) {
        texto(g, fonte, defs[i][0], df['nomeX'], dY[i] - 3, tam: 7.3, maxPx: 225);
        texto(g, fonte, defs[i][1], df['bonusX'], dY[i] - 3,
            tam: 7.3, centro: true);
      }
      if (defs.length > dY.length) {
        anexoGerado.add(ItemAnexo('Defeitos (continuação)',
            defs.skip(dY.length).map((d) => '${d[0]} — ${d[1]}').join('\n')));
      }
      // Blocos de texto
      String sTxt(String k) => (f.data[k] ?? '').toString();
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
      // Aparência
      final ap = p2['aparencia'] as Map<String, dynamic>;
      paragrafo(g, fonte, (f.aparencia['descricao'] ?? '').toString(),
          ap['livres'] as List, ap['x0'] as num, ap['x1'] as num,
          anexo: 'Aparência');
      final campos = ap['campos'] as Map<String, dynamic>;
      campos.forEach((k, pos) {
        final p = (pos as List).cast<num>();
        texto(g, fonte, (f.aparencia[k] ?? '').toString(), p[0], p[1] - 4,
            tam: 7.3, maxPx: 165);
      });
      // Maravilhas (3 blocos)
      final mars = p2['maravilhas'] as List;
      for (var i = 0; i < f.maravilhas.length && i < mars.length; i++) {
        final m = mars[i] as Map<String, dynamic>;
        final nomeP = (m['nome'] as List).cast<num>();
        final descP = (m['desc'] as List).cast<num>();
        final nome = '${f.maravilhas[i]['Nome'] ?? ''}';
        final desc = '${f.maravilhas[i]['Descrição'] ?? ''}';
        texto(g, fonte, nome, nomeP[0], nomeP[1] - 4, tam: 7.3, maxPx: 215);
        final larg1 = ((m['x1'] as num) - descP[0]).toDouble();
        final ls = quebra(fonte, desc, larg1, 7.3);
        if (ls.isNotEmpty) {
          texto(g, fonte, ls.first, descP[0], descP[1] - 4, tam: 7.3);
          if (ls.length > 1) {
            paragrafo(g, fonte, ls.skip(1).join(' '), m['linhas'] as List,
                m['x0'] as num, m['x1'] as num,
                anexo: 'Maravilha — ${nome.isEmpty ? 'sem nome' : nome}');
          }
        }
      }
      if (f.maravilhas.length > mars.length) {
        anexoGerado.add(ItemAnexo(
            'Maravilhas (continuação)',
            f.maravilhas
                .skip(mars.length)
                .map((m) => '${m['Nome'] ?? ''}: ${m['Descrição'] ?? ''}')
                .join('\n\n')));
      }
      // Combate
      final cb = p2['combate'] as Map<String, dynamic>;
      final cbY = (cb['linhas'] as List).cast<num>();
      for (var i = 0; i < f.combate.length && i < cbY.length; i++) {
        final c = f.combate[i];
        final y = cbY[i] - 4;
        texto(g, fonte, '${c['Arma/Manobra'] ?? ''}', cb['armaX'], y,
            tam: 7.3, maxPx: 185);
        for (final par in [
          ['difX', 'Dif.'],
          ['danoX', 'Dano'],
          ['tipoX', 'Tipo'],
          ['alcanceX', 'Alcance'],
          ['cadenciaX', 'Cadência'],
        ]) {
          texto(g, fonte, '${c[par[1]] ?? ''}', cb[par[0]], y,
              tam: 7.3, centro: true, maxPx: 80);
        }
      }
      if (f.combate.length > cbY.length) {
        anexoGerado.add(ItemAnexo(
            'Combate (continuação)',
            f.combate
                .skip(cbY.length)
                .map((c) => '${c['Arma/Manobra'] ?? ''} — dif ${c['Dif.'] ?? ''}, '
                    'dano ${c['Dano'] ?? ''} ${c['Tipo'] ?? ''}, '
                    'alcance ${c['Alcance'] ?? ''}, cadência ${c['Cadência'] ?? ''}')
                .join('\n')));
      }
    });

    return doc.save();
  }

  // Excedentes de antecedentes/outras da pg1 que continuam na pg2.
  static List<MapEntry<String, int>> _sobrasPg2 = [];
}
