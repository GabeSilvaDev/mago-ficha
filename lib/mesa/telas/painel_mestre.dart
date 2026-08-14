import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../models/ficha.dart';
import '../../screens/ficha_view_screen.dart';
import '../../theme.dart';
import '../mesa_service.dart';

/// As fichas que os jogadores publicaram, ao vivo.
///
/// Só leitura, sempre. A ficha é do jogador; aqui é a janela para ela. O
/// mural mora em `MuralDaMesa`, porque não é só do mestre: todo mundo na mesa
/// precisa poder reabrir a imagem.
class PainelMestre extends StatelessWidget {
  final MesaService servico;
  final String mesaId;

  const PainelMestre({super.key, required this.servico, required this.mesaId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                    // Quintessência e Paradoxo têm dois valores cada: o da
                    // criação (`quintessencia`, `paradoxo`) e o da mesa
                    // (`quintAtual`, `paradoxoAtual`), que é o que os +/− da
                    // ficha mexem. Aqui é acompanhamento de sessão, então vale
                    // o segundo — como já valia para a Força de Vontade.
                    Text(
                      'Arete ${ficha.areteFinal} · '
                      'FdV ${ficha.fdvAtual}/${ficha.forcaVontadeFinal} · '
                      'Quint. ${ficha.quintAtual} · '
                      'Paradoxo ${ficha.paradoxoAtual} · '
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
