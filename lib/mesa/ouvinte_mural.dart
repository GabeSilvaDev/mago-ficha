import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/narrador/visualizador_imagens.dart';
import 'mesa_service.dart';

/// Abre em tela cheia a imagem que o mestre põe no mural.
///
/// Envolve a tela principal enquanto o aparelho está numa mesa. Fora de mesa
/// ninguém constrói este widget, então nada é assinado.
class OuvinteMural extends StatefulWidget {
  final MesaService servico;
  final String mesaId;
  final Widget child;

  const OuvinteMural({
    super.key,
    required this.servico,
    required this.mesaId,
    required this.child,
  });

  @override
  State<OuvinteMural> createState() => _OuvinteMuralState();
}

class _OuvinteMuralState extends State<OuvinteMural> {
  StreamSubscription<ItemMural?>? _assinatura;

  /// Quando a imagem que já está aberta foi posta. Sem isso a tela reabre a
  /// cada emissão do stream, inclusive na primeira, que só repete o que já
  /// estava lá.
  DateTime? _ultimoAberto;

  @override
  void initState() {
    super.initState();
    _assinar();
  }

  /// O login vem antes de observar: o app pode ter aberto já dentro da mesa,
  /// e aí o Firebase sequer foi inicializado. Sem internet o mural
  /// simplesmente não aparece — o resto do app continua igual.
  Future<void> _assinar() async {
    try {
      await widget.servico.entrarAnonimo();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _assinatura = widget.servico.observarMural(widget.mesaId).listen(
          _aoMudar,
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    super.dispose();
  }

  void _aoMudar(ItemMural? item) {
    if (item == null || item.imagemBase64.isEmpty) return;
    if (_ultimoAberto != null && !item.em.isAfter(_ultimoAberto!)) return;
    _ultimoAberto = item.em;
    _abrir(item);
  }

  void _abrir(ItemMural item) {
    if (!mounted) return;
    final bytes = base64Decode(item.imagemBase64);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisualizadorImagens(
        imagens: const ['mural'],
        bytesDiretos: {'mural': bytes},
        legendas: {'mural': item.legenda},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
