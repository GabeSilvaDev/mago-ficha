import 'package:flutter/material.dart';

import '../../models/nota.dart';
import '../../store/imagem_store.dart';
import '../../store/nota_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';

/// Editor de um caderno: título, texto, tags e imagens.
class NotaScreen extends StatefulWidget {
  final Nota? existente;
  const NotaScreen({super.key, this.existente});

  @override
  State<NotaScreen> createState() => _NotaScreenState();
}

class _NotaScreenState extends State<NotaScreen> {
  late final Nota nota;
  final _tagCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    nota = widget.existente ?? Nota.criar();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    await NotaStore.salvar(nota);
    if (mounted) Navigator.pop(context);
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty || nota.tags.contains(t)) return;
    setState(() {
      nota.tags.add(t);
      _tagCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existente == null ? 'NOVO CADERNO' : 'CADERNO'),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            icon: const Icon(Icons.check),
            onPressed: _salvar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            initialValue: nota.titulo,
            decoration: const InputDecoration(labelText: 'Título'),
            onChanged: (v) => nota.titulo = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: nota.texto,
            maxLines: 14,
            minLines: 8,
            decoration: const InputDecoration(
              labelText: 'Anotações',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => nota.texto = v,
          ),
          const FaixaSecao('Tags'),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in nota.tags)
                InputChip(
                  label: Text(t),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => nota.tags.remove(t)),
                ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'nova tag',
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar tag',
                onPressed: _addTag,
              ),
            ],
          ),
          const FaixaSecao('Imagens'),
          if (nota.imagens.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhuma imagem. Mapas, retratos de NPC, pistas…',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in nota.imagens)
                _Miniatura(
                  id: id,
                  onRemover: () => setState(() => nota.imagens.remove(id)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Adicionar imagem'),
            onPressed: () async {
              // mesmo seletor do retrato: devolve o id já salvo no store
              final id = await escolherRetrato(context);
              if (id == null || !mounted) return;
              setState(() => nota.imagens.add(id));
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('SALVAR CADERNO'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  final String id;
  final VoidCallback onRemover;
  const _Miniatura({required this.id, required this.onRemover});

  @override
  Widget build(BuildContext context) {
    final bytes = ImagemStore.bytes(id);
    if (bytes == null) return const SizedBox.shrink();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 140, height: 105, fit: BoxFit.cover),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: const Icon(Icons.cancel, color: Cores.indigo, size: 20),
            tooltip: 'Remover imagem',
            onPressed: onRemover,
          ),
        ),
      ],
    );
  }
}
