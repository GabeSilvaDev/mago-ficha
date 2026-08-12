import 'package:uuid/uuid.dart';

/// Caderno de anotação do narrador: texto simples, imagens (ids do
/// `ImagemStore`), tags e atalhos para fichas.
class Nota {
  String id;
  String titulo;
  String texto;
  List<String> imagens;
  List<String> tags;
  List<String> fichas;
  String criadoEm;
  String atualizadoEm;

  Nota({
    required this.id,
    this.titulo = '',
    this.texto = '',
    List<String>? imagens,
    List<String>? tags,
    List<String>? fichas,
    String? criadoEm,
    String? atualizadoEm,
  })  : imagens = imagens ?? [],
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
        'tags': tags,
        'fichas': fichas,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
      };
}
