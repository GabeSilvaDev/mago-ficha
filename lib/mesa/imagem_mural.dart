import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deixa a imagem no tamanho que cabe dentro de um documento do Firestore.
///
/// O mural não usa Firebase Storage — que hoje exige plano pago: a imagem vai
/// em base64 no próprio documento. Uma foto de 1024px em JPEG q80 dá 150–250
/// KB, que em base64 vira 200–330 KB, bem dentro do limite de 1 MiB por
/// documento. Só o caso extremo precisa encolher mais, e é o que esta classe
/// garante.
class ImagemMural {
  /// Teto do base64. Deixa folga para o resto do documento (legenda, uid,
  /// data) e para o overhead do próprio Firestore.
  static const int tetoBase64 = 700 * 1024;

  /// Teto da miniatura. A galeria lê uma por imagem: com 50 imagens são ~2 MB
  /// no pior caso, contra 15 MB se ela lesse as imagens cheias.
  static const int tetoMiniatura = 40 * 1024;

  static const List<int> _larguras = [1024, 800, 640];
  static const List<int> _qualidades = [80, 70, 60];

  static const int _ladoMiniatura = 200;

  /// `decodeImage` não devolve só null em arquivo inválido: com poucos bytes
  /// ele estoura dentro de um dos decodificadores que tenta (o de PSD lê o
  /// cabeçalho antes de conferir o tamanho).
  static img.Image _decodificar(Uint8List original) {
    img.Image? imagem;
    try {
      imagem = img.decodeImage(original);
    } catch (_) {
      imagem = null;
    }
    if (imagem == null) {
      throw Exception('Não foi possível ler a imagem.');
    }
    return imagem;
  }

  /// Versão pequena, para a grade da galeria. A imagem cheia só é buscada
  /// quando alguém abre.
  static String miniatura(Uint8List original) {
    final imagem = _decodificar(original);
    final pequena = imagem.width > _ladoMiniatura
        ? img.copyResize(imagem,
            width: _ladoMiniatura, interpolation: img.Interpolation.average)
        : imagem;
    for (final q in [60, 45, 30]) {
      final b64 = base64Encode(img.encodeJpg(pequena, quality: q));
      if (b64.length <= tetoMiniatura) return b64;
    }
    return base64Encode(img.encodeJpg(
        img.copyResize(imagem, width: 120), quality: 40));
  }

  static String preparar(Uint8List original) {
    final imagem = _decodificar(original);

    for (final largura in _larguras) {
      final ajustada = imagem.width > largura
          ? img.copyResize(imagem,
              width: largura, interpolation: img.Interpolation.average)
          : imagem;
      for (final q in _qualidades) {
        final b64 = base64Encode(img.encodeJpg(ajustada, quality: q));
        if (b64.length <= tetoBase64) return b64;
      }
    }

    // Último recurso: bem pequena, mas o mural nunca falha por tamanho.
    final mini = img.copyResize(imagem, width: 480);
    return base64Encode(img.encodeJpg(mini, quality: 55));
  }
}
