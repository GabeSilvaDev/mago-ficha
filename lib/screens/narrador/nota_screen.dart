import 'package:flutter/material.dart';

import '../../models/nota.dart';
import '../../store/ficha_store.dart';
import '../../store/imagem_store.dart';
import '../../store/nota_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../ficha_view_screen.dart';
import 'visualizador_imagens.dart';

/// Editor de um caderno: título, texto, tags, imagens e personagens ligados.
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

  void _abrirImagem(int i) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: nota.imagens,
        legendas: nota.legendas,
        inicial: i,
      ),
    ));
  }

  Future<void> _editarLegenda(String id) async {
    final ctrl = TextEditingController(text: nota.legendas[id] ?? '');
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Legenda da imagem'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Ex.: mapa da estação'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Salvar',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (texto == null) return;
    setState(() {
      if (texto.trim().isEmpty) {
        nota.legendas.remove(id);
      } else {
        nota.legendas[id] = texto.trim();
      }
    });
  }

  /// Escolhe entre as fichas existentes (jogadores e NPCs) as que ficam
  /// ligadas a esta anotação.
  Future<void> _ligarPersonagem() async {
    final disponiveis =
        FichaStore.todas().where((f) => !nota.fichas.contains(f.id)).toList();
    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum personagem para ligar.')));
      return;
    }
    final escolhido = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Ligar personagem'),
        children: [
          for (final f in disponiveis)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f.id),
              child: Row(
                children: [
                  RetratoAvatar(retratoId: f.retratoId, tamanho: 32),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(f.nome.isEmpty ? 'Sem nome' : f.nome)),
                  if (f.ehNpc)
                    const Text('NPC',
                        style: TextStyle(
                            fontSize: 11, color: Cores.indigoClaro)),
                ],
              ),
            ),
        ],
      ),
    );
    if (escolhido == null) return;
    setState(() => nota.fichas.add(escolhido));
  }

  @override
  Widget build(BuildContext context) {
    final ligadas = [
      for (final id in nota.fichas)
        if (FichaStore.porId(id) != null) FichaStore.porId(id)!,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existente == null ? 'NOVO CADERNO' : 'CADERNO'),
        actions: [
          IconButton(
            key: const ValueKey('fixar-nota'),
            tooltip: nota.fixada ? 'Desafixar' : 'Fixar no topo',
            icon: Icon(
                nota.fixada ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => nota.fixada = !nota.fixada),
          ),
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
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Toque para abrir em tela cheia e mostrar para a mesa.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < nota.imagens.length; i++)
                _Miniatura(
                  id: nota.imagens[i],
                  legenda: nota.legendas[nota.imagens[i]] ?? '',
                  onAbrir: () => _abrirImagem(i),
                  onLegenda: () => _editarLegenda(nota.imagens[i]),
                  onRemover: () => setState(() {
                    nota.legendas.remove(nota.imagens[i]);
                    nota.imagens.removeAt(i);
                  }),
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
          const FaixaSecao('Personagens'),
          if (ligadas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum personagem ligado. Útil para os NPCs desta sessão.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          for (final f in ligadas)
            Card(
              child: ListTile(
                leading: RetratoAvatar(retratoId: f.retratoId, tamanho: 40),
                title: Text(f.nome.isEmpty ? 'Sem nome' : f.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Cores.indigo)),
                subtitle: Text(f.ehNpc ? 'NPC' : 'Jogador'),
                trailing: IconButton(
                  icon: const Icon(Icons.link_off, color: Cores.indigoClaro),
                  tooltip: 'Desligar da anotação',
                  onPressed: () =>
                      setState(() => nota.fichas.remove(f.id)),
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FichaViewScreen(fichaId: f.id))),
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Ligar personagem'),
            onPressed: _ligarPersonagem,
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
  final String legenda;
  final VoidCallback onAbrir;
  final VoidCallback onLegenda;
  final VoidCallback onRemover;
  const _Miniatura({
    required this.id,
    required this.legenda,
    required this.onAbrir,
    required this.onLegenda,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = ImagemStore.bytes(id);
    if (bytes == null) return const SizedBox.shrink();
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: onAbrir,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(bytes,
                      width: 140, height: 105, fit: BoxFit.cover),
                ),
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
          ),
          InkWell(
            onTap: onLegenda,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                legenda.isEmpty ? '+ legenda' : legenda,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: legenda.isEmpty ? FontStyle.italic : null,
                  color: legenda.isEmpty ? Cores.indigoClaro : Cores.tinta,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
