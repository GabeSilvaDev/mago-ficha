import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data/game_data.dart';
import '../models/ficha.dart';
import '../services/ficha_pdf.dart';
import '../store/ficha_store.dart';
import '../theme.dart';
import '../widgets/retrato.dart';
import 'wizard_screen.dart';

/// Exibe a ficha completa (valores FINAIS = grátis + bônus) com trackers
/// interativos de jogo: Vitalidade, Força de Vontade, Quintessência,
/// Paradoxo e Experiência — alterações salvam na hora.
class FichaViewScreen extends StatefulWidget {
  final String fichaId;
  const FichaViewScreen({super.key, required this.fichaId});

  @override
  State<FichaViewScreen> createState() => _FichaViewScreenState();
}

class _FichaViewScreenState extends State<FichaViewScreen> {
  Ficha? f;

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  void _recarregar() => setState(() => f = FichaStore.porId(widget.fichaId));

  /// Abre o wizard inteiro (todas as etapas).
  Future<void> _editar() async {
    if (f == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WizardScreen(existente: f)),
    );
    _recarregar();
  }

  /// Abre SÓ a etapa [passo] do wizard: edita e confirma apenas aquela tela.
  ///  0 Identidade · 1 Atributos · 2 Habilidades · 3 Esferas
  ///  4 Vantagens & Defeitos · 5 Toques Finais · 6 Detalhes
  ///
  /// [secoes] recorta ainda mais: só os campos daquele bloco da ficha
  /// aparecem (ex.: o lápis de "Arete & Força de Vontade" abre só os dois).
  Future<void> _editarPasso(int passo,
      {Set<String>? secoes, String? titulo}) async {
    if (f == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WizardScreen(
          existente: f,
          passos: [passo],
          secoes: secoes,
          titulo: titulo,
        ),
      ),
    );
    _recarregar();
  }

  bool _gerandoPdf = false;

  /// Baixa a ficha preenchida sobre o PDF oficial (ficha.pdf).
  Future<void> _baixarPdf() async {
    final ficha = f;
    if (ficha == null || _gerandoPdf) return;
    setState(() => _gerandoPdf = true);
    try {
      final bytes = await FichaPdf.gerar(ficha);
      await Printing.sharePdf(bytes: bytes, filename: 'ficha.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao gerar o PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  /// Salva o estado de jogo imediatamente (trackers).
  Future<void> _salvarQuieto() async {
    final ficha = f;
    if (ficha == null) return;
    await FichaStore.salvar(ficha);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ficha = f;
    if (ficha == null) {
      return const Scaffold(body: Center(child: Text('Ficha não encontrada.')));
    }
    ListView aba(List<Widget> filhos) => ListView(
          padding: const EdgeInsets.all(16),
          children: [...filhos, const SizedBox(height: 24)],
        );
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ficha.nome.isEmpty ? 'Sem nome' : ficha.nome),
          actions: [
            IconButton(
              onPressed: _gerandoPdf ? null : _baixarPdf,
              icon: _gerandoPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Cores.pergaminho),
                    )
                  : const Icon(Icons.download),
              tooltip: 'Baixar ficha.pdf',
            ),
            IconButton(
              onPressed: _editar,
              icon: const Icon(Icons.edit_note),
              tooltip: 'Editar ficha inteira (todas as etapas)',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Cores.dourado,
            labelColor: Cores.dourado,
            unselectedLabelColor: Cores.pergaminho,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Personagem'),
              Tab(text: 'Status'),
              Tab(text: 'Atributos & Habilidades'),
              Tab(text: 'Esferas'),
              Tab(text: 'Vantagens & Defeitos'),
              Tab(text: 'Detalhes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1 — Personagem
            aba([
              FaixaSecao('Identidade', onEditar: () => _editarPasso(0)),
              _cardIdentidade(ficha),
            ]),
            // 2 — Status (trackers de jogo)
            aba([
              FaixaSecao('Arete & Força de Vontade',
                  onEditar: () => _editarPasso(5,
                      secoes: {'arete', 'forcaVontade'},
                      titulo: 'Arete & Força de Vontade')),
              _cardAreteFdv(ficha),
              FaixaSecao('Quintessência & Paradoxo',
                  onEditar: () => _editarPasso(5,
                      secoes: {'quintessencia'}, titulo: 'Quintessência')),
              _cardQuintParadoxo(ficha),
              const FaixaSecao('Vitalidade'),
              _cardVitalidade(ficha),
              const FaixaSecao('Experiência'),
              _cardExperiencia(ficha),
            ]),
            // 3 — Atributos & Habilidades
            aba([
              FaixaSecao('Atributos', onEditar: () => _editarPasso(1)),
              _bloco(GameData.atributos, ficha.atributoFinal,
                  ficha.atributosPrioridade),
              FaixaSecao('Habilidades', onEditar: () => _editarPasso(2)),
              _bloco(GameData.habilidades, ficha.habilidadeFinal,
                  ficha.habilidadesPrioridade,
                  sufixos: _sufixosEspecializacao(ficha),
                  extras: ficha.extrasDaCategoria),
            ]),
            // 4 — Esferas
            aba([
              FaixaSecao('Esferas', onEditar: () => _editarPasso(3)),
              _cardEsferas(ficha),
            ]),
            // 5 — Vantagens & Defeitos
            aba([
              FaixaSecao('Antecedentes & Qualidades',
                  onEditar: () => _editarPasso(4,
                      secoes: {'positivos'},
                      titulo: 'Antecedentes & Qualidades')),
              _cardPositivos(ficha),
              FaixaSecao('Defeitos',
                  onEditar: () => _editarPasso(4,
                      secoes: {'defeitos'}, titulo: 'Defeitos')),
              _cardDefeitos(ficha),
            ]),
            // 6 — Detalhes
            aba([
              FaixaSecao('Detalhes', onEditar: () => _editarPasso(6)),
              if (_temDetalhes(ficha))
                _cardDetalhes(ficha)
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Sem detalhes preenchidos.',
                          style: TextStyle(color: Cores.tinta))),
                ),
              if (ficha.combate.isNotEmpty) ...[
                const FaixaSecao('Combate'),
                _cardCombate(ficha),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  // ---------- Identidade ----------
  Widget _cardIdentidade(Ficha ficha) {
    String ou(String v) => v.isEmpty ? '—' : v;
    Widget linha(String a, String va, String b, String vb) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: _rotuloValor(a, ou(va))),
              Expanded(child: _rotuloValor(b, ou(vb))),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: RetratoAvatar(retratoId: ficha.retratoId, tamanho: 72),
            ),
            Expanded(
              child: Column(children: [
            linha('Nome', ficha.nome, 'Jogador', ficha.jogador),
            linha('Crônica', ficha.cronica, 'Conceito', ficha.conceito),
            linha('Natureza', ficha.natureza, 'Comportamento',
                ficha.comportamento),
            linha('Essência', ficha.essencia, 'Afiliação', ficha.afiliacao),
            linha(
                'Facção',
                ficha.faccao == ficha.afiliacao ? '— (sem subdivisão)' : ficha.faccao,
                'Afinidade',
                GameData.esferaPorChave(ficha.afinidade)?.nome ?? ''),
          ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rotuloValor(String rotulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo,
            style: const TextStyle(
                fontSize: 11, color: Cores.indigoClaro,
                fontWeight: FontWeight.bold)),
        Text(valor, style: const TextStyle(color: Cores.tinta)),
      ],
    );
  }

  // ---------- Blocos de traços (valores finais) ----------
  Map<String, List<String>> _sufixosEspecializacao(Ficha ficha) {
    final m = <String, List<String>>{};
    for (final e in ficha.especializacoes) {
      m.putIfAbsent('${e['habilidade']}', () => []).add('${e['nome']}');
    }
    return m;
  }

  Widget _bloco(BlocoTracos bloco, int Function(String) valor,
      Map<String, dynamic> prioridades,
      {Map<String, List<String>>? sufixos,
      List<ItemDescrito> Function(String)? extras}) {
    return Column(
      children: [
        for (final cat in bloco.categorias)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cat.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Cores.dourado)),
                      const Spacer(),
                      Text(_nomePrioridade(bloco, prioridades[cat.nome]),
                          style: const TextStyle(
                              fontSize: 12, color: Cores.indigoClaro)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final tr in [
                    ...cat.tracos,
                    ...?extras?.call(cat.nome),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                                sufixos?[tr.nome] == null
                                    ? tr.nome
                                    : '${tr.nome} (${sufixos![tr.nome]!.join(', ')})',
                                style: const TextStyle(color: Cores.tinta)),
                          ),
                          _pontos(valor(tr.nome), bloco.regra.maximo),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _nomePrioridade(BlocoTracos bloco, dynamic chave) {
    for (final p in bloco.regra.prioridades) {
      if (p.chave == chave) return '${p.nome} (${p.pontos})';
    }
    return '';
  }

  /// Bolinhas grandes (círculos desenhados) para leitura fácil na ficha.
  Widget _pontos(int v, int max, {double tam = 22, double espaco = 3}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= max; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: espaco / 2),
            child: Container(
              width: tam,
              height: tam,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= v ? Cores.indigo : Colors.transparent,
                border: Border.all(color: Cores.dourado, width: 1.6),
              ),
            ),
          ),
      ],
    );
  }

  /// A ficha pronta mostra 5 bolinhas; só abre para 10 quando o valor passa
  /// de 5 (mesa que usa o teto opcional).
  int _tetoVisual(int v) => v > 5 ? GameData.esferasMaximoLivre : 5;

  // ---------- Esferas ----------
  Widget _cardEsferas(Ficha ficha) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in GameData.esferas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (ficha.afinidade == e.chave)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star,
                                size: 14, color: Cores.dourado),
                          ),
                        Expanded(
                          child: Text(e.nome,
                              style: const TextStyle(color: Cores.tinta)),
                        ),
                        _pontos(
                          ficha.esferaFinal(e.chave),
                          _tetoVisual(ficha.esferaFinal(e.chave)),
                          tam: ficha.esferaFinal(e.chave) > 5 ? 15 : 22,
                          espaco: ficha.esferaFinal(e.chave) > 5 ? 2 : 3,
                        ),
                      ],
                    ),
                    if (ficha.especEsferaDe(e.chave).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 18, top: 2),
                        child: Text(
                          ficha.especEsferaDe(e.chave).join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: ficha.especEsferaAtiva(e.chave)
                                ? Cores.indigo
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Arete & Força de Vontade ----------
  Widget _mais(VoidCallback? on) => IconButton(
      icon: const Icon(Icons.add_circle_outline), onPressed: on);
  Widget _menos(VoidCallback? on) => IconButton(
      icon: const Icon(Icons.remove_circle_outline), onPressed: on);

  Widget _cardAreteFdv(Ficha ficha) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arete',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Cores.indigo)),
            const SizedBox(height: 6),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: _pontos(ficha.areteFinal, GameData.areteMaximoLivre,
                    tam: 24, espaco: 5)),
            const Divider(color: Cores.dourado, height: 20),
            const Text('Força de Vontade',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Cores.indigo)),
            const SizedBox(height: 6),
            FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    _pontos(ficha.forcaVontadeFinal, 10, tam: 24, espaco: 5)),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(
                    width: 130,
                    child: Text('Atual (temporária)',
                        style: TextStyle(fontSize: 12.5))),
                _menos(ficha.fdvAtual > 0
                    ? () {
                        ficha.fdvAtual = ficha.fdvAtual - 1;
                        _salvarQuieto();
                      }
                    : null),
                Text('${ficha.fdvAtual} / ${ficha.forcaVontadeFinal}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                _mais(ficha.fdvAtual < ficha.forcaVontadeFinal
                    ? () {
                        ficha.fdvAtual = ficha.fdvAtual + 1;
                        _salvarQuieto();
                      }
                    : null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Quintessência & Paradoxo (roda de 20) ----------
  Widget _cardQuintParadoxo(Ficha ficha) {
    final livre = GameData.rodaQuintessencia -
        ficha.quintAtual -
        ficha.paradoxoAtual;
    Widget linha(String rotulo, int v, VoidCallback? menos, VoidCallback? mais) {
      return Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(rotulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo))),
          _menos(menos),
          SizedBox(
              width: 30,
              child: Text('$v',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          _mais(mais),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            linha(
              'Quintessência',
              ficha.quintAtual,
              ficha.quintAtual > 0
                  ? () {
                      ficha.quintAtual = ficha.quintAtual - 1;
                      _salvarQuieto();
                    }
                  : null,
              livre > 0
                  ? () {
                      ficha.quintAtual = ficha.quintAtual + 1;
                      _salvarQuieto();
                    }
                  : null,
            ),
            linha(
              'Paradoxo',
              ficha.paradoxoAtual,
              ficha.paradoxoAtual > 0
                  ? () {
                      ficha.paradoxoAtual = ficha.paradoxoAtual - 1;
                      _salvarQuieto();
                    }
                  : null,
              livre > 0
                  ? () {
                      ficha.paradoxoAtual = ficha.paradoxoAtual + 1;
                      _salvarQuieto();
                    }
                  : null,
            ),
            Text(
              'Roda de ${GameData.rodaQuintessencia} espaços — livres: $livre. '
              'Inicial: Quintessência ${ficha.quintessencia} (= Avatar '
              '${ficha.avatar}${ficha.bonusQuintessencia > 0 ? ' + ${ficha.bonusQuintessencia}×${GameData.quintessenciaPacote} de bônus' : ''}), Paradoxo 0.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Vitalidade (interativa) ----------
  Widget _cardVitalidade(Ficha ficha) {
    final dano = ficha.vitalidadeDano;
    final niveis = GameData.niveisVitalidade;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          children: [
            for (int i = 0; i < niveis.length; i++)
              InkWell(
                onTap: () {
                  ficha.vitalidadeDano = (dano == i + 1) ? i : i + 1;
                  _salvarQuieto();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(niveis[i][0],
                            style: TextStyle(
                                color: Cores.tinta,
                                fontWeight: dano == i + 1
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                      SizedBox(
                          width: 30,
                          child: Text(niveis[i][1],
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Cores.indigo))),
                      Icon(
                        i < dano
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: i < dano ? Cores.indigo : Cores.dourado,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              dano == 0
                  ? 'Sem ferimentos. Toque num nível para marcar dano.'
                  : 'Nível atual: ${niveis[dano - 1][0]} '
                      '(penalidade ${niveis[dano - 1][1]}).',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Experiência ----------
  Widget _cardExperiencia(Ficha ficha) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: Text('Pontos de Experiência',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
            ),
            _menos(ficha.experiencia > 0
                ? () {
                    ficha.experiencia = ficha.experiencia - 1;
                    _salvarQuieto();
                  }
                : null),
            SizedBox(
                width: 34,
                child: Text('${ficha.experiencia}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            _mais(() {
              ficha.experiencia = ficha.experiencia + 1;
              _salvarQuieto();
            }),
          ],
        ),
      ),
    );
  }

  // ---------- Positivos / Defeitos ----------
  /// Tooltip ao segurar (mesmo padrão do wizard).
  Widget _dica(String texto, Widget child) {
    if (texto.trim().isEmpty) return child;
    return Tooltip(
      message: texto,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 12),
      waitDuration: Duration.zero,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cores.indigo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cores.dourado),
      ),
      textStyle: const TextStyle(
          color: Cores.pergaminho, fontSize: 13.5, height: 1.35),
      child: child,
    );
  }

  String _resumoPositivo(Map<String, dynamic> e) {
    if (e['custom'] == true) return (e['descricao'] ?? '') as String;
    if (e['classe'] == 'antecedente') {
      return GameData.antecedentePorNome(e['nome'] as String?)?.resumo ?? '';
    }
    return GameData.qualidadePorNome(e['nome'] as String?)?.resumo ?? '';
  }

  String _resumoDefeito(Map<String, dynamic> e) {
    if (e['custom'] == true) return (e['descricao'] ?? '') as String;
    return GameData.defeitoPorNome(e['nome'] as String?)?.resumo ?? '';
  }

  Widget _cardPositivos(Ficha ficha) {
    final pos = ficha.positivos;
    final gen = ficha.defeitosGeneticos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pos.isEmpty)
              const Text('—', style: TextStyle(color: Cores.tinta)),
            for (final e in pos)
              _dica(
                '${e['nome']} — ${_resumoPositivo(e)}',
                _linhaItem(
                  '${e['nome']}'
                  '${e['classe'] == 'antecedente' ? ' ${e['sel']}' : ''}'
                  '${((e['detalhe'] ?? '') as String).isNotEmpty ? ' (${e['detalhe']})' : ''}',
                  '${GameData.custoPositivo(e)}',
                ),
              ),
            if (pos.isNotEmpty) ...[
              const Divider(color: Cores.dourado),
              Text('Total positivo: ${ficha.totalPositivo} pts '
                  '(= Defeitos: ${ficha.totalDefeito})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
            ],
            if (gen.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Defeitos Genéticos:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.dourado)),
              for (final e in gen)
                Text('• ${e['nome']}',
                    style: const TextStyle(color: Cores.tinta)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardDefeitos(Ficha ficha) {
    final defs = ficha.defeitos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (defs.isEmpty)
              const Text('—', style: TextStyle(color: Cores.tinta)),
            for (final e in defs)
              _dica(
                '${e['nome']} — ${_resumoDefeito(e)}',
                _linhaItem(
                  '${e['nome']}'
                  '${((e['subtipo'] ?? '') as String).isNotEmpty ? ' — ${e['subtipo']}' : ''}'
                  '${((e['detalhe'] ?? '') as String).isNotEmpty ? ' (${e['detalhe']})' : ''}',
                  '${GameData.custoDefeito(e)}',
                ),
              ),
            if (defs.isNotEmpty) ...[
              const Divider(color: Cores.dourado),
              Text('Total negativo: ${ficha.totalDefeito} pts',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linhaItem(String nome, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(nome, style: const TextStyle(color: Cores.tinta))),
          Text(pts,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Cores.indigo)),
        ],
      ),
    );
  }

  // ---------- Detalhes ----------
  bool _temDetalhes(Ficha ficha) {
    final ap = ficha.aparencia;
    return (ficha.data['historia'] ?? '').toString().isNotEmpty ||
        (ficha.data['objetivosDestino'] ?? '').toString().isNotEmpty ||
        (ficha.data['rotinas'] ?? '').toString().isNotEmpty ||
        (ficha.data['focos'] ?? '').toString().isNotEmpty ||
        (ficha.data['itensEquipamentos'] ?? '').toString().isNotEmpty ||
        (ficha.data['notas'] ?? '').toString().isNotEmpty ||
        ficha.maravilhas.isNotEmpty ||
        ficha.outrasCaracteristicas.isNotEmpty ||
        ap.values.any((v) => (v ?? '').toString().isNotEmpty);
  }

  Widget _cardDetalhes(Ficha ficha) {
    final ap = ficha.aparencia;
    String s(String k) => (ficha.data[k] ?? '').toString();
    final aparenciaCampos = [
      ['Idade', ap['idade']],
      ['Idade Aparente', ap['idadeAparente']],
      ['Sexo', ap['sexo']],
      ['Etnia', ap['etnia']],
      ['Cabelos', ap['cabelos']],
      ['Olhos', ap['olhos']],
      ['Altura', ap['altura']],
      ['Peso', ap['peso']],
    ].where((e) => (e[1] ?? '').toString().isNotEmpty).toList();

    Widget blocoTexto(String rotulo, String valor) => valor.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Cores.dourado)),
                Text(valor, style: const TextStyle(color: Cores.tinta)),
              ],
            ),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            blocoTexto('História', s('historia')),
            blocoTexto('Objetivos / Destino', s('objetivosDestino')),
            blocoTexto('Rotinas', s('rotinas')),
            blocoTexto('Focos', s('focos')),
            if (ficha.maravilhas.isNotEmpty) ...[
              const Text('Maravilhas',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.dourado)),
              for (final m in ficha.maravilhas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${m['Nome']}: ${m['Descrição']}',
                      style: const TextStyle(color: Cores.tinta)),
                ),
              const SizedBox(height: 4),
            ],
            if (aparenciaCampos.isNotEmpty) ...[
              const Text('Aparência',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.dourado)),
              Wrap(
                spacing: 14,
                runSpacing: 2,
                children: [
                  for (final c in aparenciaCampos)
                    Text('${c[0]}: ${c[1]}',
                        style: const TextStyle(color: Cores.tinta)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            blocoTexto('Descrição', (ap['descricao'] ?? '').toString()),
            blocoTexto('Itens & Equipamentos', s('itensEquipamentos')),
            if (ficha.outrasCaracteristicas.isNotEmpty) ...[
              const Text('Outras Características',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.dourado)),
              for (final o in ficha.outrasCaracteristicas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${o['nome']}',
                              style: const TextStyle(color: Cores.tinta))),
                      _pontos((o['valor'] as num?)?.toInt() ?? 0, 5, tam: 18),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
            blocoTexto('Notas', s('notas')),
          ],
        ),
      ),
    );
  }

  // ---------- Combate ----------
  Widget _cardCombate(Ficha ficha) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in ficha.combate)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c['Arma/Manobra']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Cores.indigo)),
                    Text(
                        'Dif: ${c['Dif.']} · Dano: ${c['Dano']} · Tipo: ${c['Tipo']} · '
                        'Alcance: ${c['Alcance']} · Cadência: ${c['Cadência']}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Cores.tinta)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
