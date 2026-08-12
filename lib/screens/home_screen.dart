import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ficha.dart';
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

  Future<void> _importar(BuildContext context) async {
    try {
      final f = await FichaIO.importarJson();
      if (f == null) return;
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
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao importar: $e')),
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
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'importar',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: Cores.indigo),
                    SizedBox(width: 8),
                    Text('Importar ficha (JSON)'),
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
