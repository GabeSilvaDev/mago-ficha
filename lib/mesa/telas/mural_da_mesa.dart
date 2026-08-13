import 'dart:convert';

import 'package:flutter/material.dart';

import '../../screens/narrador/visualizador_imagens.dart';
import '../../store/imagem_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../imagem_mural.dart';
import '../mesa_service.dart';

/// O mural da mesa, do jeito que cada um vê.
///
/// A imagem abre sozinha quando o mestre a põe, mas quem fechou precisa poder
/// voltar a ela quando quiser: enquanto estiver no mural, fica aqui para
/// reabrir quantas vezes for. Só o mestre põe e tira ([souMestre]).
class MuralDaMesa extends StatefulWidget {
  final MesaService servico;
  final String mesaId;
  final bool souMestre;

  const MuralDaMesa({
    super.key,
    required this.servico,
    required this.mesaId,
    required this.souMestre,
  });

  @override
  State<MuralDaMesa> createState() => _MuralDaMesaState();
}

class _MuralDaMesaState extends State<MuralDaMesa> {
  MesaService get servico => widget.servico;
  String get mesaId => widget.mesaId;

  /// Reduzir uma foto grande e subir leva alguns segundos: sem retorno visual
  /// o mestre toca de novo e manda a mesma imagem duas vezes.
  bool _enviando = false;

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _mostrarImagem() async {
    if (_enviando) return;
    final id = await escolherRetrato(context);
    if (id == null || !mounted) return;

    final legenda = await _pedirLegenda();
    if (!mounted) return;

    setState(() => _enviando = true);
    try {
      final bytes = ImagemStore.bytes(id);
      if (bytes == null) throw Exception('Não consegui ler a imagem.');
      await servico.mostrarNoMural(
          mesaId, ImagemMural.preparar(bytes), legenda ?? '');
      // a cópia local só existia para chegar até aqui: o mural carrega a sua
      await ImagemStore.excluir(id);
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<String?> _pedirLegenda() {
    final campo = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Legenda (opcional)'),
        content: TextField(
          controller: campo,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Ex.: o mapa que vocês acham na mesa'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Sem legenda')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, campo.text.trim()),
            child: const Text('Mostrar', style: TextStyle(color: Cores.indigo)),
          ),
        ],
      ),
    );
  }

  Future<void> _tirar() async {
    try {
      await servico.limparMural(mesaId);
    } catch (e) {
      _erro(e);
    }
  }

  void _abrirTelaCheia(ItemMural item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': base64Decode(item.imagemBase64)},
        legendas: {'mural': item.legenda},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ItemMural?>(
      stream: servico.observarMural(mesaId),
      builder: (context, snap) {
        if (_enviando) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final item = snap.data;
        return item == null ? _vazio() : _comImagem(item);
      },
    );
  }

  Widget _vazio() {
    if (!widget.souMestre) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'O mestre ainda não mostrou nenhuma imagem. Quando mostrar, ela '
            'abre sozinha aqui — e continua nesta tela para você olhar de novo '
            'quando quiser.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A imagem abre em tela cheia no aparelho de todo mundo que está '
              'na mesa, e fica disponível aqui até você tirar.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _mostrarImagem,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Mostrar imagem para a mesa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comImagem(ItemMural item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            InkWell(
              onTap: () => _abrirTelaCheia(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  base64Decode(item.imagemBase64),
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 120,
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
              ),
            ),
            if (item.legenda.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.legenda,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _abrirTelaCheia(item),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Ver em tela cheia'),
                ),
                if (widget.souMestre)
                  TextButton.icon(
                    onPressed: _tirar,
                    icon: const Icon(Icons.visibility_off_outlined, size: 18),
                    label: const Text('Tirar do mural'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
