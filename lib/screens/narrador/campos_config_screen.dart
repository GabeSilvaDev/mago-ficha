import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/campo_narrador.dart';
import '../../store/narrador_store.dart';
import '../../theme.dart';

/// Define os campos customizados que aparecem nos cards da galeria e servem
/// para ordenar e filtrar os personagens.
class CamposConfigScreen extends StatefulWidget {
  const CamposConfigScreen({super.key});

  @override
  State<CamposConfigScreen> createState() => _CamposConfigScreenState();
}

class _CamposConfigScreenState extends State<CamposConfigScreen> {
  List<CampoNarrador> _campos = [];

  @override
  void initState() {
    super.initState();
    _campos = NarradorStore.campos();
  }

  String _rotuloTipo(CampoNarrador c) {
    switch (c.tipo) {
      case TipoCampo.texto:
        return 'Texto livre';
      case TipoCampo.numero:
        return 'Número';
      case TipoCampo.tag:
        return 'Etiqueta: ${c.opcoes.join(', ')}';
      case TipoCampo.derivado:
        return 'Lido da ficha: '
            '${CampoNarrador.origensDerivadas[c.origem] ?? c.origem}';
    }
  }

  Future<void> _novo() async {
    final campo = await showDialog<CampoNarrador>(
      context: context,
      builder: (_) => const _DialogoCampo(),
    );
    if (campo == null) return;
    final lista = [..._campos, campo];
    await NarradorStore.salvarCampos(lista);
    if (mounted) setState(() => _campos = lista);
  }

  Future<void> _confirmarExcluir(CampoNarrador c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: Text('Apagar o campo "${c.nome}"?'),
        content: const Text(
            'O valor desse campo será removido de todas as fichas. '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok != true) return;
    await NarradorStore.excluirCampo(c.id);
    if (mounted) setState(() => _campos = NarradorStore.campos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAMPOS CUSTOMIZADOS'),
        actions: [
          IconButton(
            onPressed: _novo,
            icon: const Icon(Icons.add),
            tooltip: 'Novo campo',
          ),
        ],
      ),
      body: _campos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum campo ainda.\n\n'
                  'Campos aparecem nos cards da galeria e servem para ordenar '
                  'e filtrar. Os do tipo "lido da ficha" (Arete, Afiliação...) '
                  'não precisam ser preenchidos à mão.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final c in _campos)
                  Card(
                    child: ListTile(
                      title: Text(c.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Cores.indigo)),
                      subtitle: Text(_rotuloTipo(c)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Cores.indigo),
                        onPressed: () => _confirmarExcluir(c),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Os três primeiros campos são os que aparecem no card.',
                    style:
                        TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Formulário de um campo novo.
class _DialogoCampo extends StatefulWidget {
  const _DialogoCampo();

  @override
  State<_DialogoCampo> createState() => _DialogoCampoState();
}

class _DialogoCampoState extends State<_DialogoCampo> {
  final _nome = TextEditingController();
  final _opcoes = TextEditingController();
  TipoCampo _tipo = TipoCampo.texto;
  String _origem = CampoNarrador.origensDerivadas.keys.first;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _opcoes.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Dê um nome ao campo.');
      return;
    }
    final opcoes = _opcoes.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (_tipo == TipoCampo.tag && opcoes.isEmpty) {
      setState(() => _erro = 'Etiqueta precisa de pelo menos uma opção.');
      return;
    }
    Navigator.pop(
      context,
      CampoNarrador(
        id: const Uuid().v4(),
        nome: nome,
        tipo: _tipo,
        opcoes: _tipo == TipoCampo.tag ? opcoes : const [],
        origem: _tipo == TipoCampo.derivado ? _origem : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.pergaminho,
      title: const Text('Novo campo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do campo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoCampo>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                    value: TipoCampo.texto, child: Text('Texto livre')),
                DropdownMenuItem(
                    value: TipoCampo.numero, child: Text('Número')),
                DropdownMenuItem(
                    value: TipoCampo.tag, child: Text('Etiqueta (lista)')),
                DropdownMenuItem(
                    value: TipoCampo.derivado,
                    child: Text('Lido da ficha')),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? TipoCampo.texto),
            ),
            if (_tipo == TipoCampo.tag) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _opcoes,
                decoration: const InputDecoration(
                  labelText: 'Opções, separadas por vírgula',
                  hintText: 'Vivo, Morto, Desaparecido',
                ),
              ),
            ],
            if (_tipo == TipoCampo.derivado) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _origem,
                decoration:
                    const InputDecoration(labelText: 'Característica'),
                items: [
                  for (final e in CampoNarrador.origensDerivadas.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _origem = v ?? _origem),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Campo lido da ficha não é preenchido à mão: serve para '
                  'ordenar e filtrar a galeria.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_erro!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: _salvar,
            child:
                const Text('Adicionar', style: TextStyle(color: Cores.indigo))),
      ],
    );
  }
}
