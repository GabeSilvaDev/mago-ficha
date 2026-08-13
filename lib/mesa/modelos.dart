enum PapelMesa { mestre, jogador }

/// Quem está na mesa. `visto` é o batimento de presença: o app regrava
/// enquanto está aberto na mesa, e quem parou de bater aparece offline.
class Membro {
  /// Presença vale por 90s — três batimentos de 30s. Uma perda pontual de
  /// rede não derruba o membro da lista.
  static const Duration janelaOnline = Duration(seconds: 90);

  final String uid;
  final String nome;
  final PapelMesa papel;
  final DateTime entrouEm;
  final DateTime visto;

  const Membro({
    required this.uid,
    required this.nome,
    required this.papel,
    required this.entrouEm,
    required this.visto,
  });

  bool onlineEm(DateTime agora) => agora.difference(visto) < janelaOnline;

  factory Membro.fromJson(String uid, Map<String, dynamic> j) => Membro(
        uid: uid,
        nome: (j['nome'] ?? '') as String,
        // papel desconhecido vira jogador: nunca promover por engano
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        entrouEm: DateTime.parse(j['entrouEm'] as String),
        visto: DateTime.parse(j['visto'] as String),
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'papel': papel.name,
        'entrouEm': entrouEm.toIso8601String(),
        'visto': visto.toIso8601String(),
      };
}

/// A mesa em si. O `codigo` é o que se dita para alguém entrar.
class Mesa {
  final String id;
  final String nome;
  final String codigo;
  final String mestreUid;
  final DateTime criadaEm;

  const Mesa({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.mestreUid,
    required this.criadaEm,
  });

  factory Mesa.fromJson(String id, Map<String, dynamic> j) => Mesa(
        id: id,
        nome: (j['nome'] ?? '') as String,
        codigo: (j['codigo'] ?? '') as String,
        mestreUid: (j['mestreUid'] ?? '') as String,
        criadaEm: DateTime.parse(j['criadaEm'] as String),
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'codigo': codigo,
        'mestreUid': mestreUid,
        'criadaEm': criadaEm.toIso8601String(),
      };
}
