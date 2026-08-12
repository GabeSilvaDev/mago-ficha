import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ficha.dart';
import '../services/backup_io.dart';
import '../services/ficha_io.dart';
import '../store/ficha_store.dart';
import '../theme.dart';
import '../widgets/retrato.dart';
import 'wizard_screen.dart';
import 'ficha_view_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _criar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WizardScreen()),
    );
  }

  void _abrir(BuildContext context, Ficha f) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FichaViewScreen(fichaId: f.id)),
    );
  }

  /// Importa ficha única (.json) ou backup inteiro (.zip). O backup só grava
  /// depois de mostrar o resumo e perguntar o que fazer com as repetidas.
  Future<void> _importar(BuildContext context) async {
    try {
      final escolhido = await BackupIO.escolherArquivo();
      if (escolhido == null) return;
      final (nome, bytes) = escolhido;

      if (!nome.toLowerCase().endsWith('.zip')) {
        final f = await FichaIO.deJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        await FichaStore.salvar(f);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Ficha "${f.nome.isEmpty ? 'Sem nome' : f.nome}" importada.')),
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FichaViewScreen(fichaId: f.id)),
        );
        return;
      }

      final resumo = BackupIO.lerZip(bytes);
      if (!context.mounted) return;
      final politica = await _confirmarBackup(context, resumo);
      if (politica == null || !context.mounted) return;
      final n = await BackupIO.aplicar(resumo, politica);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n ficha(s) importada(s).')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao importar: $e')),
      );
    }
  }

  /// Mostra o que vem no backup e pergunta o que fazer com as repetidas.
  Future<PoliticaColisao?> _confirmarBackup(
      BuildContext context, ResumoBackup r) {
    return showDialog<PoliticaColisao>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Importar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.total} ficha(s) no arquivo.'),
            if (r.colidem.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${r.colidem.length} já existe(m) neste aparelho:'),
              Text(r.colidem.join(', '),
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              const Text('O que fazer com elas?'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          if (r.colidem.isNotEmpty) ...[
            TextButton(
                onPressed: () => Navigator.pop(ctx, PoliticaColisao.pular),
                child: const Text('Pular')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, PoliticaColisao.substituir),
                child: const Text('Substituir')),
          ],
          TextButton(
              onPressed: () => Navigator.pop(ctx, PoliticaColisao.duplicar),
              child: Text(r.colidem.isEmpty ? 'Importar' : 'Duplicar')),
        ],
      ),
    );
  }

  Future<void> _exportarTudo(BuildContext context) async {
    try {
      await BackupIO.exportarTudo();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar: $e')),
      );
    }
  }

  Future<void> _exportar(BuildContext context, Ficha f) async {
    try {
      await FichaIO.exportarJson(f);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAGO: A ASCENSÃO'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: Cores.pergaminho,
            onSelected: (v) {
              if (v == 'importar') _importar(context);
              if (v == 'exportar') _exportarTudo(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'importar',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: Cores.indigo),
                    SizedBox(width: 8),
                    Text('Importar (JSON ou ZIP)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'exportar',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Cores.indigo),
                    SizedBox(width: 8),
                    Text('Exportar tudo (.zip)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: FichaStore.listenable,
        builder: (context, Box<String> box, _) {
          final fichas = FichaStore.todas();
          return Column(
            children: [
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => _criar(context),
                icon: const Icon(Icons.auto_awesome, size: 24),
                label: const Text('CRIAR PERSONAGEM'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: fichas.isEmpty
                    ? const _Vazio()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: fichas.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                              child: Text('Seus magos',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Cores.indigo,
                                      fontSize: 16)),
                            );
                          }
                          final f = fichas[i - 1];
                          return _CartaoFicha(
                            ficha: f,
                            onTap: () => _abrir(context, f),
                            onExportar: () => _exportar(context, f),
                            onExcluir: () => _confirmarExcluir(context, f),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarExcluir(BuildContext context, Ficha f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Excluir ficha?'),
        content: Text(
            'Tem certeza que deseja excluir "${f.nome.isEmpty ? 'Sem nome' : f.nome}"? Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok == true) await FichaStore.excluir(f.id);
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nenhum mago ainda.\nToque em CRIAR PERSONAGEM para começar,\nou importe uma ficha JSON no menu ⋮.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Cores.tinta, fontSize: 16),
        ),
      ),
    );
  }
}

class _CartaoFicha extends StatelessWidget {
  final Ficha ficha;
  final VoidCallback onTap;
  final VoidCallback onExportar;
  final VoidCallback onExcluir;
  const _CartaoFicha({
    required this.ficha,
    required this.onTap,
    required this.onExportar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (ficha.grupo.isNotEmpty) ficha.grupo,
      if (ficha.conceito.isNotEmpty) ficha.conceito,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: RetratoAvatar(retratoId: ficha.retratoId, tamanho: 44),
        title: Text(ficha.nome.isEmpty ? 'Sem nome' : ficha.nome,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Cores.indigo)),
        subtitle: Text(sub.isEmpty ? 'Mago sem detalhes' : sub),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Cores.indigoClaro),
          color: Cores.pergaminho,
          onSelected: (v) {
            if (v == 'exportar') onExportar();
            if (v == 'excluir') onExcluir();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'exportar',
              child: Row(
                children: [
                  Icon(Icons.file_download_outlined, color: Cores.indigo),
                  SizedBox(width: 8),
                  Text('Exportar JSON'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'excluir',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Cores.indigo),
                  SizedBox(width: 8),
                  Text('Excluir'),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
