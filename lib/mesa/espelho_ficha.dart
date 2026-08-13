import 'dart:async';

import '../models/ficha.dart';
import '../services/ficha_io.dart';
import 'mesa_service.dart';

/// Manda para a mesa a ficha que o jogador publicou, agrupando as escritas.
///
/// O app salva a cada toque numa bolinha. Espelhar toque a toque seria uma
/// escrita por toque; a janela junta a rajada e envia só o estado final.
class EspelhoFicha {
  static const Duration janelaPadrao = Duration(seconds: 2);

  final MesaService _servico;
  final Duration janela;

  String? _mesaId;
  String? _fichaId;
  Ficha? _pendente;
  Timer? _timer;

  EspelhoFicha(this._servico, {this.janela = janelaPadrao});

  bool get ligado => _mesaId != null;

  String? get fichaId => _fichaId;

  void ligar(String mesaId, String fichaId) {
    _mesaId = mesaId;
    _fichaId = fichaId;
  }

  void desligar() {
    _timer?.cancel();
    _timer = null;
    _pendente = null;
    _mesaId = null;
    _fichaId = null;
  }

  /// Chamado a cada `FichaStore.salvar`.
  void aoSalvar(Ficha f) {
    if (!ligado || f.id != _fichaId) return;
    _pendente = f;
    _timer ??= Timer(janela, () {
      _timer = null;
      enviarAgora();
    });
  }

  /// Envia o que estiver pendente sem esperar a janela (ao sair da tela, por
  /// exemplo).
  Future<void> enviarAgora() async {
    final f = _pendente;
    final mesaId = _mesaId;
    if (f == null || mesaId == null) return;
    _pendente = null;
    await _servico.publicarFicha(
      mesaId,
      FichaIO.paraJson(f),
      f.nome.isEmpty ? 'Sem nome' : f.nome,
    );
  }
}
