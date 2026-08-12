import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../store/imagem_store.dart';
import '../../theme.dart';

/// Abre as imagens de um caderno em tela cheia: zoom, arrastar e deslizar
/// entre elas.
///
/// O **modo mostrar** (ícone de olho) apaga a interface e deixa só a imagem em
/// fundo preto — é o estado em que o narrador vira o celular para a mesa sem
/// mostrar título, legenda ou botão nenhum. Toque na imagem entra e sai dele.
class VisualizadorImagens extends StatefulWidget {
  final List<String> imagens;
  final Map<String, String> legendas;
  final int inicial;

  const VisualizadorImagens({
    super.key,
    required this.imagens,
    this.legendas = const {},
    this.inicial = 0,
  });

  @override
  State<VisualizadorImagens> createState() => _VisualizadorImagensState();
}

class _VisualizadorImagensState extends State<VisualizadorImagens> {
  late final PageController _pagina;
  late int _atual;
  bool _mostrando = false;

  @override
  void initState() {
    super.initState();
    _atual = widget.inicial.clamp(0, widget.imagens.length - 1);
    _pagina = PageController(initialPage: _atual);
  }

  @override
  void dispose() {
    _pagina.dispose();
    // desfaz a tela cheia do modo mostrar, se sair por ali
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _alternarMostrar() {
    setState(() => _mostrando = !_mostrando);
    SystemChrome.setEnabledSystemUIMode(
      _mostrando ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
    );
  }

  String get _legendaAtual =>
      widget.legendas[widget.imagens[_atual]] ?? '';

  @override
  Widget build(BuildContext context) {
    final total = widget.imagens.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _mostrando
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Cores.pergaminho,
              title: Text(
                total > 1 ? '${_atual + 1} de $total' : 'Imagem',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                IconButton(
                  key: const ValueKey('modo-mostrar'),
                  tooltip: 'Modo mostrar (esconde tudo)',
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: _alternarMostrar,
                ),
              ],
            ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pagina,
            itemCount: total,
            onPageChanged: (i) => setState(() => _atual = i),
            itemBuilder: (_, i) {
              final bytes = ImagemStore.bytes(widget.imagens[i]);
              if (bytes == null) {
                return const Center(
                  child: Text('Imagem não encontrada.',
                      style: TextStyle(color: Colors.white70)),
                );
              }
              return GestureDetector(
                // toque simples entra e sai do modo mostrar
                onTap: _alternarMostrar,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(child: Image.memory(bytes)),
                ),
              );
            },
          ),
          if (!_mostrando && _legendaAtual.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: SafeArea(
                  top: false,
                  child: Text(
                    _legendaAtual,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Cores.pergaminho, fontSize: 14),
                  ),
                ),
              ),
            ),
          if (_mostrando)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: IconButton(
                  key: const ValueKey('sair-modo-mostrar'),
                  tooltip: 'Sair do modo mostrar',
                  icon: const Icon(Icons.close, color: Colors.white24),
                  onPressed: _alternarMostrar,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
