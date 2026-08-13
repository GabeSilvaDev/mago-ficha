import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../mesa_firestore.dart';
import '../mesa_service.dart';
import '../mesa_store.dart';
import '../modelos.dart';
import 'entrar_mesa_dialogo.dart';

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

  @override
  void initState() {
    super.initState();
    _servico = widget.servico ?? MesaFirestore();
    if (MesaStore.atual != null) _ligarPonto();
  }

  @override
  void dispose() {
    _ponto?.cancel();
    super.dispose();
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
      final mesa = await _servico.criarMesa(nomeMesa, meuNome);
      await MesaStore.entrar(EstadoMesa(
        mesaId: mesa.id,
        nome: mesa.nome,
        uid: uid,
        papel: PapelMesa.mestre,
      ));
      _ligarPonto();
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
    });
  }

  Future<void> _sair(String mesaId) async {
    await _comEspera(() async {
      await _servico.sair(mesaId);
      _desligarPonto();
      await MesaStore.limpar();
    });
  }

  /// Sem pedir nada: a mesa acabou por fora (fechada ou fui removido).
  Future<void> _voltarParaOffline(String motivo) async {
    _desligarPonto();
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
      await _servico.fecharMesa(mesaId);
      _desligarPonto();
      await MesaStore.limpar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = MesaStore.atual;
    if (estado == null) return _semMesa();
    return _naMesa(estado);
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
