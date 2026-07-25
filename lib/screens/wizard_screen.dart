import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../models/ficha.dart';
import '../store/ficha_store.dart';
import '../theme.dart';
import '../widgets/dots.dart';

/// Assistente de criação de personagem — 7 passos.
///
/// Dois eixos independentes:
///
/// **Regras** (escolhível no ⚙ da barra, gravado na ficha em `modoLivre`):
///  * *Iniciante* — cada passo trava o Próximo até ficar perfeito.
///  * *Livre / mestre* — os limites viram AVISOS: dá pra ultrapassar
///    (evolução do personagem, ajuste do narrador). Ficha já pronta abre
///    nesse modo por padrão.
///
/// **Navegação**:
///  * criando — sequencial (Próximo destravado por etapa);
///  * editando a ficha inteira — abas no topo, pula pra qualquer etapa;
///  * `passos` com um subconjunto — edita e confirma só aquelas telas.
class WizardScreen extends StatefulWidget {
  /// Se vier uma ficha, edita; senão cria uma nova.
  final Ficha? existente;

  /// Índices das etapas desta sessão (null = todas, na ordem).
  final List<int>? passos;

  /// Sub-seções visíveis dentro das etapas (null = a etapa inteira).
  ///
  /// Vantagens & Defeitos: `positivos`, `defeitos`.
  /// Toques Finais: `bonusAtributos`, `bonusHabilidades`, `bonusEsferas`,
  /// `arete`, `forcaVontade`, `quintessencia`.
  final Set<String>? secoes;

  /// Título da barra quando se edita um pedaço só (ex.: 'Arete & Força de
  /// Vontade'). Sem isso vale o nome da etapa.
  final String? titulo;

