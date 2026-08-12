import 'package:uuid/uuid.dart';

/// Caderno de anotação do narrador: texto simples, imagens (ids do
/// `ImagemStore`), tags e atalhos para fichas.
class Nota {
  String id;
  String titulo;
  String texto;
  List<String> imagens;

  /// Legenda de cada imagem, por id ("mapa da estação"). Imagem sem legenda
  /// simplesmente não aparece aqui.
  Map<String, String> legendas;
  List<String> tags;

  /// Ids de fichas (jogadores ou NPCs) ligadas a esta anotação.
  List<String> fichas;

  /// Fixada no topo da lista — a nota da sessão de hoje.
  bool fixada;
  String criadoEm;
  String atualizadoEm;

  Nota({
    required this.id,
    this.titulo = '',
    this.texto = '',
    List<String>? imagens,
    Map<String, String>? legendas,
    List<String>? tags,
    List<String>? fichas,
    this.fixada = false,
    String? criadoEm,
    String? atualizadoEm,
  })  : imagens = imagens ?? [],
        legendas = legendas ?? {},
        tags = tags ?? [],
        fichas = fichas ?? [],
        criadoEm = criadoEm ?? DateTime.now().toIso8601String(),
        atualizadoEm = atualizadoEm ?? DateTime.now().toIso8601String();

  factory Nota.criar() => Nota(id: const Uuid().v4());

  factory Nota.fromJson(Map<String, dynamic> j) => Nota(
        id: j['id'] as String,
        titulo: (j['titulo'] ?? '') as String,
        texto: (j['texto'] ?? '') as String,
        imagens: List<String>.from(j['imagens'] ?? const <String>[]),
        legendas: ((j['legendas'] ?? const {}) as Map)
            .map((k, v) => MapEntry('$k', '$v')),
        fixada: j['fixada'] == true,
        tags: List<String>.from(j['tags'] ?? const <String>[]),
        fichas: List<String>.from(j['fichas'] ?? const <String>[]),
        criadoEm: j['criadoEm'] as String?,
        atualizadoEm: j['atualizadoEm'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'texto': texto,
        'imagens': imagens,
        if (legendas.isNotEmpty) 'legendas': legendas,
        'tags': tags,
        if (fixada) 'fixada': true,
        'fichas': fichas,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
      };
}
