import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../mesa/fichas_da_mesa.dart';
import '../../mesa/mesa_service.dart';
import '../../models/campo_narrador.dart';
import '../../models/ficha.dart';
import '../../store/ficha_store.dart';
import '../../store/narrador_store.dart';
import '../../theme.dart';
import '../../widgets/retrato.dart';
import '../ficha_view_screen.dart';
import '../wizard_screen.dart';
import 'campos_config_screen.dart';
import 'galeria_ordem.dart';

/// Galeria de personagens: cards com retrato e os campos que o narrador
/// escolheu mostrar, com filtro por tipo e ordenação por característica.
///
/// Durante uma sessão, as fichas que os jogadores publicaram entram aqui
/// junto com as locais — só para consulta. [servico] existe para o teste
/// injetar o fake.
class GaleriaAba extends StatefulWidget {
  final MesaService? servico;
  const GaleriaAba({super.key, this.servico});

  @override
  State<GaleriaAba> createState() => _GaleriaAbaState();
}

class _GaleriaAbaState extends State<GaleriaAba> {
  FiltroTipo _tipo = FiltroTipo.todos;
  CampoNarrador? _ordem;
  bool _crescente = true;
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final campos = NarradorStore.campos();
    // a definição de campo pode ter sido apagada enquanto estava selecionada
    if (_ordem != null && !campos.any((c) => c.id == _ordem!.id)) _ordem = null;

    return FichasDaMesa(
      servico: widget.servico,
      builder: (context, daMesa) => ValueListenableBuilder(
        valueListenable: FichaStore.listenable,
        builder: (context, Box<String> box, _) {
          final juncao = juntarComAsLocais(daMesa);
          final lista = GaleriaOrdem.aplicar(
            juncao.todas,
            tipo: _tipo,
            ordenarPor: _ordem,
            crescente: _crescente,
            busca: _busca,
          );
          return _corpo(context, lista, campos, juncao.idsDaMesa);
        },
      ),
    );
  }

  Widget _corpo(BuildContext context, List<Ficha> lista,
      List<CampoNarrador> campos, Set<String> idsDaMesa) {
    return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar pelo nome',
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final opcao in const [
                    (FiltroTipo.todos, 'Todos', 'filtro-todos'),
                    (FiltroTipo.pcs, 'Jogadores', 'filtro-pcs'),
                    (FiltroTipo.npcs, 'NPCs', 'filtro-npcs'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey(opcao.$3),
                        label: Text(opcao.$2),
                        selected: _tipo == opcao.$1,
                        onSelected: (_) => setState(() => _tipo = opcao.$1),
                      ),
                    ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _ordem?.id ?? '',
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Nome')),
                      for (final c in campos)
                        DropdownMenuItem(value: c.id, child: Text(c.nome)),
                    ],
                    onChanged: (v) => setState(() => _ordem =
                        (v == null || v.isEmpty)
                            ? null
                            : campos.firstWhere((c) => c.id == v)),
                  ),
                  IconButton(
                    tooltip: _crescente ? 'Crescente' : 'Decrescente',
                    icon: Icon(
                        _crescente ? Icons.arrow_upward : Icons.arrow_downward),
                    onPressed: () => setState(() => _crescente = !_crescente),
                  ),
                  IconButton(
                    tooltip: 'Novo NPC (ficha completa, modo livre)',
                    icon: const Icon(Icons.person_add_alt),
                    onPressed: () async {
                      // mesmo passo a passo do jogador; `criarNpc` já entra em
                      // modo livre, então nenhum limite trava o narrador
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              WizardScreen(inicial: Ficha.criarNpc())));
                      if (mounted) setState(() {});
                    },
                  ),
                  IconButton(
                    tooltip: 'Campos customizados',
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CamposConfigScreen()));
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhum personagem por aqui.\n'
                          'Crie um mago na aba Magos, ou um NPC no ícone de '
                          'pessoa acima.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: lista.length,
                      itemBuilder: (_, i) =>
                          _card(lista[i], campos, idsDaMesa.contains(lista[i].id)),
                    ),
            ),
          ],
    );
  }

  Widget _card(Ficha f, List<CampoNarrador> campos, bool daMesa) {
    // no máximo três campos, senão o card vira tabela
    final mostrar = campos.take(3).toList();
    return Card(
      child: InkWell(
        onTap: () async {
          // NPC é uma ficha normal: abre a mesma tela do personagem de jogador.
          // A da mesa não está no Hive daqui e é do jogador: abre só leitura.
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => daMesa
                  ? FichaViewScreen(fichaDireta: f, somenteLeitura: true)
                  : FichaViewScreen(fichaId: f.id)));
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: RetratoAvatar(retratoId: f.retratoId, tamanho: 76)),
              const SizedBox(height: 8),
              Text(f.nome.isEmpty ? 'Sem nome' : f.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Cores.indigo)),
              if (daMesa)
                const Text('na mesa · só leitura',
                    style: TextStyle(
                        fontSize: 11,
                        color: Cores.indigoClaro,
                        fontStyle: FontStyle.italic))
              else if (f.ehNpc)
                const Text('NPC',
                    style: TextStyle(fontSize: 11, color: Cores.indigoClaro)),
              const SizedBox(height: 4),
              for (final c in mostrar)
                if (c.textoDe(f).isNotEmpty)
                  Text('${c.nome}: ${c.textoDe(f)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
