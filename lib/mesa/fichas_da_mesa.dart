import 'package:flutter/material.dart';

import '../models/ficha.dart';
import '../store/ficha_store.dart';
import 'mesa_firestore.dart';
import 'mesa_service.dart';
import 'mesa_store.dart';
import 'modelos.dart';

/// Entrega ao [builder] as fichas que os jogadores publicaram na mesa.
///
/// Fora de mesa — ou para quem não é o mestre — a lista vem vazia e nada de
/// rede acontece: o app segue offline igual. As fichas nunca entram no Hive;
/// são cópias ao vivo, e somem sozinhas quando o jogador despublica, sai, ou
/// o mestre fecha a mesa.
class FichasDaMesa extends StatefulWidget {
  final MesaService? servico;
  final Widget Function(BuildContext context, List<Ficha> daMesa) builder;

  const FichasDaMesa({super.key, required this.builder, this.servico});

  @override
  State<FichasDaMesa> createState() => _FichasDaMesaState();
}

class _FichasDaMesaState extends State<FichasDaMesa> {
  late final MesaService _servico;
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _servico = widget.servico ?? MesaFirestore();
    _conectar();
  }

  /// Esta aba pode ser a primeira a abrir: sem refazer o login, observar a
  /// mesa estoura porque o Firebase nem foi inicializado.
  Future<void> _conectar() async {
    if (!_souMestreDeAlgumaMesa) return;
    try {
      await _servico.entrarAnonimo();
      if (mounted) setState(() => _pronto = true);
    } catch (_) {
      // sem internet a galeria continua mostrando só o que é local
    }
  }

  bool get _souMestreDeAlgumaMesa =>
      MesaStore.atual?.papel == PapelMesa.mestre;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MesaStore.listenable,
      builder: (context, _, _) {
        final estado = MesaStore.atual;
        if (estado == null || estado.papel != PapelMesa.mestre) {
          return widget.builder(context, const []);
        }
        if (!_pronto) {
          // entrou na mesa agora: conecta e reconstrói quando estiver de pé
          _conectar();
          return widget.builder(context, const []);
        }
        return StreamBuilder<List<FichaNaMesa>>(
          stream: _servico.observarFichas(estado.mesaId),
          builder: (context, snap) {
            final naMesa = snap.data ?? const <FichaNaMesa>[];
            final fichas = <Ficha>[];
            for (final f in naMesa) {
              // a ficha que o próprio mestre publicou já está no Hive dele
              if (f.donoUid == estado.uid) continue;
              fichas.add(Ficha(Map<String, dynamic>.from(f.ficha)));
            }
            return widget.builder(context, fichas);
          },
        );
      },
    );
  }
}

/// Junta as fichas locais com as da mesa, sem duplicar.
///
/// Quando o mesmo id aparece dos dois lados — o mestre importou o JSON do
/// jogador antes da sessão, por exemplo — vale a da mesa: é a que está viva.
({List<Ficha> todas, Set<String> idsDaMesa}) juntarComAsLocais(
    List<Ficha> daMesa) {
  final ids = {for (final f in daMesa) f.id};
  return (
    todas: [...daMesa, ...FichaStore.todas().where((f) => !ids.contains(f.id))],
    idsDaMesa: ids,
  );
}
