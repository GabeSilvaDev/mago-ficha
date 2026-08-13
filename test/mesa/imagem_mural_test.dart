import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mago_a_ascensao/mesa/imagem_mural.dart';

/// Imagem com ruído: cor sólida comprime demais e não testa nada.
Uint8List _ruido(int largura, int altura) {
  final im = img.Image(width: largura, height: altura);
  for (var y = 0; y < altura; y++) {
    for (var x = 0; x < largura; x++) {
      im.setPixelRgb(
          x, y, (x * 7 + y * 13) % 256, (x * 3) % 256, (y * 11) % 256);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imagem normal passa e continua legível', () {
    final b64 = ImagemMural.preparar(_ruido(800, 600));
    final bytes = base64Decode(b64);
    expect(bytes[0], 0xFF); // JPEG
    expect(bytes[1], 0xD8);
    expect(b64.length, lessThan(ImagemMural.tetoBase64));
    final decodificada = img.decodeImage(bytes)!;
    expect(decodificada.width, greaterThan(200));
  });

  test('imagem enorme é encolhida até caber', () {
    final b64 = ImagemMural.preparar(_ruido(4000, 3000));
    expect(b64.length, lessThan(ImagemMural.tetoBase64));
    final decodificada = img.decodeImage(base64Decode(b64))!;
    expect(decodificada.width, lessThanOrEqualTo(1024));
  });

  test('teto tem folga real dentro do limite de 1 MiB do Firestore', () {
    expect(ImagemMural.tetoBase64, lessThan(1024 * 1024));
  });

  test('bytes que não são imagem falham com mensagem clara', () {
    expect(() => ImagemMural.preparar(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()));
  });

  test('miniatura é pequena o suficiente para a galeria inteira', () {
    final b64 = ImagemMural.miniatura(_ruido(1600, 1200));
    expect(b64.length, lessThan(ImagemMural.tetoMiniatura));
    final im = img.decodeImage(base64Decode(b64))!;
    expect(im.width, lessThanOrEqualTo(200));
  });

  test('miniatura de imagem pequena não é ampliada', () {
    final b64 = ImagemMural.miniatura(_ruido(120, 90));
    final im = img.decodeImage(base64Decode(b64))!;
    expect(im.width, 120);
  });

  test('cinquenta miniaturas cabem numa abertura de galeria barata', () {
    final b64 = ImagemMural.miniatura(_ruido(1600, 1200));
    expect(b64.length * 50, lessThan(2 * 1024 * 1024));
  });

  test('miniatura de bytes inválidos falha com mensagem clara', () {
    expect(() => ImagemMural.miniatura(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()));
  });
}