  const WizardScreen({
    super.key,
    this.existente,
    this.passos,
    this.secoes,
    this.titulo,
  });

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen>
    with SingleTickerProviderStateMixin {
  late final Ficha f;
  late final TextEditingController _conceitoCtrl;
  late final List<int> _passos;
  late final TabController? _tab;
  int idx = 0; // posição DENTRO de _passos

  /// Regras frouxas (livre/mestre). Vem da ficha e pode ser trocado no ⚙.
  late bool _livre;

  static const _titulos = [
    'Identidade',
    'Atributos',
    'Habilidades',
    'Esferas',
    'Vantagens & Defeitos',
    'Toques Finais',
    'Detalhes',
  ];

  /// Nomes curtos pras abas.
  static const _abas = [
    'Identidade',
    'Atributos',
    'Habilidades',
    'Esferas',
    'Vant. & Def.',
    'Toques Finais',
    'Detalhes',
  ];

  /// Etapa real sendo exibida.
  int get page => _passos[idx];

  /// Está editando uma ficha que já existe.
  bool get _editando => widget.existente != null;

  /// Editando só um pedaço do wizard.
  bool get _parcial =>
      _passos.length < _titulos.length || widget.secoes != null;

  /// Esta sub-seção entra nesta sessão? (sem `secoes` = tudo entra)
  bool _mostra(String sec) =>
      widget.secoes == null || widget.secoes!.contains(sec);

  /// Placar/checklist das regras da criação. Some no modo livre: editando uma
  /// ficha pronta não há mais orçamento a fechar — sobe até o máximo do traço.
  bool get _mostraRegras => !_livre;

  /// Abas livres: só quando se edita a ficha inteira.
  bool get _comAbas => _editando && !_parcial;

  @override
  void initState() {
    super.initState();
    f = widget.existente ?? Ficha.criar();
    // Os 15 pontos de bônus (e o resto dos limites) são regra da CRIAÇÃO.
    // Editando uma ficha pronta nada trava — nem que o ⚙ dela tenha ficado
    // em "Iniciante" durante a criação. Criando, vale o modo gravado.
    _livre = _editando || f.modoLivre;
    _conceitoCtrl = TextEditingController(text: f.conceito);
    final p = widget.passos
        ?.where((i) => i >= 0 && i < _titulos.length)
        .toList();
    _passos = (p == null || p.isEmpty)
        ? List.generate(_titulos.length, (i) => i)
        : p;
    _tab = _comAbas
        ? (TabController(length: _passos.length, vsync: this)
          ..addListener(() {
            if (_tab!.index != idx) setState(() => idx = _tab.index);
          }))
        : null;
  }

  @override
  void dispose() {
    _conceitoCtrl.dispose();
    _tab?.dispose();
    super.dispose();
  }

  void _irPara(int novo) {
    setState(() => idx = novo);
    _tab?.animateTo(novo);
  }

  Future<void> _salvar() async {
    await FichaStore.salvar(f);
    if (!mounted) return;
    // Editando: volta pra ficha. Criando: volta pra lista de personagens.
    if (_editando) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_parcial ? 'Alterações salvas!' : 'Ficha salva!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _parcial
                ? (_passos.length == 1
                    ? 'Editar · ${widget.titulo ?? _titulos[page]}'
                    : 'Editar ${idx + 1}/${_passos.length} · ${_titulos[page]}')
                : (_comAbas
                    ? _titulos[page]
                    : '${idx + 1}/${_passos.length} · ${_titulos[page]}'),
            style: const TextStyle(fontSize: 16)),
        actions: [
          // Editando um pedaço da ficha não há regra de criação pra escolher.
          if (!_parcial) _menuModo(),
          if (_editando)
            IconButton(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              tooltip: 'Salvar e voltar',
            ),
        ],
        bottom: _tab == null
            ? null
            : TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Cores.dourado,
                labelColor: Cores.dourado,
                unselectedLabelColor: Cores.pergaminho,
                onTap: (i) => setState(() => idx = i),
                tabs: [for (final i in _passos) Tab(text: _abas[i])],
              ),
      ),
      body: Column(
        children: [
          if (_tab == null)
            LinearProgressIndicator(
              value: (idx + 1) / _passos.length,
              backgroundColor: Cores.pergaminhoEscuro,
              color: Cores.dourado,
            ),
          if (_livre) _avisoEvolucao(),
          Expanded(child: _paginaAtual()),
          _barraInferior(),
        ],
      ),
    );
  }

  /// ⚙ da barra: escolhe as regras que a ficha segue.
  Widget _menuModo() {
    return PopupMenuButton<bool>(
      icon: const Icon(Icons.rule),
      tooltip: 'Regras da ficha',
      color: Cores.pergaminho,
      onSelected: (v) => setState(() {
        _livre = v;
        f.modoLivre = v;
      }),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: false,
          checked: !_livre,
          child: const Text('Iniciante (regras da criação)'),
        ),
        CheckedPopupMenuItem(
          value: true,
          checked: _livre,
          child: const Text('Livre — evolução / mestre'),
        ),
      ],
    );
  }

  /// Faixa de aviso do modo livre.
  Widget _avisoEvolucao() {
    return Container(
      width: double.infinity,
      color: Cores.pergaminhoEscuro,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18, color: Cores.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _parcial
                  ? 'Edição livre: os 15 pontos de bônus e os limites da '
                      'criação não valem aqui — sobe até o máximo do traço.'
                  : 'Modo livre: os limites da criação viram avisos — dá pra '
                      'ultrapassar (evolução do personagem / ajuste do mestre). '
                      'Troque no ⚙ da barra.',
              style: const TextStyle(fontSize: 12, color: Cores.indigo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaAtual() {
    switch (page) {
      case 0:
        return _pgIdentidade();
      case 1:
        return _pgDistribuicao(
          bloco: GameData.atributos,
          valor: f.atributo,
          setValor: f.setAtributo,
        );
      case 2:
        return _pgTracos(
          bloco: GameData.habilidades,
          valor: f.habilidade,
          setValor: f.setHabilidade,
          prioridadeMapa: f.habilidadesPrioridade,
        );
      case 3:
        return _pgEsferas();
      case 4:
        return _pgVantagens();
      case 5:
        return _pgToquesFinais();
      default:
        return _pgDetalhes();
    }
  }

  /// Validação DURA de cada etapa — o botão Próximo só habilita quando
  /// a etapa está perfeita (Detalhes é a única totalmente opcional).
  /// No modo evolução nada trava: os placares continuam mostrando o excedido,
  /// mas em vermelho/aviso, sem impedir de salvar.
  bool _passoValido(int p) {
    if (_livre) return true;
    switch (p) {
      case 0: // Identidade: tudo obrigatório, exceto Crônica
        return f.nome.trim().isNotEmpty &&
            f.jogador.trim().isNotEmpty &&
            f.natureza.isNotEmpty &&
            f.comportamento.isNotEmpty &&
            f.essencia.isNotEmpty &&
            f.afiliacao.isNotEmpty &&
            f.faccao.isNotEmpty &&
            f.conceito.trim().isNotEmpty;
      case 1: // Atributos: 4-3-3-3-2-2-2-2-1 exato
        return _distribuicaoCompleta(GameData.atributos, f.atributo);
      case 2: // Habilidades: 15/11/9 exatos + especializações completas
        final pontosOk = _tracosCompletos(GameData.habilidades);
        final especOk = GameData.habilidades.categorias.every((c) =>
            f.especDaCategoria(c).length == f.especPermitidas(c.nome));
        return pontosOk && especOk;
      case 3: // Esferas: afinidade válida com ≥1 e os 6 pontos gastos
        final opcoes = GameData.opcoesAfinidade(f.faccao);
        final afinOk =
            f.afinidade.isNotEmpty && opcoes.contains(f.afinidade);
        return afinOk &&
            f.esfera(f.afinidade) >= 1 &&
            f.esferasGasto == GameData.esferasPontosGratuitos &&
            GameData.chavesEsferas
                .every((c) => f.esfera(c) <= GameData.esferasMaximoCriacao);
      case 4: // Vantagens & Defeitos: OPCIONAL (checklist da tela só orienta)
        return true;
      case 5: // Toques Finais: os 15 bônus gastos, sem sobra
        return f.bonusRestante == 0;
      default: // Detalhes: tudo opcional
        return true;
    }
  }

  /// Rótulo de botão que encolhe em vez de estourar a linha.
  Widget _rotulo(String t) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(t, maxLines: 1),
      );

  Widget _barraInferior() {
    final ultima = idx == _passos.length - 1;
    final valido = _passoValido(page);
    final rotulo = ultima
        ? (_parcial ? 'Salvar esta tela' : 'Salvar Ficha')
        : 'Próximo';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!valido && !ultima)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Complete esta etapa para continuar.',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Cores.indigoClaro),
                ),
              ),
            // Botões em Expanded + rótulo que encolhe: em tela estreita
            // ("Cancelar" + "Salvar esta tela") nada estoura pra fora.
            Row(
              children: [
                if (idx > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _irPara(idx - 1),
                      icon: const Icon(Icons.arrow_back),
                      label: _rotulo('Voltar'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Cores.indigo,
                          side: const BorderSide(color: Cores.indigo)),
                    ),
                  )
                else if (_parcial)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: _rotulo('Cancelar'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Cores.indigo,
                          side: const BorderSide(color: Cores.indigo)),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: ultima
                        ? _salvar
                        : (valido ? () => _irPara(idx + 1) : null),
                    icon: Icon(ultima ? Icons.save : Icons.arrow_forward),
                    label: _rotulo(rotulo),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Helpers de UI ----------

  Widget _texto(String label, String valor, ValueChanged<String> onCh,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: valor,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onCh,
      ),
    );
  }

  /// Tooltip padrão do app: aparece ao SEGURAR o dedo em cima do item.
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

  /// Campo que abre uma MODAL com as opções; segurar numa opção mostra a
  /// descrição em tooltip. Segurar no próprio campo mostra a descrição
  /// do item já selecionado.
  Widget _campoSeletor({
    required String label,
    required String valor,
    required List<ItemDescrito> opcoes,
    required ValueChanged<String> onSel,
    String? placeholder,
    bool habilitado = true,
  }) {
    final selDesc = valor.isEmpty
        ? ''
        : opcoes
            .firstWhere((o) => o.nome == valor,
                orElse: () => ItemDescrito(valor, ''))
            .descricao;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _dica(
        selDesc.isEmpty ? '' : '$valor — $selDesc',
        InkWell(
          onTap: !habilitado || opcoes.isEmpty
              ? null
              : () => _abrirSeletor(
                  titulo: label, opcoes: opcoes, atual: valor, onSel: onSel),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.expand_more, color: Cores.indigo),
            ),
            child: Text(
              valor.isEmpty ? (placeholder ?? 'Toque para escolher') : valor,
              style: TextStyle(
                  color: valor.isEmpty ? Colors.grey.shade600 : Cores.tinta),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSeletor({
    required String titulo,
    required List<ItemDescrito> opcoes,
    required String atual,
    required ValueChanged<String> onSel,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Cores.pergaminho,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (ctx, controller) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: Cores.dourado,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Cores.indigo)),
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 6),
              child: Text('Segure numa opção para ver a descrição',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
            const Divider(color: Cores.dourado, height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: opcoes.length,
                itemBuilder: (ctx, i) {
                  final o = opcoes[i];
                  final sel = o.nome == atual;
                  return _dica(
                    o.descricao,
                    ListTile(
                      dense: true,
                      title: Text(o.nome,
                          style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              color: sel ? Cores.indigo : Cores.tinta)),
                      trailing: sel
                          ? const Icon(Icons.check_circle,
                              color: Cores.dourado)
                          : null,
                      onTap: () {
                        onSel(o.nome);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Passo 1: Identidade ----------
  Widget _pgIdentidade() {
    final afiSel = GameData.afiliacaoPorNome(f.afiliacao);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FaixaSecao('Identidade'),
        _texto('Nome do personagem *', f.data['nome'],
            (v) => setState(() => f.data['nome'] = v)),
        _texto('Jogador *', f.data['jogador'],
            (v) => setState(() => f.data['jogador'] = v)),
        _texto('Crônica (opcional)', f.data['cronica'],
            (v) => f.data['cronica'] = v,
            hint: 'Nome da campanha / história'),

        const FaixaSecao('Personalidade'),
        _campoSeletor(
          label: 'Natureza',
          valor: f.natureza,
          opcoes: GameData.naturezas,
          onSel: (v) => setState(() => f.data['natureza'] = v),
        ),
        _campoSeletor(
          label: 'Comportamento',
          valor: f.comportamento,
          opcoes: GameData.comportamentos,
          onSel: (v) => setState(() => f.data['comportamento'] = v),
        ),
        _campoSeletor(
          label: 'Essência',
          valor: f.essencia,
          opcoes: GameData.essencias,
          onSel: (v) => setState(() => f.data['essencia'] = v),
        ),

        const FaixaSecao('Afiliação'),
        _campoSeletor(
          label: 'Afiliação',
          valor: f.afiliacao,
          opcoes: [
            for (final a in GameData.afiliacoes)
              ItemDescrito(
                  a.nome,
                  '${a.descricao}\n\n'
                  '${a.faccoes.length == 1 ? 'Sem subdivisão.' : '${a.faccoes.length} facções: '
                      '${a.faccoes.map((fc) => fc.nome).join(' · ')}'}'),
          ],
          onSel: (v) => setState(() {
            f.data['afiliacao'] = v;
            final a = GameData.afiliacaoPorNome(v);
            // afiliação sem subdivisão (Nefandi, Órfão, Desauridos): já escolhe
            f.data['faccao'] =
                (a != null && a.faccoes.length == 1) ? a.faccoes.first.nome : '';
          }),
        ),
        _campoSeletor(
          label: afiSel == null || afiSel.faccoes.length == 1
              ? 'Facção'
              : 'Facção (${afiSel.faccoes.length} opções)',
          valor: f.faccao,
          opcoes: [
            for (final fc in afiSel?.faccoes ?? const <Faccao>[])
              ItemDescrito(fc.nome, fc.resumo),
          ],
          habilitado: afiSel != null,
          placeholder: afiSel == null
              ? 'Escolha a afiliação primeiro'
              : 'Toque para escolher',
          onSel: (v) => setState(() => f.data['faccao'] = v),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 4),
          child: Text(
            afiSel == null
                ? 'Afiliação é o grande grupo (Tradições, Tecnocracia, '
                    'Discrepantes…); Facção é a casa dentro dele.'
                : (afiSel.faccoes.length == 1
                    ? '${afiSel.nome} não se divide em facções — a facção já foi preenchida.'
                    : 'Segure numa facção para ver o resumo dela.'),
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),

        const FaixaSecao('Conceito'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: _conceitoCtrl,
            decoration: const InputDecoration(
              labelText: 'Conceito *',
              hintText: 'Ex.: Detetive paranormal, Cientista renegado...',
            ),
            onChanged: (v) => setState(() => f.data['conceito'] = v),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 6, left: 4),
          child: Text(
            'Sugestões (toque para usar; segure para ver exemplos) — '
            'a lista não é fechada, crie o seu:',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final c in GameData.conceitos)
              _dica(
                c.exemplos,
                ActionChip(
                  label: Text(c.nome, style: const TextStyle(fontSize: 12)),
                  backgroundColor: _conceitoCtrl.text == c.nome
                      ? Cores.dourado
                      : Cores.pergaminho,
                  side: const BorderSide(color: Cores.dourado),
                  onPressed: () => setState(() {
                    _conceitoCtrl.text = c.nome;
                    f.data['conceito'] = c.nome;
                  }),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------- Passos 2 e 3: Traços por prioridade (Atributos / Habilidades) ----------

  /// Troca a prioridade de [catNome] para [novaChave], mantendo a bijeção
  /// (a categoria que tinha essa prioridade recebe a prioridade antiga).
  void _trocarPrioridade(
      Map<String, dynamic> mapa, String catNome, String novaChave) {
    final atual = mapa[catNome] as String?;
    if (atual == novaChave) return;
    String? outra;
    mapa.forEach((k, v) {
      if (v == novaChave) outra = k;
    });
    if (outra != null && atual != null) mapa[outra!] = atual;
    mapa[catNome] = novaChave;
    setState(() {});
  }

  /// Ok = cada coluna gastou exatamente o orçamento da sua prioridade
  /// (contando as habilidades personalizadas).
  bool _tracosCompletos(BlocoTracos bloco) => bloco.categorias
      .every((c) => f.gastoHabilidades(c) == f.orcamentoHabilidades(c.nome));

  // ---------- Modo distribuição (Atributos: 4-3-3-3-2-2-2-2-1) ----------
  Map<int, int> _contagemValores(BlocoTracos bloco, int Function(String) valor) {
    final m = <int, int>{};
    for (final n in bloco.nomes) {
      final v = valor(n);
      m[v] = (m[v] ?? 0) + 1;
    }
    return m;
  }

  bool _distribuicaoCompleta(BlocoTracos bloco, int Function(String) valor) {
    final atual = _contagemValores(bloco, valor);
    return bloco.regra.distribuicao
        .every((d) => (atual[d.key] ?? 0) == d.value);
  }

  Widget _pgDistribuicao({
    required BlocoTracos bloco,
    required int Function(String) valor,
    required void Function(String, int) setValor,
  }) {
    final regra = bloco.regra;
    final atual = _contagemValores(bloco, valor);
    final ok = _distribuicaoCompleta(bloco, valor);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mostraRegras)
          Card(
            color: ok ? const Color(0xFFE4EFD8) : Cores.pergaminhoEscuro,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(ok ? Icons.check_circle : Icons.tune,
                        color: ok ? Colors.green.shade700 : Cores.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ok
                            ? 'Distribuição correta!'
                            : 'Distribua 4 · 3 · 3 · 3 · 2 · 2 · 2 · 2 · 1',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ok ? Colors.green.shade800 : Cores.indigo),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (final d in regra.distribuicao)
                        _metaChip(d.key, atual[d.key] ?? 0, d.value),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(regra.texto,
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          ),
        for (final cat in bloco.categorias)
          Column(
            children: [
              FaixaSecao(cat.nome),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    children: [
                      for (final tr in cat.tracos)
                        _linhaTraco(tr, regra, valor, setValor),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _metaChip(int valor, int atual, int meta) {
    final feito = atual == meta;
    final cor = feito
        ? Colors.green.shade700
        : (atual > meta ? Colors.red.shade700 : Cores.tinta);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Cores.pergaminho,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feito ? Colors.green : Cores.dourado),
      ),
      child: Text('Valor $valor:  $atual / $meta',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
    );
  }

  Widget _pgTracos({
    required BlocoTracos bloco,
    required int Function(String) valor,
    required void Function(String, int) setValor,
    required Map<String, dynamic> prioridadeMapa,
  }) {
    final regra = bloco.regra;
    final tudoOk = _tracosCompletos(bloco);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mostraRegras)
          Card(
            color: tudoOk ? const Color(0xFFE4EFD8) : Cores.pergaminhoEscuro,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(tudoOk ? Icons.check_circle : Icons.tune,
                        color: tudoOk ? Colors.green.shade700 : Cores.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tudoOk
                            ? 'Distribuição completa!'
                            : 'Defina a prioridade de cada categoria e distribua',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                tudoOk ? Colors.green.shade800 : Cores.indigo),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (final p in regra.prioridades) _chipPrioridade(p),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(regra.texto,
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          ),
        for (final cat in bloco.categorias)
          _cardCategoriaTracos(cat, regra, valor, setValor, prioridadeMapa),
      ],
    );
  }

  Widget _chipPrioridade(Prioridade p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Cores.pergaminho,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Cores.dourado),
      ),
      child: Text('${p.nome}: ${p.pontos} pts',
          style:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _cardCategoriaTracos(
    Categoria cat,
    RegraPrioridade regra,
    int Function(String) valor,
    void Function(String, int) setValor,
    Map<String, dynamic> prioridadeMapa,
  ) {
    final chave = prioridadeMapa[cat.nome] as String? ?? '';
    final orcamento = regra.pontosDe(chave);
    final gasto = f.gastoHabilidades(cat);
    final over = gasto > orcamento;
    final completo = gasto == orcamento;
    final extras = f.extrasDaCategoria(cat.nome);

    return Column(
      children: [
        FaixaSecao(cat.nome),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final p in regra.prioridades)
                      ChoiceChip(
                        label:
                            Text(p.nome, style: const TextStyle(fontSize: 12)),
                        selected: chave == p.chave,
                        selectedColor: Cores.indigo,
                        backgroundColor: Cores.pergaminho,
                        labelStyle: TextStyle(
                            color: chave == p.chave
                                ? Cores.pergaminho
                                : Cores.tinta),
                        side: const BorderSide(color: Cores.dourado),
                        onSelected: (_) => _trocarPrioridade(
                            prioridadeMapa, cat.nome, p.chave),
                      ),
                  ],
                ),
                if (_mostraRegras)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      'Distribuídos: $gasto / $orcamento'
                      '${over ? '  ⚠ excedido' : (completo ? '  ✓' : '')}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: over
                              ? Colors.red.shade800
                              : (completo
                                  ? Colors.green.shade800
                                  : Cores.indigo)),
                    ),
                  ),
                const Divider(color: Cores.dourado, height: 12),
                for (final tr in cat.tracos)
                  _linhaTraco(tr, regra, valor, setValor),
                if (extras.isNotEmpty) ...[
                  const Divider(color: Cores.dourado, height: 12),
                  const Text('Personalizadas (opcionais do livro)',
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Cores.indigoClaro)),
                  for (final tr in extras)
                    _linhaTraco(tr, regra, valor, setValor,
                        onRemover: () => _removerHabilidadeExtra(tr.nome)),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addHabilidadeExtra(cat),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Habilidade personalizada'),
                  ),
                ),
                if (regra.prioridades.any((p) => p.especializacoes > 0))
                  _secaoEspecializacoes(cat, regra.especDe(chave)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Especializações da categoria (quantidade dada pela prioridade da coluna).
  Widget _secaoEspecializacoes(Categoria cat, int permitidas) {
    final usadas = f.especDaCategoria(cat);
    final over = usadas.length > permitidas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Cores.dourado, height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Especializações: ${usadas.length} / $permitidas'
                '${over ? '  ⚠ excedido' : ''}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: over ? Colors.red.shade800 : Cores.indigo),
              ),
            ),
            if (permitidas > 0 || _livre)
              TextButton.icon(
                onPressed: (!_livre && usadas.length >= permitidas)
                    ? null
                    : () => _addEspecializacao(cat),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
          ],
        ),
        if (permitidas == 0)
          const Text('Esta coluna não recebe especialização.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
        else if (usadas.isEmpty)
          const Text(
              'Ex.: Armas de Fogo: revólveres · Ocultismo: fantasmas',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final e in usadas)
              Chip(
                label: Text('${e['habilidade']}: ${e['nome']}',
                    style: const TextStyle(fontSize: 12)),
                backgroundColor: Cores.pergaminho,
                side: const BorderSide(color: Cores.dourado),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(
                    () => f.especializacoes.remove(e)),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addEspecializacao(Categoria cat) async {
    // só habilidades da coluna (padrão + personalizadas) com pelo menos 1 ponto
    final opcoes = f
        .tracosDaCategoria(cat)
        .where((t) => f.habilidade(t.nome) >= 1)
        .toList();
    if (opcoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Coloque pontos em uma Habilidade desta coluna primeiro.')));
      return;
    }
    String hab = opcoes.first.nome;
    final nomeCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: Text('Especialização — ${cat.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: hab,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Habilidade'),
                items: [
                  for (final t in opcoes)
                    DropdownMenuItem(
                        value: t.nome,
                        child: Text('${t.nome} (${f.habilidade(t.nome)})')),
                ],
                onChanged: (v) => setL(() => hab = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Especialização',
                    hintText: 'Ex.: revólveres, fantasmas, blefe...'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nomeCtrl.text.trim().isEmpty) return;
                setState(() => f.adicionar('especializacoes',
                    {'habilidade': hab, 'nome': nomeCtrl.text.trim()}));
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      }),
    );
  }

  Widget _linhaTraco(
    ItemDescrito tr,
    RegraPrioridade regra,
    int Function(String) valor,
    void Function(String, int) setValor, {
    VoidCallback? onRemover,
  }) {
    final v = valor(tr.nome);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _dica(
              '${tr.nome} — ${tr.descricao}',
              Text(tr.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.tinta)),
            ),
          ),
          LinhaBolinhas(
            valor: v,
            max: regra.maximo,
            min: regra.valorInicial,
            // Evolução: o teto da criação (3) some — vale o máximo absoluto.
            maxInterativo: _livre ? regra.maximo : regra.maximoCriacao,
            onChanged: (nv) => setState(() => setValor(tr.nome, nv)),
          ),
          SizedBox(
            width: 20,
            child: Text('$v',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          if (onRemover != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Cores.indigoClaro),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remover habilidade personalizada',
              onPressed: onRemover,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Cria uma Habilidade que não está na lista padrão da ficha (o livro traz
  /// várias opcionais). Ela vive na mesma coluna e gasta os mesmos pontos.
  Future<void> _addHabilidadeExtra(Categoria cat) async {
    final nomeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? erro;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: Text('Habilidade personalizada — ${cat.nome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para as Habilidades opcionais do livro que não estão na '
                  'ficha padrão. Ela entra nesta coluna e gasta os mesmos '
                  'pontos das outras.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nomeCtrl,
                  decoration: InputDecoration(
                      labelText: 'Nome *', errorText: erro),
                  onChanged: (_) => setL(() => erro = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Descrição (aparece ao segurar o dedo)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) {
                  setL(() => erro = 'Dê um nome à Habilidade.');
                  return;
                }
                final existe = f.nomesHabilidades
                    .any((n) => n.toLowerCase() == nome.toLowerCase());
                if (existe) {
                  setL(() => erro = 'Já existe uma Habilidade com esse nome.');
                  return;
                }
                setState(() =>
                    f.addHabilidadeExtra(cat.nome, nome, descCtrl.text.trim()));
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _removerHabilidadeExtra(String nome) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Remover habilidade?'),
        content: Text(
            'Remover "$nome" apaga também os pontos, bônus e especializações '
            'dela.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok == true) setState(() => f.removerHabilidadeExtra(nome));
  }

  // ---------- Passo 4: Esferas ----------
  Widget _checklist(bool ok, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: ok ? Colors.green.shade700 : Cores.indigoClaro),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _pgEsferas() {
    final faccao = f.faccao;
    final opcoes = GameData.opcoesAfinidade(faccao);
    final bloqueadas = GameData.esferasBloqueadas(faccao);
    final teto = GameData.esferasMaximoCriacao; // iniciantes: máx 3 por Esfera
    final grat = GameData.esferasPontosGratuitos;

    // Zera silenciosamente Esferas bloqueadas (ex.: Entropia p/ Ahl-i-Batin).
    // Na evolução não mexe: só avisa — quem já jogou pode ter mudado de rumo.
    if (!_livre) {
      for (final c in bloqueadas) {
        if (f.esfera(c) != 0) f.setEsfera(c, 0);
      }
    }

    final afin = opcoes.contains(f.afinidade) ? f.afinidade : null;
    final gasto = f.esferasGasto;
    final afinComPonto = afin != null && f.esfera(afin) >= 1;
    final somaOk = gasto == grat;
    final nenhumaAcimaTeto =
        GameData.chavesEsferas.every((c) => f.esferaFinal(c) <= teto);
    final tudoOk = afin != null && afinComPonto && somaOk && nenhumaAcimaTeto;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FaixaSecao('Esfera de Afinidade'),
        _campoSeletor(
          label: 'Afinidade',
          valor: GameData.esferaPorChave(afin)?.nome ?? '',
          opcoes: [
            for (final c in opcoes)
              ItemDescrito(GameData.esferaPorChave(c)?.nome ?? c,
                  GameData.esferaPorChave(c)?.descricao ?? ''),
          ],
          habilitado: faccao.isNotEmpty,
          placeholder: faccao.isEmpty
              ? 'Defina a Facção na 1ª tela'
              : 'Toque para escolher',
          onSel: (nome) => setState(() {
            final chave = GameData.esferas
                .firstWhere((e) => e.nome == nome,
                    orElse: () => GameData.esferas.first)
                .chave;
            f.afinidade = chave;
            if (f.esfera(chave) < 1) f.setEsfera(chave, 1);
          }),
        ),
        Text(
          faccao.isEmpty
              ? 'Sem Facção definida — todas as Esferas ficam disponíveis como Afinidade.'
              : 'Facção: $faccao — opções: '
                  '${opcoes.map((c) => GameData.esferaPorChave(c)?.nome ?? c).join(', ')}.',
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        if (_mostraRegras)
          Card(
            color: tudoOk ? const Color(0xFFE4EFD8) : Cores.pergaminhoEscuro,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pontos grátis: $gasto / $grat',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: gasto > grat
                              ? Colors.red.shade800
                              : (somaOk
                                  ? Colors.green.shade800
                                  : Cores.indigo))),
                  const SizedBox(height: 6),
                  _checklist(afin != null, 'Afinidade selecionada'),
                  _checklist(afinComPonto, 'Afinidade com pelo menos 1 ponto'),
                  _checklist(somaOk, 'Soma dos pontos de Esfera = $grat'),
                  _checklist(nenhumaAcimaTeto,
                      'Nenhuma Esfera acima de $teto (limite de iniciante)'),
                  const SizedBox(height: 6),
                  Text(GameData.esferasRegraTexto,
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          ),
        const FaixaSecao('Esferas'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              children: [
                for (final e in GameData.esferas)
                  _linhaEsfera(e, teto, afin, bloqueadas.contains(e.chave)),
              ],
            ),
          ),
        ),
        const FaixaSecao('Vantagens'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _linhaBase('Arete',
                    '${f.areteFinal}${f.bonusArete > 0 ? '  (1 + ${f.bonusArete} bônus)' : ''}'),
                _linhaBase('Força de Vontade',
                    '${f.forcaVontadeFinal}${f.bonusForcaVontade > 0 ? '  (5 + ${f.bonusForcaVontade} bônus)' : ''}'),
                _linhaBase('Quintessência',
                    '${f.quintessencia}   (= Avatar ${f.avatar}${f.bonusQuintessencia > 0 ? ' + ${f.bonusQuintessencia}×4' : ''})'),
                _linhaBase('Paradoxo', '${f.paradoxo}'),
                const SizedBox(height: 6),
                Text(
                  _livre
                      ? 'Arete, Força de Vontade e Quintessência sobem no passo '
                          'Toques Finais.'
                      : 'Arete (máx 3), Força de Vontade (até 10) e Quintessência '
                          'sobem no passo Toques Finais, com os 15 pontos de bônus.',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linhaEsfera(Esfera e, int teto, String? afin, bool bloqueada) {
    final v = f.esfera(e.chave);
    final ehAfin = afin == e.chave;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: ehAfin
                ? const Icon(Icons.star, size: 16, color: Cores.dourado)
                : (bloqueada
                    ? const Icon(Icons.block, size: 15, color: Colors.grey)
                    : null),
          ),
          Expanded(
            child: _dica(
              '${e.nome} — ${e.descricao}'
              '${bloqueada ? '\n\n⚠ Bloqueada para a sua Facção.' : ''}',
              Text(e.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: bloqueada ? Colors.grey : Cores.tinta)),
            ),
          ),
          LinhaBolinhas(
            valor: v,
            max: 5,
            min: ehAfin ? 1 : 0,
            // Evolução: sem teto de iniciante (e Esfera bloqueada só avisa).
            maxInterativo: _livre ? 5 : (bloqueada ? 0 : teto),
            onChanged: (nv) => setState(() => f.setEsfera(e.chave, nv)),
          ),
          SizedBox(
            width: 20,
            child: Text('$v',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _linhaBase(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Cores.indigo)),
          ),
          Expanded(
              child: Text(valor, style: const TextStyle(color: Cores.tinta))),
        ],
      ),
    );
  }

  // ---------- Passo 5: Antecedentes/Qualidades & Defeitos ----------
  ButtonStyle _outlined() => OutlinedButton.styleFrom(
      foregroundColor: Cores.indigo,
      side: const BorderSide(color: Cores.indigo));

  Widget _stepper(int v, int min, int max, ValueChanged<int> onCh) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: v > min ? () => onCh(v - 1) : null),
          SizedBox(
              width: 26,
              child: Text('$v',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: v < max ? () => onCh(v + 1) : null),
        ],
      );

  Widget _placar(String titulo, String itens, String pts) => Column(
        children: [
          Text(titulo,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Cores.indigo)),
          Text(pts,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Cores.indigo)),
          Text(itens, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _pgVantagens() {
    final pos = f.positivos;
    final defs = f.defeitos;
    final gen = f.defeitosGeneticos;
    final totPos = f.totalPositivo;
    final totDef = f.totalDefeito;

    // Máximo de 4 características em CADA categoria (regra da mesa).
    final nAntec =
        pos.where((e) => e['classe'] == 'antecedente').length;
    final nQual = pos.where((e) => e['classe'] == 'qualidade').length;
    final okAntec = nAntec <= 4;
    final okQual = nQual <= 4;
    final okDef = defs.length <= 4;
    final okIgual = totPos == totDef;
    final temAvatar = f.avatar >= 1;

    var aprim = 0;
    for (final e in pos) {
      if (e['nome'] == 'Aprimoramento') {
        aprim += (e['sel'] as num?)?.toInt() ?? 0;
      }
    }
    final okAprim = aprim == 0 || (gen.length + f.paradoxo) >= aprim;

    final conflitoBer = pos.any((e) => e['nome'] == 'Berserker') &&
        defs.any((e) => e['nome'] == 'Atavismo de Estresse');

    final tudoOk = okAntec &&
        okQual &&
        okDef &&
        okIgual &&
        temAvatar &&
        okAprim &&
        !conflitoBer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mostraRegras)
          Card(
            color: tudoOk ? const Color(0xFFE4EFD8) : Cores.pergaminhoEscuro,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _placar('Positivos', '${pos.length} itens', '$totPos pts')),
                      Container(width: 1, height: 44, color: Cores.dourado),
                      Expanded(child: _placar('Defeitos', '${defs.length} itens', '$totDef pts')),
                    ],
                  ),
                  const Divider(color: Cores.dourado),
                  _checklist(okAntec, 'Máximo 4 Antecedentes ($nAntec/4)'),
                  _checklist(okQual, 'Máximo 4 Qualidades ($nQual/4)'),
                  _checklist(okDef, 'Máximo 4 Defeitos (${defs.length}/4)'),
                  _checklist(okIgual,
                      'Equilíbrio de intensidade: Defeitos = positivos  ($totDef / $totPos pts)'),
                  _checklist(temAvatar, 'Avatar/Gênio pelo menos 1'),
                  if (aprim > 0)
                    _checklist(
                        okAprim,
                        'Aprimoramento $aprim: precisa de $aprim Defeito(s) '
                        'Genético(s) ou Paradoxo (tem ${gen.length + f.paradoxo})'),
                  if (conflitoBer)
                    _checklist(false,
                        'Berserker e Atavismo de Estresse são a mesma coisa — remova um'),
                  const SizedBox(height: 4),
                  const Text(
                    'Antecedentes + Qualidades = positivos. Defeitos só equilibram '
                    '(não dão os 15 pontos de bônus). Máximo 4 de cada categoria.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        if (_mostra('positivos')) ...[
          const FaixaSecao('Antecedentes & Qualidades'),
          if (pos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'Nenhum ainda. Adicione Antecedentes e/ou Qualidades.',
                  textAlign: TextAlign.center),
            ),
          for (int i = 0; i < pos.length; i++) _cartaoPositivo(pos[i], i),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => _addAntecedente(),
                    icon: const Icon(Icons.add),
                    label: const Text('Antecedente'),
                    style: _outlined()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => _addQualidade(),
                    icon: const Icon(Icons.add),
                    label: const Text('Qualidade'),
                    style: _outlined()),
              ),
            ],
          ),
        ],
        if (_mostra('defeitos')) ...[
          const FaixaSecao('Defeitos'),
          if (defs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhum ainda. Adicione pelo menos 2 Defeitos.',
                  textAlign: TextAlign.center),
            ),
          for (int i = 0; i < defs.length; i++) _cartaoDefeito(defs[i], i),
          OutlinedButton.icon(
              onPressed: () => _addDefeito(),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Defeito'),
              style: _outlined()),
          const FaixaSecao('Defeitos Genéticos (Aprimoramento)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(GameData.defeitosGeneticosTexto,
                style: const TextStyle(fontSize: 11.5)),
          ),
          for (int i = 0; i < gen.length; i++)
            Card(
              child: ListTile(
                dense: true,
                title: Text('${gen[i]['nome']}'),
                subtitle: const Text('Valor 0 — não entra na soma'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Cores.indigoClaro),
                  onPressed: () =>
                      setState(() => f.remover('defeitosGeneticos', i)),
                ),
              ),
            ),
          OutlinedButton.icon(
              onPressed: _addGenetico,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Defeito Genético'),
              style: _outlined()),
        ],
      ],
    );
  }

  /// Resumo (para o tooltip de segurar) de uma entrada positiva/defeito.
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

  Widget _cartaoPositivo(Map<String, dynamic> e, int i) {
    final custo = GameData.custoPositivo(e);
    final classe = e['classe'] == 'antecedente' ? 'Antecedente' : 'Qualidade';
    final detalhe = (e['detalhe'] ?? '') as String;
    final sub = [
      classe,
      if (e['custom'] == true) 'personalizado',
      if (e['classe'] == 'antecedente') 'grad ${e['sel']}',
      if (detalhe.isNotEmpty) detalhe,
    ].join(' · ');
    return _dica(
      '${e['nome']} — ${_resumoPositivo(e)}',
      Card(
        child: ListTile(
          dense: true,
          title: Text('${e['nome']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(sub),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$custo pts',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Cores.indigoClaro),
                onPressed: () => setState(() => f.remover('positivos', i)),
              ),
            ],
          ),
          onTap: () => e['classe'] == 'antecedente'
              ? _addAntecedente(edit: e)
              : _addQualidade(edit: e),
        ),
      ),
    );
  }

  Widget _cartaoDefeito(Map<String, dynamic> e, int i) {
    final custo = GameData.custoDefeito(e);
    final detalhe = (e['detalhe'] ?? '') as String;
    final subtipo = (e['subtipo'] ?? '') as String;
    final sub = [
      if (e['custom'] == true) 'personalizado',
      if (subtipo.isNotEmpty) subtipo,
      if (detalhe.isNotEmpty) detalhe,
    ].join(' · ');
    return _dica(
      '${e['nome']} — ${_resumoDefeito(e)}',
      Card(
        child: ListTile(
          dense: true,
          title: Text('${e['nome']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: sub.isEmpty ? null : Text(sub),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$custo pts',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Cores.indigoClaro),
                onPressed: () => setState(() => f.remover('defeitos', i)),
              ),
            ],
          ),
          onTap: () => _addDefeito(edit: e),
        ),
      ),
    );
  }

  /// Campo de escolha dentro dos diálogos: abre o seletor em modal
  /// (segurar numa opção mostra a descrição).
  Widget _campoDialogo({
    required String label,
    required String valor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.expand_more, color: Cores.indigo),
        ),
        child: Text(
          valor.isEmpty ? 'Toque para escolher' : valor,
          style: TextStyle(
              color: valor.isEmpty ? Colors.grey.shade600 : Cores.tinta),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static const _kCustom = 'Personalizado…';

  static ItemDescrito get _opcaoCustom => ItemDescrito(_kCustom,
      'Crie o seu próprio, com nome, descrição e pontos definidos por você (combine com o Narrador).');

  Future<void> _addAntecedente({Map<String, dynamic>? edit}) async {
    Antecedente? sel = edit != null && edit['custom'] != true
        ? GameData.antecedentePorNome(edit['nome'] as String?)
        : null;
    bool custom = edit?['custom'] == true;
    int grad = (edit?['sel'] as num?)?.toInt() ?? 1;
    final detalheCtrl =
        TextEditingController(text: (edit?['detalhe'] ?? '') as String);
    final nomeCtrl = TextEditingController(
        text: custom ? (edit?['nome'] ?? '') as String : '');
    final descCtrl = TextEditingController(
        text: custom ? (edit?['descricao'] ?? '') as String : '');
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        final ehTec = f.afiliacao == 'Tecnocracia';
        final custo = custom ? grad : (sel == null ? 0 : sel!.custo(grad));
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: Text(
              edit == null ? 'Adicionar Antecedente' : 'Editar Antecedente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campoDialogo(
                  label: 'Antecedente',
                  valor: custom ? _kCustom : (sel?.nome ?? ''),
                  onTap: () => _abrirSeletor(
                    titulo: 'Antecedente',
                    opcoes: [
                      for (final a in GameData.antecedentes)
                        ItemDescrito(
                            a.nome +
                                (a.dobrado ? '  (×2)' : '') +
                                (a.restrito ? '  ⚙' : ''),
                            a.resumo),
                      _opcaoCustom,
                    ],
                    atual: custom
                        ? _kCustom
                        : (sel == null
                            ? ''
                            : sel!.nome +
                                (sel!.dobrado ? '  (×2)' : '') +
                                (sel!.restrito ? '  ⚙' : '')),
                    onSel: (n) => setL(() {
                      if (n == _kCustom) {
                        custom = true;
                        sel = null;
                      } else {
                        custom = false;
                        final limpo =
                            n.replaceAll('  (×2)', '').replaceAll('  ⚙', '');
                        sel = GameData.antecedentePorNome(limpo);
                        if (grad < 1) grad = 1;
                      }
                    }),
                  ),
                ),
                if (custom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                    onChanged: (_) => setL(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                  ),
                ] else if (sel != null) ...[
                  const SizedBox(height: 8),
                  Text(sel!.resumo, style: const TextStyle(fontSize: 12.5)),
                  if (sel!.restrito && !ehTec)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('⚠ Normalmente exclusivo da Tecnocracia.',
                          style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  if (sel!.avatar)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Todo mago precisa de Avatar ≥ 1. Define a Quintessência inicial.',
                          style: TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                ],
                if (custom || sel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Graduação: '),
                      _stepper(grad, 1, 5, (nv) => setL(() => grad = nv)),
                    ],
                  ),
                  if (!custom)
                    TextField(
                      controller: detalheCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Detalhe (opcional)'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                      'Custo: $custo pontos positivos'
                      '${!custom && (sel?.dobrado ?? false) ? '  (grad ×2)' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Cores.indigo)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: (custom
                      ? nomeCtrl.text.trim().isEmpty
                      : sel == null)
                  ? null
                  : () {
                      setState(() {
                        final dados = custom
                            ? {
                                'classe': 'antecedente',
                                'nome': nomeCtrl.text.trim(),
                                'sel': grad,
                                'detalhe': '',
                                'custom': true,
                                'descricao': descCtrl.text.trim(),
                              }
                            : {
                                'classe': 'antecedente',
                                'nome': sel!.nome,
                                'sel': grad,
                                'detalhe': detalheCtrl.text,
                                'custom': false,
                                'descricao': '',
                              };
                        if (edit != null) {
                          edit
                            ..clear()
                            ..addAll(dados);
                        } else {
                          f.adicionar('positivos', dados);
                        }
                      });
                      Navigator.pop(context);
                    },
              child: Text(edit == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _addQualidade({Map<String, dynamic>? edit}) async {
    Qualidade? sel = edit != null && edit['custom'] != true
        ? GameData.qualidadePorNome(edit['nome'] as String?)
        : null;
    bool custom = edit?['custom'] == true;
    int selVal =
        (edit?['sel'] as num?)?.toInt() ?? (sel?.custoSpec.selInicial ?? 1);
    final detalheCtrl =
        TextEditingController(text: (edit?['detalhe'] ?? '') as String);
    final nomeCtrl = TextEditingController(
        text: custom ? (edit?['nome'] ?? '') as String : '');
    final descCtrl = TextEditingController(
        text: custom ? (edit?['descricao'] ?? '') as String : '');
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        final spec = sel?.custoSpec;
        final custo =
            custom ? selVal : (spec == null ? 0 : spec.custo(selVal));
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title:
              Text(edit == null ? 'Adicionar Qualidade' : 'Editar Qualidade'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campoDialogo(
                  label: 'Qualidade',
                  valor: custom ? _kCustom : (sel?.nome ?? ''),
                  onTap: () => _abrirSeletor(
                    titulo: 'Qualidade',
                    opcoes: [
                      for (final q in GameData.qualidades)
                        ItemDescrito(q.nome, q.resumo),
                      _opcaoCustom,
                    ],
                    atual: custom ? _kCustom : (sel?.nome ?? ''),
                    onSel: (n) => setL(() {
                      if (n == _kCustom) {
                        custom = true;
                        sel = null;
                        if (selVal < 1) selVal = 1;
                      } else {
                        custom = false;
                        sel = GameData.qualidadePorNome(n);
                        selVal = sel!.custoSpec.selInicial;
                      }
                    }),
                  ),
                ),
                if (custom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                    onChanged: (_) => setL(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Custo: '),
                      _stepper(selVal, 1, 10, (nv) => setL(() => selVal = nv)),
                    ],
                  ),
                ] else if (sel != null && spec != null) ...[
                  const SizedBox(height: 8),
                  Text(sel!.resumo, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 8),
                  if (spec.tipo == 'opcoes')
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final val in spec.valores)
                          ChoiceChip(
                            label: Text('$val pts'),
                            selected: selVal == val,
                            selectedColor: Cores.indigo,
                            backgroundColor: Cores.pergaminhoEscuro,
                            labelStyle: TextStyle(
                                color: selVal == val
                                    ? Cores.pergaminho
                                    : Cores.tinta),
                            onSelected: (_) => setL(() => selVal = val),
                          ),
                      ],
                    )
                  else if (spec.tipo == 'porPonto')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Graduação: '),
                        _stepper(selVal, spec.min, spec.max,
                            (nv) => setL(() => selVal = nv)),
                        Text('  (${spec.unidade}/ponto)'),
                      ],
                    ),
                  if (spec.rotulo.isNotEmpty || spec.tipo == 'fixo')
                    TextField(
                      controller: detalheCtrl,
                      decoration: InputDecoration(
                          labelText: spec.rotulo.isNotEmpty
                              ? spec.rotulo
                              : 'Detalhe (opcional)'),
                    ),
                ],
                if (custom || sel != null) ...[
                  const SizedBox(height: 8),
                  Text('Custo: $custo pontos positivos',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Cores.indigo)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: (custom
                      ? nomeCtrl.text.trim().isEmpty
                      : sel == null)
                  ? null
                  : () {
                      setState(() {
                        final dados = custom
                            ? {
                                'classe': 'qualidade',
                                'nome': nomeCtrl.text.trim(),
                                'sel': selVal,
                                'detalhe': '',
                                'custom': true,
                                'descricao': descCtrl.text.trim(),
                              }
                            : {
                                'classe': 'qualidade',
                                'nome': sel!.nome,
                                'sel': selVal,
                                'detalhe': detalheCtrl.text,
                                'custom': false,
                                'descricao': '',
                              };
                        if (edit != null) {
                          edit
                            ..clear()
                            ..addAll(dados);
                        } else {
                          f.adicionar('positivos', dados);
                        }
                      });
                      Navigator.pop(context);
                    },
              child: Text(edit == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _addDefeito({Map<String, dynamic>? edit}) async {
    Defeito? sel = edit != null && edit['custom'] != true
        ? GameData.defeitoPorNome(edit['nome'] as String?)
        : null;
    bool custom = edit?['custom'] == true;
    int selVal =
        (edit?['sel'] as num?)?.toInt() ?? (sel?.custoSpec.selInicial ?? 1);
    String? subtipo = edit?['subtipo'] as String?;
    final detalheCtrl =
        TextEditingController(text: (edit?['detalhe'] ?? '') as String);
    final nomeCtrl = TextEditingController(
        text: custom ? (edit?['nome'] ?? '') as String : '');
    final descCtrl = TextEditingController(
        text: custom ? (edit?['descricao'] ?? '') as String : '');
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        final spec = sel?.custoSpec;
        final custo =
            custom ? selVal : (spec == null ? 0 : spec.custo(selVal));
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: Text(edit == null ? 'Adicionar Defeito' : 'Editar Defeito'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campoDialogo(
                  label: 'Defeito',
                  valor: custom ? _kCustom : (sel?.nome ?? ''),
                  onTap: () => _abrirSeletor(
                    titulo: 'Defeito',
                    opcoes: [
                      for (final d in GameData.defeitos)
                        ItemDescrito(d.nome, d.resumo),
                      _opcaoCustom,
                    ],
                    atual: custom ? _kCustom : (sel?.nome ?? ''),
                    onSel: (n) => setL(() {
                      if (n == _kCustom) {
                        custom = true;
                        sel = null;
                        subtipo = null;
                        if (selVal < 1) selVal = 1;
                      } else {
                        custom = false;
                        sel = GameData.defeitoPorNome(n);
                        selVal = sel!.custoSpec.selInicial;
                        subtipo = sel!.subtipos.isNotEmpty
                            ? sel!.subtipos.first
                            : null;
                      }
                    }),
                  ),
                ),
                if (custom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                    onChanged: (_) => setL(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Valor: '),
                      _stepper(selVal, 1, 10, (nv) => setL(() => selVal = nv)),
                    ],
                  ),
                ] else if (sel != null && spec != null) ...[
                  const SizedBox(height: 8),
                  Text(sel!.resumo, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 8),
                  if (spec.tipo == 'opcoes')
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final val in spec.valores)
                          ChoiceChip(
                            label: Text('$val pts'),
                            selected: selVal == val,
                            selectedColor: Cores.indigo,
                            backgroundColor: Cores.pergaminhoEscuro,
                            labelStyle: TextStyle(
                                color: selVal == val
                                    ? Cores.pergaminho
                                    : Cores.tinta),
                            onSelected: (_) => setL(() => selVal = val),
                          ),
                      ],
                    )
                  else if (spec.tipo == 'faixa')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Valor: '),
                        _stepper(selVal, spec.min, spec.max,
                            (nv) => setL(() => selVal = nv)),
                      ],
                    ),
                  if (sel!.subtipos.isNotEmpty)
                    _campoDialogo(
                      label: 'Manifestação',
                      valor: subtipo ?? '',
                      onTap: () => _abrirSeletor(
                        titulo: 'Manifestação',
                        opcoes: [
                          for (final s in sel!.subtipos) ItemDescrito(s, ''),
                        ],
                        atual: subtipo ?? '',
                        onSel: (v) => setL(() => subtipo = v),
                      ),
                    ),
                  TextField(
                    controller: detalheCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Detalhe (opcional)'),
                  ),
                ],
                if (custom || sel != null) ...[
                  const SizedBox(height: 8),
                  Text('Custo: $custo pontos negativos',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Cores.indigo)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: (custom
                      ? nomeCtrl.text.trim().isEmpty
                      : sel == null)
                  ? null
                  : () {
                      setState(() {
                        final dados = custom
                            ? {
                                'nome': nomeCtrl.text.trim(),
                                'sel': selVal,
                                'detalhe': '',
                                'subtipo': '',
                                'custom': true,
                                'descricao': descCtrl.text.trim(),
                              }
                            : {
                                'nome': sel!.nome,
                                'sel': selVal,
                                'detalhe': detalheCtrl.text,
                                'subtipo': subtipo ?? '',
                                'custom': false,
                                'descricao': '',
                              };
                        if (edit != null) {
                          edit
                            ..clear()
                            ..addAll(dados);
                        } else {
                          f.adicionar('defeitos', dados);
                        }
                      });
                      Navigator.pop(context);
                    },
              child: Text(edit == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _addGenetico() async {
    String? sel =
        GameData.defeitosGeneticos.isNotEmpty ? GameData.defeitosGeneticos.first : null;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: const Text('Defeito Genético'),
          content: DropdownButtonFormField<String>(
            initialValue: sel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final t in GameData.defeitosGeneticos)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setL(() => sel = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: sel == null
                  ? null
                  : () {
                      setState(() =>
                          f.adicionar('defeitosGeneticos', {'nome': sel}));
                      Navigator.pop(context);
                    },
              child: const Text('Adicionar'),
            ),
          ],
        );
      }),
    );
  }

  // ---------- Passo 6: Toques Finais (15 pontos de bônus) ----------

  /// Linha com stepper de bônus: mostra base → final e os botões ±.
  /// Incremento só habilita se couber no teto e no orçamento restante.
  Widget _linhaBonus({
    required String nome,
    required int base,
    required int bonusV,
    required int maxFinal,
    required int custoUnit,
    required void Function(int) setB,
    bool desabilitado = false,
    int? maxFinalLivre,
  }) {
    final total = base + bonusV;
    // Evolução: os 15 pontos deixam de ser trava (viram só um placar) e o teto
    // da criação sobe para o máximo absoluto do traço.
    final teto = _livre ? maxFinalLivre ?? maxFinal : maxFinal;
    final podeMais = (!desabilitado || _livre) &&
        total < teto &&
        (_livre || f.bonusRestante >= custoUnit);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: desabilitado ? Colors.grey : Cores.tinta)),
          ),
          Text('$base',
              style: const TextStyle(fontSize: 13, color: Cores.tinta)),
          const Icon(Icons.arrow_right_alt, size: 18, color: Cores.dourado),
          SizedBox(
            width: 22,
            child: Text('$total',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: bonusV > 0 ? Cores.indigo : Cores.tinta)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            visualDensity: VisualDensity.compact,
            onPressed:
                bonusV > 0 ? () => setState(() => setB(bonusV - 1)) : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            visualDensity: VisualDensity.compact,
            onPressed: podeMais ? () => setState(() => setB(bonusV + 1)) : null,
          ),
        ],
      ),
    );
  }

  /// Título da caixa Arete/FdV/Quintessência conforme o que está visível.
  String _tituloVantagensBonus() {
    final partes = [
      if (_mostra('arete')) 'Arete',
      if (_mostra('forcaVontade')) 'Força de Vontade',
      if (_mostra('quintessencia')) 'Quintessência',
    ];
    if (partes.length == 1) return partes.first;
    return '${partes.take(partes.length - 1).join(', ')} e ${partes.last}';
  }

  Widget _pgToquesFinais() {
    final gasto = f.bonusGasto;
    final resta = f.bonusRestante;
    final total = GameData.bonusTotal;
    final bloqueadas = GameData.esferasBloqueadas(f.faccao);
    final temVantagens = _mostra('arete') ||
        _mostra('forcaVontade') ||
        _mostra('quintessencia');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mostraRegras)
          Card(
            color: resta < 0 ? const Color(0xFFF3D9D2) : Cores.pergaminhoEscuro,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _placar('Gastos', 'de $total', '$gasto pts')),
                      Container(width: 1, height: 44, color: Cores.dourado),
                      Expanded(
                          child:
                              _placar('Restantes', 'podem sobrar', '$resta')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value:
                        total == 0 ? 0 : (gasto / total).clamp(0, 1).toDouble(),
                    backgroundColor: Cores.pergaminho,
                    color: resta < 0 ? Colors.red : Cores.dourado,
                    minHeight: 7,
                  ),
                  const SizedBox(height: 8),
                  Text(GameData.bonusTexto,
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 4),
                  const Text(
                    'Qualidades e Defeitos NÃO mexem nesses pontos — o total é sempre 15.',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        if (_mostra('bonusAtributos')) ...[
          FaixaSecao(
              'Atributos  (${GameData.custoBonus('atributo')} bônus/ponto)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (final cat in GameData.atributos.categorias) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(cat.nome,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Cores.dourado)),
                    ),
                    for (final t in cat.tracos)
                      _linhaBonus(
                        nome: t.nome,
                        base: f.atributo(t.nome),
                        bonusV: f.bonusAtributo(t.nome),
                        maxFinal: GameData.atributos.regra.maximo,
                        custoUnit: GameData.custoBonus('atributo'),
                        setB: (v) => f.setBonusAtributo(t.nome, v),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (_mostra('bonusHabilidades')) ...[
          FaixaSecao(
              'Habilidades  (${GameData.custoBonus('habilidade')} bônus/ponto)'),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'É aqui que uma Habilidade sobe de 3 para 4 ou 5.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
          for (final cat in GameData.habilidades.categorias)
            Card(
              child: ExpansionTile(
                title: Text(cat.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Cores.indigo)),
                shape: const Border(),
                childrenPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  for (final t in f.tracosDaCategoria(cat))
                    _linhaBonus(
                      nome: t.nome,
                      base: f.habilidade(t.nome),
                      bonusV: f.bonusHabilidade(t.nome),
                      maxFinal: GameData.habilidades.regra.maximo,
                      custoUnit: GameData.custoBonus('habilidade'),
                      setB: (v) => f.setBonusHabilidade(t.nome, v),
                    ),
                ],
              ),
            ),
        ],
        if (_mostra('bonusEsferas')) ...[
          FaixaSecao('Esferas  (${GameData.custoBonus('esfera')} bônus/ponto)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (final e in GameData.esferas)
                    _linhaBonus(
                      nome: e.nome,
                      base: f.esfera(e.chave),
                      bonusV: f.bonusEsfera(e.chave),
                      maxFinal: GameData.esferasMaximoCriacao,
                      maxFinalLivre: 5,
                      custoUnit: GameData.custoBonus('esfera'),
                      setB: (v) => f.setBonusEsfera(e.chave, v),
                      desabilitado: bloqueadas.contains(e.chave),
                    ),
                  if (!_livre)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          'Limite de iniciante: ${GameData.esferasMaximoCriacao} por Esfera.',
                          style: const TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (temVantagens) ...[
          FaixaSecao(_tituloVantagensBonus()),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  if (_mostra('arete'))
                    _linhaBonus(
                      nome: _livre
                          ? 'Arete'
                          : 'Arete  (${GameData.custoBonus('arete')}/ponto · máx ${GameData.areteMaximoCriacao} na criação)',
                      base: f.arete,
                      bonusV: f.bonusArete,
                      maxFinal: GameData.areteMaximoCriacao,
                      maxFinalLivre: 10,
                      custoUnit: GameData.custoBonus('arete'),
                      setB: (v) => f.bonusArete = v,
                    ),
                  if (_mostra('forcaVontade'))
                    _linhaBonus(
                      nome: _livre
                          ? 'Força de Vontade'
                          : 'Força de Vontade  (${GameData.custoBonus('forcaVontade')}/ponto)',
                      base: f.forcaVontade,
                      bonusV: f.bonusForcaVontade,
                      maxFinal: GameData.forcaVontadeMaxima,
                      custoUnit: GameData.custoBonus('forcaVontade'),
                      setB: (v) => f.bonusForcaVontade = v,
                    ),
                  if (_mostra('quintessencia')) ...[
                    _linhaBonus(
                      nome:
                          'Quintessência  (1 ponto = +${GameData.quintessenciaPacote})',
                      base: f.avatar,
                      bonusV: f.bonusQuintessencia,
                      maxFinal: GameData.rodaQuintessencia,
                      custoUnit: GameData.custoBonus('quintessencia'),
                      setB: (v) => f.bonusQuintessencia = v,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Quintessência final: ${f.quintessencia} '
                        '(Avatar ${f.avatar} + ${f.bonusQuintessencia} × ${GameData.quintessenciaPacote}). '
                        'Paradoxo: ${f.paradoxo} (não pode ser comprado).',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------- Passo 7: Detalhes (página 2 da ficha) ----------
  Future<void> _addLinha(
      String titulo, List<String> campos, String listaKey) async {
    final ctrls = {for (final c in campos) c: TextEditingController()};
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in campos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: ctrls[c],
                    decoration: InputDecoration(labelText: c),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() => f.adicionar(
                  listaKey, {for (final c in campos) c: ctrls[c]!.text}));
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOutraCaracteristica() async {
    final nomeCtrl = TextEditingController();
    int valor = 1;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setL) {
        return AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: const Text('Outra Característica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Valor: '),
                  _stepper(valor, 0, 5, (nv) => setL(() => valor = nv)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nomeCtrl.text.trim().isEmpty) return;
                setState(() => f.adicionar('outrasCaracteristicas',
                    {'nome': nomeCtrl.text.trim(), 'valor': valor}));
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      }),
    );
  }

  Widget _pgDetalhes() {
    final ap = f.aparencia;
    final maravilhas = f.maravilhas;
    final combate = f.combate;
    final outras = f.outrasCaracteristicas;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FaixaSecao('História'),
        _texto('História', f.data['historia'], (v) => f.data['historia'] = v,
            maxLines: 4),
        _texto('Objetivos / Destino', f.data['objetivosDestino'],
            (v) => f.data['objetivosDestino'] = v,
            maxLines: 3),
        const FaixaSecao('Rotinas'),
        _texto('Rotinas', f.data['rotinas'], (v) => f.data['rotinas'] = v,
            maxLines: 3, hint: 'Práticas e hábitos mágikos do dia a dia'),
        const FaixaSecao('Focos'),
        _texto('Focos', f.data['focos'], (v) => f.data['focos'] = v,
            maxLines: 3,
            hint: 'Paradigma, práticas e instrumentos da sua mágika'),
        const FaixaSecao('Maravilhas'),
        for (int i = 0; i < maravilhas.length; i++)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${maravilhas[i]['Nome']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${maravilhas[i]['Descrição']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Cores.indigoClaro),
                onPressed: () => setState(() => f.remover('maravilhas', i)),
              ),
            ),
          ),
        OutlinedButton.icon(
            onPressed: () =>
                _addLinha('Adicionar Maravilha', ['Nome', 'Descrição'], 'maravilhas'),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Maravilha'),
            style: _outlined()),
        const FaixaSecao('Aparência'),
        Row(children: [
          Expanded(
              child: _texto('Idade', ap['idade'] ?? '',
                  (v) => ap['idade'] = v)),
          const SizedBox(width: 8),
          Expanded(
              child: _texto('Idade Aparente', ap['idadeAparente'] ?? '',
                  (v) => ap['idadeAparente'] = v)),
        ]),
        Row(children: [
          Expanded(
              child: _texto('Sexo', ap['sexo'] ?? '', (v) => ap['sexo'] = v)),
          const SizedBox(width: 8),
          Expanded(
              child:
                  _texto('Etnia', ap['etnia'] ?? '', (v) => ap['etnia'] = v)),
        ]),
        Row(children: [
          Expanded(
              child: _texto(
                  'Cabelos', ap['cabelos'] ?? '', (v) => ap['cabelos'] = v)),
          const SizedBox(width: 8),
          Expanded(
              child:
                  _texto('Olhos', ap['olhos'] ?? '', (v) => ap['olhos'] = v)),
        ]),
        Row(children: [
          Expanded(
              child: _texto(
                  'Altura', ap['altura'] ?? '', (v) => ap['altura'] = v)),
          const SizedBox(width: 8),
          Expanded(
              child: _texto('Peso', ap['peso'] ?? '', (v) => ap['peso'] = v)),
        ]),
        _texto('Descrição', ap['descricao'] ?? '', (v) => ap['descricao'] = v,
            maxLines: 3),
        const FaixaSecao('Itens & Equipamentos'),
        _texto('Itens e equipamentos', f.data['itensEquipamentos'],
            (v) => f.data['itensEquipamentos'] = v,
            maxLines: 4),
        const FaixaSecao('Combate'),
        for (int i = 0; i < combate.length; i++)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${combate[i]['Arma/Manobra']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'Dif: ${combate[i]['Dif.']} · Dano: ${combate[i]['Dano']} · '
                  'Tipo: ${combate[i]['Tipo']} · Alcance: ${combate[i]['Alcance']} · '
                  'Cadência: ${combate[i]['Cadência']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Cores.indigoClaro),
                onPressed: () => setState(() => f.remover('combate', i)),
              ),
            ),
          ),
        OutlinedButton.icon(
            onPressed: () => _addLinha(
                'Adicionar arma/manobra',
                ['Arma/Manobra', 'Dif.', 'Dano', 'Tipo', 'Alcance', 'Cadência'],
                'combate'),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar arma/manobra'),
            style: _outlined()),
        const FaixaSecao('Outras Características'),
        for (int i = 0; i < outras.length; i++)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${outras[i]['nome']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '●' * ((outras[i]['valor'] as num?)?.toInt() ?? 0) +
                          '○' *
                              (5 - ((outras[i]['valor'] as num?)?.toInt() ?? 0))
                                  .clamp(0, 5),
                      style: const TextStyle(
                          color: Cores.indigo, letterSpacing: 2)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Cores.indigoClaro),
                    onPressed: () =>
                        setState(() => f.remover('outrasCaracteristicas', i)),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
            onPressed: _addOutraCaracteristica,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar característica'),
            style: _outlined()),
        const FaixaSecao('Notas'),
        _texto('Notas', f.data['notas'], (v) => f.data['notas'] = v,
            maxLines: 4),
      ],
    );
  }

}
