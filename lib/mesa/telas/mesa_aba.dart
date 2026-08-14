import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ficha.dart';
import '../../services/ficha_io.dart';
import '../../store/ficha_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../espelho_ficha.dart';
import '../mesa_firestore.dart';
import '../mesa_service.dart';
import '../mesa_store.dart';
import '../modelos.dart';
import 'entrar_mesa_dialogo.dart';
import 'mural_da_mesa.dart';
import 'painel_mestre.dart';

/// A aba Mesa: criar, entrar, ver quem está online e sair.
///
/// [servico] existe para o teste injetar o fake; em produção fica null e a
/// tela usa `MesaFirestore`.
class MesaAba extends StatefulWidget {
  final MesaService? servico;
  const MesaAba({super.key, this.servico});

  @override
  State<MesaAba> createState() => _MesaAbaState();
}

class _MesaAbaState extends State<MesaAba> {
  late final MesaService _servico;
  Timer? _ponto;
  bool _ocupado = false;
  EspelhoFicha? _espelho;

  /// A sessão online está de pé (login feito) e dá para observar a mesa.
  bool _sessaoPronta = false;
  String? _erroSessao;

  @override
  void initState() {
    super.initState();
    _servico = widget.servico ?? MesaFirestore();
    if (MesaStore.atual != null) _religar();
  }

  /// O app reabriu já dentro de uma mesa. O estado veio do disco, mas a
  /// sessão online não existe ainda: sem refazer o login, observar a mesa
  /// estoura porque o Firebase sequer foi inicializado.
  Future<void> _religar() async {
    try {
      await _servico.entrarAnonimo();
      final estado = MesaStore.atual;
      if (!mounted || estado == null) return;
      _ligarPonto();
      final fichaId = estado.fichaPublicadaId;
      if (fichaId != null) _ligarEspelho(estado.mesaId, fichaId);
      setState(() => _sessaoPronta = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroSessao = '$e');
    }
  }

  @override
  void dispose() {
    _ponto?.cancel();
    _desligarEspelho();
    super.dispose();
  }

  void _ligarEspelho(String mesaId, String fichaId) {
    _espelho = EspelhoFicha(_servico)..ligar(mesaId, fichaId);
    FichaStore.observador = _espelho!.aoSalvar;
  }

  /// Espelho morto com observador vivo faz o app escrever numa mesa que já não
  /// existe: os dois desligam juntos, sempre.
  void _desligarEspelho() {
    FichaStore.observador = null;
    _espelho?.desligar();
    _espelho = null;
  }

  /// Batimento de presença enquanto o app está aberto na mesa.
  void _ligarPonto() {
    _ponto?.cancel();
    _ponto = Timer.periodic(const Duration(seconds: 30), (_) {
      final estado = MesaStore.atual;
      if (estado != null) _servico.baterPonto(estado.mesaId);
    });
  }

