import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/nota.dart';
import '../../store/nota_store.dart';
import '../../theme.dart';
import 'nota_screen.dart';

/// Lista dos cadernos do narrador, com busca por título, texto e tag.
class CadernosAba extends StatefulWidget {
  const CadernosAba({super.key});

  @override
  State<CadernosAba> createState() => _CadernosAbaState();
}

class _CadernosAbaState extends State<CadernosAba> {
  String _busca = '';
  String? _tag;

  Future<void> _abrir([Nota? n]) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NotaScreen(existente: n)));
    if (mounted) setState(() {});
  }

  Future<void> _confirmarExcluir(Nota n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Excluir caderno?'),
        content: Text(
            'Excluir "${n.titulo.isEmpty ? 'Sem título' : n.titulo}"? '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Cores.indigo))),
        ],
      ),
    );
    if (ok == true) await NotaStore.excluir(n.id);
  }

  String _resumo(Nota n) {
    final linha = n.texto.trim().split('\n').first;
    return linha.length > 90 ? '${linha.substring(0, 90)}…' : linha;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: NotaStore.listenable,
      builder: (context, Box<String> box, _) {
        final tags = NotaStore.tags();
        // tag pode ter sumido junto com a última nota que a usava
        if (_tag != null && !tags.contains(_tag)) _tag = null;
        final notas = NotaStore.buscar(_busca, tag: _tag);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar em título, texto e tags',
                      ),
                      onChanged: (v) => setState(() => _busca = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Novo caderno',
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: _abrir,
                  ),
                ],
              ),
            ),
            if (tags.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          key: ValueKey('tag-$t'),
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          selected: _tag == t,
                          visualDensity: VisualDensity.compact,
                          onSelected: (sel) =>
                              setState(() => _tag = sel ? t : null),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: notas.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhum caderno ainda.\n'
                          'Anote sessões, NPCs, pistas e ganchos — com imagens '
                          'e tags para achar depois.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: notas.length,
                      itemBuilder: (_, i) {
                        final n = notas[i];
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                if (n.fixada)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.push_pin,
                                        size: 14, color: Cores.dourado),
                                  ),
                                Expanded(
                                  child: Text(
                                      n.titulo.isEmpty
                                          ? 'Sem título'
                                          : n.titulo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Cores.indigo)),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (n.texto.trim().isNotEmpty)
                                  Text(_resumo(n),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                if (n.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      children: [
                                        for (final t in n.tags)
                                          Chip(
                                            label: Text(t,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                            visualDensity:
                                                VisualDensity.compact,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (n.imagens.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.image_outlined,
                                            size: 18, color: Cores.indigoClaro),
                                        Text('${n.imagens.length}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Cores.indigoClaro)),
                                      ],
                                    ),
                                  ),
                                if (n.fichas.isNotEmpty)
                                  const Icon(Icons.people_outline,
                                      size: 18, color: Cores.indigoClaro),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Cores.indigoClaro),
                                  onPressed: () => _confirmarExcluir(n),
                                ),
                              ],
                            ),
                            onTap: () => _abrir(n),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
