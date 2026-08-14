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
///
/// Legenda e acervo moram na [GaleriaMesa]; aqui é só o que está em destaque
/// agora, sem precisar ler mais nada além do próprio mural.
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

    final resultado = await _pedirLegenda();
    if (resultado == null || !mounted) return;
    final (legenda, mostrarAgora) = resultado;

    setState(() => _enviando = true);
    try {
      final bytes = ImagemStore.bytes(id);
      if (bytes == null) throw Exception('Não consegui ler a imagem.');
      final imagemId = await servico.guardarNaGaleria(
        mesaId,
        ImagemMural.preparar(bytes),
        ImagemMural.miniatura(bytes),
        legenda,
      );
      if (mostrarAgora) await servico.mostrarAgora(mesaId, imagemId);
      // a cópia local só existia para chegar até aqui: a galeria guarda a sua
      await ImagemStore.excluir(id);
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// null quando cancela. Do contrário, a legenda e se é para pôr em
  /// destaque agora ou só guardar no acervo.
  Future<(String, bool)?> _pedirLegenda() {
    final campo = TextEditingController();
    return showDialog<(String, bool)>(
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (campo.text.trim(), false)),
            child: const Text('Guardar na galeria'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (campo.text.trim(), true)),
            child: const Text('Mostrar agora',
                style: TextStyle(color: Cores.indigo)),
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
        if (item == null) return _vazio();
        // a key troca quando o destaque muda: o estado (e o Future já em
        // andamento) reinicia do zero para a imagem nova, sem precisar
        // comparar imagemId dentro do build para decidir se refaz a busca.
        return _CartaoDestaque(
          key: ValueKey(item.imagemId),
          servico: servico,
          mesaId: mesaId,
          imagemId: item.imagemId,
          souMestre: widget.souMestre,
          aoTirar: _tirar,
        );
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
}

/// A imagem em destaque, sozinha: busca a imagem cheia uma vez em
/// `initState` e não de novo — a `key: ValueKey(imagemId)` do pai garante que
/// uma imagem nova recria este estado, e uma imagem igual não teria por que
/// refazer a busca.
class _CartaoDestaque extends StatefulWidget {
  final MesaService servico;
  final String mesaId;
  final String imagemId;
  final bool souMestre;
  final VoidCallback aoTirar;

  const _CartaoDestaque({
    super.key,
    required this.servico,
    required this.mesaId,
    required this.imagemId,
    required this.souMestre,
    required this.aoTirar,
  });

  @override
  State<_CartaoDestaque> createState() => _CartaoDestaqueState();
}

class _CartaoDestaqueState extends State<_CartaoDestaque> {
  late final Future<String?> _futuro =
      widget.servico.imagemCheia(widget.mesaId, widget.imagemId);

  void _abrirTelaCheia(String imagemBase64) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': base64Decode(imagemBase64)},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _futuro,
      builder: (context, snap) {
        // `hasData` não serve aqui: a busca pode terminar com `null` (imagem
        // não existe mais), e `hasData` só olha se `data != null` — travaria
        // no carregando para sempre. O que importa é se já terminou.
        if (snap.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final imagemBase64 = snap.data;
        if (imagemBase64 == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Imagem não encontrada.'),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _abrirTelaCheia(imagemBase64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      base64Decode(imagemBase64),
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _abrirTelaCheia(imagemBase64),
                      icon: const Icon(Icons.open_in_full, size: 18),
                      label: const Text('Ver em tela cheia'),
                    ),
                    if (widget.souMestre)
                      TextButton.icon(
                        onPressed: widget.aoTirar,
                        icon:
                            const Icon(Icons.visibility_off_outlined, size: 18),
                        label: const Text('Tirar do mural'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
