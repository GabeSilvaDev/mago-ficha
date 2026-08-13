import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../models/ficha.dart';
import '../../screens/ficha_view_screen.dart';
import '../../store/imagem_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../imagem_mural.dart';
import '../mesa_service.dart';

/// O que o mestre vê e controla da sessão: o mural e as fichas publicadas.
///
/// As fichas são só leitura, sempre. A ficha é do jogador; aqui é a janela
/// para ela.
class PainelMestre extends StatefulWidget {
  final MesaService servico;
  final String mesaId;

  const PainelMestre({super.key, required this.servico, required this.mesaId});

  @override
  State<PainelMestre> createState() => _PainelMestreState();
}

class _PainelMestreState extends State<PainelMestre> {
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

  /// O mural: uma imagem por vez, que abre sozinha para todo mundo na mesa.
  Widget _mural() {
    return StreamBuilder<ItemMural?>(
      stream: servico.observarMural(mesaId),
      builder: (context, snap) {
        final item = snap.data;
        if (_enviando) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (item == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A imagem abre em tela cheia no aparelho de todo mundo '
                    'que está na mesa.',
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    base64Decode(item.imagemBase64),
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 90,
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
                if (item.legenda.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.legenda,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                TextButton.icon(
                  onPressed: _tirar,
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: const Text('Tirar do mural'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FaixaSecao('Mural da mesa'),
        _mural(),
        const FaixaSecao('Fichas da sessão'),
        _fichas(),
      ],
    );
  }

  Widget _fichas() {
    return StreamBuilder<List<FichaNaMesa>>(
      stream: servico.observarFichas(mesaId),
      builder: (context, snap) {
        final fichas = snap.data ?? const <FichaNaMesa>[];
        if (fichas.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Ninguém publicou ficha nesta mesa ainda. Peça para o pessoal '
                'entrar e publicar na aba Mesa.',
              ),
            ),
          );
        }
        final ordenadas = [...fichas]
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return Column(
          children: [for (final f in ordenadas) _cartao(context, f)],
        );
      },
    );
  }

  Widget _cartao(BuildContext context, FichaNaMesa naMesa) {
    // O JSON da mesa é o mesmo do export: o próprio model já sabe lê-lo.
    final ficha = Ficha(Map<String, dynamic>.from(naMesa.ficha));
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              FichaViewScreen(fichaDireta: ficha, somenteLeitura: true),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _retrato(naMesa.ficha['retrato']),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(naMesa.nome.isEmpty ? 'Sem nome' : naMesa.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Cores.indigo)),
                    Text(_vitalidade(ficha),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Arete ${ficha.areteFinal} · '
                      'FdV ${ficha.fdvAtual}/${ficha.forcaVontadeFinal} · '
                      'Quint. ${ficha.quintessencia} · '
                      'Paradoxo ${ficha.paradoxo} · '
                      'XP ${ficha.experiencia}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'atualizada ${_desde(naMesa.atualizadaEm)}',
                      style: const TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// O retrato vem embutido no JSON (base64), não pelo `ImagemStore`: a
  /// imagem é do aparelho do jogador.
  Widget _retrato(Object? base64) {
    Widget miolo = const Icon(Icons.person, color: Cores.pergaminho, size: 26);
    if (base64 is String && base64.isNotEmpty) {
      try {
        miolo = ClipOval(
          child: Image.memory(base64Decode(base64),
              width: 48, height: 48, fit: BoxFit.cover),
        );
      } catch (_) {
        // base64 estragado não derruba o painel do mestre no meio da sessão
      }
    }
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Cores.indigo,
        border: Border.all(color: Cores.dourado, width: 1.5),
      ),
      child: miolo,
    );
  }

  String _vitalidade(Ficha f) {
    final dano = f.vitalidadeDano;
    if (dano <= 0) return 'Ileso';
    final i = (dano - 1).clamp(0, GameData.niveisVitalidade.length - 1);
    return GameData.niveisVitalidade[i][0];
  }

  String _desde(DateTime quando) {
    final s = DateTime.now().difference(quando).inSeconds;
    if (s < 60) return 'agora';
    if (s < 3600) return 'há ${s ~/ 60} min';
    if (s < 86400) return 'há ${s ~/ 3600} h';
    return 'há ${s ~/ 86400} d';
  }
}
