import 'dart:convert';

import 'package:flutter/material.dart';

import '../../screens/narrador/visualizador_imagens.dart';
import '../../theme.dart';
import '../mesa_service.dart';

/// O acervo de imagens da mesa: tudo que o mestre já guardou, mais recente
/// primeiro. O que está em destaque agora mora em [MuralDaMesa] — aqui é o
/// resto, para reabrir quando quiser.
class GaleriaMesa extends StatefulWidget {
  final MesaService servico;
  final String mesaId;
  final bool souMestre;

  const GaleriaMesa({
    super.key,
    required this.servico,
    required this.mesaId,
    required this.souMestre,
  });

  @override
  State<GaleriaMesa> createState() => _GaleriaMesaState();
}

class _GaleriaMesaState extends State<GaleriaMesa> {
  /// id do item sendo aberto agora, para a célula mostrar o carregando por
  /// cima só da miniatura dela — as outras continuam clicáveis.
  String? _carregando;

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _abrir(ItemGaleria item) async {
    setState(() => _carregando = item.id);
    final cheia = await widget.servico.imagemCheia(widget.mesaId, item.id);
    if (!mounted) return;
    setState(() => _carregando = null);
    if (cheia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui carregar a imagem.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': base64Decode(cheia)},
        legendas: {'mural': item.legenda},
      ),
    ));
  }

  Future<void> _mostrarAgora(ItemGaleria item) async {
    try {
      await widget.servico.mostrarAgora(widget.mesaId, item.id);
    } catch (e) {
      _erro(e);
    }
  }

  Future<void> _apagar(ItemGaleria item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Apagar esta imagem?'),
        content: const Text(
            'Ela some da galeria e do mural (se estiver em destaque). Isso '
            'não pode ser desfeito.'),
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
    try {
      await widget.servico.apagarDaGaleria(widget.mesaId, item.id);
    } catch (e) {
      _erro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemGaleria>>(
      stream: widget.servico.observarGaleria(widget.mesaId),
      builder: (context, snap) {
        final itens = snap.data ?? const <ItemGaleria>[];
        return itens.isEmpty ? _vazia() : _grade(itens);
      },
    );
  }

  Widget _vazia() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          widget.souMestre
              ? 'Nenhuma imagem nesta mesa ainda. Use "Mostrar imagem para a '
                'mesa" acima.'
              : 'Nenhuma imagem nesta mesa ainda.',
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _grade(List<ItemGaleria> itens) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itens.length,
      itemBuilder: (_, i) => _celula(itens[i]),
    );
  }

  Widget _celula(ItemGaleria item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(item),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    base64Decode(item.miniaturaBase64),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                  if (_carregando == item.id)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Cores.pergaminho),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                item.legenda,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.souMestre)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Mostrar agora',
                    icon: const Icon(Icons.present_to_all, size: 18),
                    onPressed: () => _mostrarAgora(item),
                  ),
                  IconButton(
                    tooltip: 'Apagar da galeria',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _apagar(item),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
