import '../../models/campo_narrador.dart';
import '../../models/ficha.dart';

enum FiltroTipo { todos, pcs, npcs }

/// Regras de lista da galeria, separadas do widget para poderem ser testadas
/// sem montar tela.
class GaleriaOrdem {
  static List<Ficha> aplicar(
    List<Ficha> fichas, {
    FiltroTipo tipo = FiltroTipo.todos,
    CampoNarrador? ordenarPor,
    bool crescente = true,
    String busca = '',
    CampoNarrador? campoTag,
    String? tagFiltro,
  }) {
    final termo = busca.trim().toLowerCase();
    final lista = fichas.where((f) {
      if (tipo == FiltroTipo.pcs && f.ehNpc) return false;
      if (tipo == FiltroTipo.npcs && !f.ehNpc) return false;
      if (termo.isNotEmpty && !f.nome.toLowerCase().contains(termo)) {
        return false;
      }
      if (campoTag != null && tagFiltro != null && tagFiltro.isNotEmpty) {
        if (campoTag.textoDe(f) != tagFiltro) return false;
      }
      return true;
    }).toList();

    lista.sort((a, b) {
      if (ordenarPor == null) {
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
      final va = ordenarPor.valorDe(a);
      final vb = ordenarPor.valorDe(b);
      // quem não tem valor no campo fica sempre no fim, nos dois sentidos
      if (va == null && vb == null) return a.nome.compareTo(b.nome);
      if (va == null) return 1;
      if (vb == null) return -1;
      final c = (va is num && vb is num)
          ? va.compareTo(vb)
          : '$va'.toLowerCase().compareTo('$vb'.toLowerCase());
      return crescente ? c : -c;
    });

    return lista;
  }
}