  void _desligarPonto() {
    _ponto?.cancel();
    _ponto = null;
  }

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _comEspera(Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await acao();
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _criar() async {
    final dados = await pedirDadosDaMesa(context);
    if (dados == null) return;
    final (nomeMesa, meuNome) = dados;
    await _comEspera(() async {
      final uid = await _servico.entrarAnonimo();
      // a chave é mostrada ao mestre pela Task 9; aqui só criamos a mesa
      final (mesa, _) = await _servico.criarMesa(nomeMesa, meuNome);
      await MesaStore.entrar(EstadoMesa(
        mesaId: mesa.id,
        nome: mesa.nome,
        uid: uid,
        papel: PapelMesa.mestre,
      ));
      _ligarPonto();
      _sessaoPronta = true;
    });
  }

  Future<void> _entrar() async {
    final dados = await pedirCodigo(context);
    if (dados == null) return;
    final (codigo, meuNome) = dados;
    await _comEspera(() async {
      final uid = await _servico.entrarAnonimo();
      final mesa = await _servico.entrarPorCodigo(codigo, meuNome);
      await MesaStore.entrar(EstadoMesa(
        mesaId: mesa.id,
        nome: mesa.nome,
        uid: uid,
        papel: mesa.mestreUid == uid ? PapelMesa.mestre : PapelMesa.jogador,
      ));
      _ligarPonto();
      _sessaoPronta = true;
    });
  }

  Future<void> _sair(String mesaId) async {
    await _comEspera(() async {
      await _servico.sair(mesaId);
      _desligarPonto();
      _desligarEspelho();
      await MesaStore.limpar();
    });
  }

  /// Sem pedir nada: a mesa acabou por fora (fechada ou fui removido).
  Future<void> _voltarParaOffline(String motivo) async {
    _desligarPonto();
    _desligarEspelho();
    await MesaStore.limpar();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(motivo)));
  }

  Future<void> _fechar(String mesaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Fechar a mesa?'),
        content: const Text(
            'A mesa some para todo mundo e as fichas voltam a ser offline. '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Fechar',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok != true) return;
    await _comEspera(() async {
      await _servico.apagarMesa(mesaId);
      _desligarPonto();
      _desligarEspelho();
      await MesaStore.limpar();
    });
  }

  /// Escolhe uma ficha local e a espelha na mesa. NPC fica de fora: quem
  /// publica é jogador com o próprio mago.
  Future<void> _publicar(EstadoMesa estado) async {
    final minhas = FichaStore.todas().where((f) => !f.ehNpc).toList();
    if (minhas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Você ainda não tem nenhum mago para publicar.')));
      return;
    }
    final escolhida = await showDialog<Ficha>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Publicar uma ficha'),
        children: [
          for (final f in minhas)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Row(
                children: [
                  RetratoAvatar(retratoId: f.retratoId, tamanho: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f.nome.isEmpty ? 'Sem nome' : f.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Cores.indigo)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (escolhida == null) return;

    await _comEspera(() async {
      await _servico.publicarFicha(
        estado.mesaId,
        FichaIO.paraJson(escolhida),
        escolhida.nome.isEmpty ? 'Sem nome' : escolhida.nome,
      );
      await MesaStore.entrar(estado.comFicha(escolhida.id));
      _ligarEspelho(estado.mesaId, escolhida.id);
    });
  }

  Future<void> _tirarDaMesa(EstadoMesa estado) async {
    await _comEspera(() async {
      await _servico.despublicarFicha(estado.mesaId);
      _desligarEspelho();
      await MesaStore.entrar(estado.comFicha(null));
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = MesaStore.atual;
    if (estado == null) return _semMesa();
    if (_erroSessao != null) return _semConexao(estado);
    if (!_sessaoPronta) {
      return const Center(child: CircularProgressIndicator());
    }
    return _naMesa(estado);
  }

  /// Estava numa mesa e o app voltou sem internet. O resto do app continua
  /// funcionando; aqui só dá para esperar ou sair da mesa.
  Widget _semConexao(EstadoMesa estado) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: Cores.indigoClaro),
            const SizedBox(height: 12),
            Text(
              'Não consegui conectar à mesa "${estado.nome}".\n'
              'Suas fichas continuam aqui do mesmo jeito.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(_erroSessao!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _erroSessao = null;
                _religar();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                _desligarPonto();
                _desligarEspelho();
                await MesaStore.limpar();
                if (mounted) setState(() => _erroSessao = null);
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair da mesa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _semMesa() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 56, color: Cores.indigoClaro),
            const SizedBox(height: 12),
            const Text(
              'Você não está em nenhuma mesa.\n'
              'O app continua funcionando offline do mesmo jeito — a mesa é '
              'só para o mestre acompanhar a sessão.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_ocupado)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton.icon(
                onPressed: _criar,
                icon: const Icon(Icons.add),
                label: const Text('Criar mesa'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _entrar,
                icon: const Icon(Icons.login),
                label: const Text('Entrar com código'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Cores.indigo,
                    side: const BorderSide(color: Cores.indigo)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _naMesa(EstadoMesa estado) {
    final souMestre = estado.papel == PapelMesa.mestre;
    return StreamBuilder<Mesa?>(
      stream: _servico.observarMesa(estado.mesaId),
      builder: (context, snap) {
        if (snap.hasData && snap.data == null) {
          // a mesa sumiu enquanto estávamos nela
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _voltarParaOffline('O mestre encerrou a mesa.');
          });
        }
        final mesa = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mesa?.nome ?? estado.nome,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Cores.indigo)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Código: '),
                        SelectableText(
                          mesa?.codigo ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 16),
                        ),
                        IconButton(
                          tooltip: 'Copiar código',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: mesa == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                      ClipboardData(text: mesa.codigo));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Código copiado.')));
                                },
                        ),
                        if (souMestre && mesa != null)
                          IconButton(
                            tooltip: 'Trocar código',
                            icon: const Icon(Icons.autorenew, size: 18),
                            onPressed: () => _comEspera(
                                () => _servico.trocarCodigo(mesa.id)),
                          ),
                      ],
                    ),
                    const Text(
                      'Dite esse código para quem for entrar.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            const FaixaSecao('Quem está na mesa'),
            _membros(estado, souMestre),
            // o mural é de todos: quem fechou a imagem volta a ela por aqui
            const FaixaSecao('Mural da mesa'),
            MuralDaMesa(
                servico: _servico,
                mesaId: estado.mesaId,
                souMestre: souMestre),
            if (souMestre)
              PainelMestre(servico: _servico, mesaId: estado.mesaId),
            const FaixaSecao('Minha ficha nesta mesa'),
            _minhaFicha(estado),
            const SizedBox(height: 16),
            if (_ocupado)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _sair(estado.mesaId),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair da mesa'),
                  ),
                  if (souMestre)
                    TextButton.icon(
                      onPressed: () => _fechar(estado.mesaId),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Fechar mesa'),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// A ficha que EU publiquei. O mestre também joga com uma às vezes, então
  /// isto vale para os dois papéis.
  Widget _minhaFicha(EstadoMesa estado) {
    final fichaId = estado.fichaPublicadaId;
    final ficha = fichaId == null ? null : FichaStore.porId(fichaId);

    if (fichaId == null || ficha == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Publicando a ficha, o mestre acompanha o que você marca nela '
                'durante a sessão. Os outros jogadores não veem.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _ocupado ? null : () => _publicar(estado),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Publicar uma ficha'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Cores.indigo,
                      side: const BorderSide(color: Cores.indigo)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: RetratoAvatar(retratoId: ficha.retratoId),
            title: Text(ficha.nome.isEmpty ? 'Sem nome' : ficha.nome,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Cores.indigo)),
            subtitle: const Text('o mestre vê as mudanças em segundos'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextButton.icon(
              onPressed: _ocupado ? null : () => _tirarDaMesa(estado),
              icon: const Icon(Icons.cloud_off_outlined, size: 18),
              label: const Text('Tirar da mesa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membros(EstadoMesa estado, bool souMestre) {
    return StreamBuilder<List<Membro>>(
      stream: _servico.observarMembros(estado.mesaId),
      builder: (context, snap) {
        final membros = snap.data ?? const <Membro>[];
        if (membros.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Ninguém aqui ainda.'),
            ),
          );
        }
        final agora = DateTime.now();
        return Card(
          child: Column(
            children: [
              for (final m in membros)
                ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: m.onlineEm(agora)
                        ? Colors.green.shade600
                        : Colors.grey,
                  ),
                  title: Text(m.nome.isEmpty ? 'Sem nome' : m.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Cores.indigo)),
                  subtitle: Text(
                      m.papel == PapelMesa.mestre ? 'mestre' : 'jogador'),
                  trailing: souMestre && m.uid != estado.uid
                      ? IconButton(
                          tooltip: 'Remover da mesa',
                          icon: const Icon(Icons.person_remove_outlined,
                              color: Cores.indigoClaro),
                          onPressed: () => _comEspera(() =>
                              _servico.removerMembro(estado.mesaId, m.uid)),
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}
