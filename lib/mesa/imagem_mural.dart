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

  static const List<int> _larguras = [1024, 800, 640];
  static const List<int> _qualidades = [80, 70, 60];

  static String preparar(Uint8List original) {
    // `decodeImage` não devolve só null em arquivo inválido: com poucos bytes
    // ele estoura dentro de um dos decodificadores que tenta (o de PSD lê o
    // cabeçalho antes de conferir o tamanho). Arquivo torto vira recado, não
    // queda do app no meio da sessão.
    img.Image? imagem;
    try {
      imagem = img.decodeImage(original);
    } catch (_) {
      imagem = null;
    }
    if (imagem == null) {
      throw Exception('Não foi possível ler a imagem.');
    }

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
