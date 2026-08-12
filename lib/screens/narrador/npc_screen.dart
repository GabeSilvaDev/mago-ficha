import 'package:flutter/material.dart';

import '../../models/campo_narrador.dart';
import '../../models/ficha.dart';
import '../../store/ficha_store.dart';
import '../../store/narrador_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../wizard_screen.dart';

/// Formulário curto de NPC. Por baixo é uma `Ficha` normal (com `tipo: npc`),
/// então dá para promover o NPC ao criador completo quando ele crescer.
class NpcScreen extends StatefulWidget {
  final Ficha? existente;
  const NpcScreen({super.key, this.existente});

  @override
  State<NpcScreen> createState() => _NpcScreenState();
}

class _NpcScreenState extends State<NpcScreen> {
  late final Ficha f;

  @override
  void initState() {
    super.initState();
    f = widget.existente ?? Ficha.criarNpc();
  }

  Future<void> _salvar() async {
    await FichaStore.salvar(f);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmarExcluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Excluir NPC?'),
        content: Text('Excluir "${f.nome.isEmpty ? 'Sem nome' : f.nome}"? '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok != true) return;
    await FichaStore.excluir(f.id);
    if (mounted) Navigator.pop(context);
  }

  Widget _texto(String rotulo, String valor, ValueChanged<String> onMuda,
      {int linhas = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: valor,
        maxLines: linhas,
        decoration: InputDecoration(labelText: rotulo),
        onChanged: onMuda,
      ),
    );
  }

  Widget _campoCustom(CampoNarrador c) {
    switch (c.tipo) {
      case TipoCampo.derivado:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                  child: Text('${c.nome} (lido da ficha)',
                      style: const TextStyle(fontSize: 13))),
              Text(c.textoDe(f).isEmpty ? '—' : c.textoDe(f),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case TipoCampo.tag:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            initialValue: c.opcoes.contains(f.campo(c.id))
                ? f.campo(c.id) as String
                : null,
            decoration: InputDecoration(labelText: c.nome),
            items: [
              const DropdownMenuItem(value: '', child: Text('—')),
              for (final o in c.opcoes)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => setState(() => f.setCampo(c.id, v)),
          ),
        );
      case TipoCampo.numero:
        return _texto(c.nome, '${f.campo(c.id) ?? ''}',
            (v) => f.setCampo(c.id, int.tryParse(v.trim())));
      case TipoCampo.texto:
        return _texto(
            c.nome, '${f.campo(c.id) ?? ''}', (v) => f.setCampo(c.id, v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final campos = NarradorStore.campos();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existente == null ? 'NOVO NPC' : 'NPC'),
        actions: [
          IconButton(
            tooltip: 'Abrir no criador completo',
            icon: const Icon(Icons.edit_note),
            onPressed: () async {
              await FichaStore.salvar(f);
              if (!context.mounted) return;
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WizardScreen(existente: f)));
              if (mounted) setState(() {});
            },
          ),
          if (widget.existente != null)
            IconButton(
              tooltip: 'Excluir NPC',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmarExcluir,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                RetratoAvatar(retratoId: f.retratoId, tamanho: 96),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                          f.temRetrato ? 'Trocar retrato' : 'Escolher retrato'),
                      onPressed: () async {
                        final id = await escolherRetrato(context);
                        if (id == null || !mounted) return;
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
          const FaixaSecao('Identidade'),
          _texto('Nome', f.nome, (v) => setState(() => f.data['nome'] = v)),
          _texto('Conceito', f.conceito, (v) => f.data['conceito'] = v),
          _texto('Afiliação', f.afiliacao, (v) => f.data['afiliacao'] = v),
          const FaixaSecao('Anotações'),
          _texto('Notas do narrador', '${f.data['notas'] ?? ''}',
              (v) => f.data['notas'] = v,
              linhas: 6),
          if (campos.isNotEmpty) ...[
            const FaixaSecao('Campos do narrador'),
            for (final c in campos) _campoCustom(c),
          ],
          const FaixaSecao('Traços'),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Traços livres do NPC (nome e valor). Saem no PDF em "Outras '
              'Características".',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
          for (var i = 0; i < f.outrasCaracteristicas.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: '${f.outrasCaracteristicas[i]['nome'] ?? ''}',
                      decoration: const InputDecoration(labelText: 'Traço'),
                      onChanged: (v) => f.outrasCaracteristicas[i]['nome'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue:
                          '${f.outrasCaracteristicas[i]['valor'] ?? 0}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Valor'),
                      onChanged: (v) => f.outrasCaracteristicas[i]['valor'] =
                          int.tryParse(v.trim()) ?? 0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(
                        () => f.outrasCaracteristicas.removeAt(i)),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar traço'),
            onPressed: () => setState(() =>
                f.adicionar('outrasCaracteristicas', {'nome': '', 'valor': 1})),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('SALVAR NPC'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
