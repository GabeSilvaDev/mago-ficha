import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ficha.dart';
import '../services/backup_io.dart';
import '../services/ficha_io.dart';
import '../store/ficha_store.dart';
import '../theme.dart';
import '../widgets/layout.dart';
import '../widgets/retrato.dart';
import 'wizard_screen.dart';
import 'ficha_view_screen.dart';
import '../mesa/telas/mesa_aba.dart';
import 'narrador/narrador_screen.dart';

/// Duas áreas: a lista de magos dos jogadores e a área do narrador.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;

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
        if (!context.mounted) return;
        // JSON exportado antes do campo `tipo` existir chega como jogador
        final comoNpc = await _perguntarTipo(context, f.nome);
        if (comoNpc == null) return;
        if (comoNpc) f.ehNpc = true;
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
      final escolha = await _confirmarBackup(context, resumo);
      if (escolha == null || !context.mounted) return;
      final n = await BackupIO.aplicar(resumo, escolha.$1,
          marcarComoNpc: escolha.$2);
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

  /// Ficha única: jogador ou NPC? Devolve null se cancelar.
  Future<bool?> _perguntarTipo(BuildContext context, String nome) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Importar como'),
        content: Text('"${nome.isEmpty ? 'Sem nome' : nome}" entra como '
            'personagem de jogador ou NPC do narrador?\n\n'
            'Dá para trocar depois, na aba Personagem da ficha.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('NPC')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Jogador',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
  }

  /// Mostra o que vem no backup, pergunta o que fazer com as repetidas e se
  /// o lote inteiro entra como NPC. Devolve (política, marcarComoNpc).
  Future<(PoliticaColisao, bool)?> _confirmarBackup(
      BuildContext context, ResumoBackup r) {
    var comoNpc = false;
    return showDialog<(PoliticaColisao, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: const Text('Importar backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.total} ficha(s) no arquivo.'),
              if (r.notas.isNotEmpty) Text('${r.notas.length} caderno(s).'),
              if (r.camposNarrador.isNotEmpty)
                Text('${r.camposNarrador.length} campo(s) do narrador '
                    '(substituem os atuais).'),
              CheckboxListTile(
                key: const ValueKey('importar-como-npc'),
                value: comoNpc,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Marcar todas como NPC',
                    style: TextStyle(fontSize: 14)),
                onChanged: (v) => setLocal(() => comoNpc = v ?? false),
              ),
              if (r.colidem.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                  onPressed: () =>
                      Navigator.pop(ctx, (PoliticaColisao.pular, comoNpc)),
                  child: const Text('Pular')),
              TextButton(
                  onPressed: () => Navigator.pop(
                      ctx, (PoliticaColisao.substituir, comoNpc)),
                  child: const Text('Substituir')),
            ],
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, (PoliticaColisao.duplicar, comoNpc)),
                child: Text(r.colidem.isEmpty ? 'Importar' : 'Duplicar')),
          ],
        ),
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
    final larga = telaLarga(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['MAGO: A ASCENSÃO', 'MESA', 'NARRADOR'][_aba]),
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
      // No PC a navegação vai para a lateral: barra inferior em tela larga
      // deixa um vão enorme no meio e obriga a mira do mouse a atravessar a
      // tela inteira.
      body: larga
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _aba,
                  onDestinationSelected: (i) => setState(() => _aba = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Cores.pergaminhoEscuro,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        selectedIcon: Icon(Icons.auto_awesome),
                        label: Text('Magos')),
                    NavigationRailDestination(
                        icon: Icon(Icons.groups_outlined),
                        selectedIcon: Icon(Icons.groups),
                        label: Text('Mesa')),
                    NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('Narrador')),
                  ],
                ),
                const VerticalDivider(width: 1, color: Cores.dourado),
                Expanded(child: Miolo(child: _corpo(context))),
              ],
            )
          : _corpo(context),
      bottomNavigationBar: larga
          ? null
          : NavigationBar(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'Magos'),
                NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: 'Mesa'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'Narrador'),
              ],
            ),
    );
  }

  Widget _corpo(BuildContext context) => IndexedStack(
        index: _aba,
        children: [
          _abaMagos(context),
          // a Mesa fica no meio porque o jogador precisa alcançar ela, e ele
          // nunca abre a aba Narrador
          const MesaAba(),
          const NarradorScreen(),
        ],
      );

  /// Lista dos magos dos jogadores. NPCs ficam só na galeria do narrador.
  Widget _abaMagos(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: FichaStore.listenable,
        builder: (context, Box<String> box, _) {
          final fichas =
              FichaStore.todas().where((f) => !f.ehNpc).toList();
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
        });
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
