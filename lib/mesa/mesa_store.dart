import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'modelos.dart';

/// Em que mesa este aparelho está. Fica no Hive para o app reabrir já dentro
/// da mesa, sem pedir o código de novo.
class EstadoMesa {
  final String mesaId;
  final String nome;
  final String uid;
  final PapelMesa papel;

  /// Ficha local espelhada nesta mesa (Fase 2). Null = ainda não publicou.
  final String? fichaPublicadaId;

  /// Só o mestre tem. Repassada por `comFicha` — senão publicar uma ficha
  /// apagaria a chave do estado atual.
  final String? chave;

  const EstadoMesa({
    required this.mesaId,
    required this.nome,
    required this.uid,
    required this.papel,
    this.fichaPublicadaId,
    this.chave,
  });

  EstadoMesa comFicha(String? fichaId) => EstadoMesa(
        mesaId: mesaId,
        nome: nome,
        uid: uid,
        papel: papel,
        fichaPublicadaId: fichaId,
        chave: chave,
      );

  factory EstadoMesa.fromJson(Map<String, dynamic> j) => EstadoMesa(
        mesaId: j['mesaId'] as String,
        nome: (j['nome'] ?? '') as String,
        uid: j['uid'] as String,
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        fichaPublicadaId: j['fichaPublicadaId'] as String?,
        chave: j['chave'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'nome': nome,
        'uid': uid,
        'papel': papel.name,
        if (fichaPublicadaId != null) 'fichaPublicadaId': fichaPublicadaId,
        if (chave != null) 'chave': chave,
      };
}

/// Uma mesa em que este aparelho já entrou. Fica guardada mesmo depois de sair:
/// jogamos todo sábado, e ninguém quer ditar o código toda semana.
class MesaConhecida {
  final String mesaId;
  final String nome;
  final PapelMesa papel;

  /// Só o mestre tem. É o que permite reassumir a mesa noutro aparelho — e é
  /// justamente o que se perde ao limpar os dados do app.
  final String? chave;

  /// O nome que a pessoa usa NESTA mesa — não o nome da mesa. Sem ele, voltar
  /// pela lista (`_voltarPara`) não tem de onde tirar o nome de exibição e
  /// acaba mandando o nome da mesa como se fosse o da pessoa: quem volta
  /// aparece em "quem está na mesa" chamado, por exemplo, "Sombras de SP" em
  /// vez do próprio nome.
  final String? meuNome;

  const MesaConhecida({
    required this.mesaId,
    required this.nome,
    required this.papel,
    this.chave,
    this.meuNome,
  });

  factory MesaConhecida.fromJson(Map<String, dynamic> j) => MesaConhecida(
        mesaId: j['mesaId'] as String,
        nome: (j['nome'] ?? '') as String,
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        chave: j['chave'] as String?,
        meuNome: j['meuNome'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'nome': nome,
        'papel': papel.name,
        if (chave != null) 'chave': chave,
        if (meuNome != null) 'meuNome': meuNome,
      };
}

/// Guarda só o estado local da mesa. Abrir esta box é leitura de disco, não
/// conexão de rede — o app continua offline até alguém entrar numa mesa.
class MesaStore {
  static const String boxName = 'mesa';
  static const String _chave = 'atual';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static EstadoMesa? get atual {
    final s = _box.get(_chave);
    if (s == null) return null;
    return EstadoMesa.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> entrar(EstadoMesa e) async =>
      _box.put(_chave, jsonEncode(e.toJson()));

  static Future<void> limpar() async => _box.delete(_chave);

  static const String _chaveConhecidas = 'conhecidas';

  static List<MesaConhecida> conhecidas() {
    final s = _box.get(_chaveConhecidas);
    if (s == null) return const [];
    final lista = jsonDecode(s) as List;
    return [
      for (final m in lista)
        MesaConhecida.fromJson((m as Map).cast<String, dynamic>())
    ];
  }

  static Future<void> lembrar(MesaConhecida mesa) async {
    final atuais = conhecidas().where((m) => m.mesaId != mesa.mesaId).toList();
    await _box.put(_chaveConhecidas,
        jsonEncode([mesa, ...atuais].map((m) => m.toJson()).toList()));
  }

  static Future<void> esquecer(String mesaId) async {
    final restantes =
        conhecidas().where((m) => m.mesaId != mesaId).map((m) => m.toJson());
    await _box.put(_chaveConhecidas, jsonEncode(restantes.toList()));
  }

  static String? chaveDe(String mesaId) {
    for (final m in conhecidas()) {
      if (m.mesaId == mesaId) return m.chave;
    }
    return null;
  }
}
