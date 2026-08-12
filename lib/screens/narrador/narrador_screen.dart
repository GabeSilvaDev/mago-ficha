import 'package:flutter/material.dart';

import '../../theme.dart';
import 'cadernos_aba.dart';
import 'galeria_aba.dart';

/// Área do narrador: galeria de personagens e cadernos de anotação.
class NarradorScreen extends StatelessWidget {
  const NarradorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Cores.indigo,
            labelColor: Cores.indigo,
            tabs: [Tab(text: 'Galeria'), Tab(text: 'Cadernos')],
          ),
          Expanded(child: TabBarView(children: [GaleriaAba(), CadernosAba()])),
        ],
      ),
    );
  }
}
