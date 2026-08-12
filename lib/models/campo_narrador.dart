import 'ficha.dart';

/// Tipo de um campo customizado do narrador.
/// `derivado` não é editável: lê direto da ficha, o que permite ordenar e
/// filtrar por característica sem redigitar nada.
enum TipoCampo { texto, numero, tag, derivado }

class CampoNarrador {
  final String id;
  final String nome;
  final TipoCampo tipo;

  /// Opções do tipo `tag`.
  final List<String> opcoes;

  /// Chave da característica lida, quando o tipo é `derivado`.
  final String origem;

  const CampoNarrador({
    required this.id,
    required this.nome,
    required this.tipo,
    this.opcoes = const [],
    this.origem = '',
  });

  /// Características que um campo derivado pode ler: chave -> rótulo.
  static const Map<String, String> origensDerivadas = {
    'arete': 'Arete',
    'forcaVontade': 'Força de Vontade',
    'afiliacao': 'Afiliação',
    'faccao': 'Facção',
    'conceito': 'Conceito',
    'essencia': 'Essência',
    'vitalidade': 'Dano de Vitalidade',
    'experiencia': 'Experiência',
  };

  factory CampoNarrador.fromJson(Map<String, dynamic> j) => CampoNarrador(
        id: j['id'] as String,
        nome: (j['nome'] ?? '') as String,
        tipo: TipoCampo.values.firstWhere(
          (t) => t.name == j['tipo'],
          orElse: () => TipoCampo.texto,
        ),
        opcoes: List<String>.from(j['opcoes'] ?? const <String>[]),
        origem: (j['origem'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo.name,
        if (opcoes.isNotEmpty) 'opcoes': opcoes,
        if (origem.isNotEmpty) 'origem': origem,
      };

  /// Valor bruto, para ordenar (num ou String).
  Object? valorDe(Ficha f) {
    if (tipo != TipoCampo.derivado) return f.campo(id);
    switch (origem) {
      case 'arete':
        return f.areteFinal;
      case 'forcaVontade':
        return f.forcaVontadeFinal;
      case 'afiliacao':
        return f.afiliacao;
      case 'faccao':
        return f.faccao;
      case 'conceito':
        return f.conceito;
      case 'essencia':
        return f.essencia;
      case 'vitalidade':
        return f.vitalidadeDano;
      case 'experiencia':
        return f.experiencia;
      default:
        return null;
    }
  }

  /// Valor pronto para mostrar no card.
  String textoDe(Ficha f) {
    final v = valorDe(f);
    return v == null ? '' : '$v';
  }
}
