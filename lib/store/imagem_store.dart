import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// Guarda as imagens do app (retratos das fichas e imagens dos cadernos do
/// narrador) numa box própria: a ficha é reescrita inteira a cada `salvar()`,
/// então um retrato embutido nela seria copiado a cada toque numa bolinha.
///
/// Toda imagem entra reduzida para no máximo [maxLado] px no maior lado e
/// recomprimida em JPEG [qualidade] — o tamanho fica limitado na origem.
class ImagemStore {
  static const String boxName = 'imagens';
  static const int maxLado = 1024;
  static const int qualidade = 80;

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  /// Reduz e recomprime. Imagem menor que [maxLado] só é recomprimida.
  static Uint8List reduzir(Uint8List bytes) {
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Não foi possível ler a imagem.');
    }
    final maior =
        original.width > original.height ? original.width : original.height;
    final ajustada = maior > maxLado
        ? img.copyResize(
            original,
            width: original.width >= original.height ? maxLado : null,
            height: original.height > original.width ? maxLado : null,
            interpolation: img.Interpolation.average,
          )
        : original;
    return Uint8List.fromList(img.encodeJpg(ajustada, quality: qualidade));
  }

  /// Guarda a imagem e devolve o id.
  static Future<String> salvar(Uint8List bytes) async {
    final id = const Uuid().v4();
    await _box.put(id, base64Encode(reduzir(bytes)));
    return id;
  }

  /// Guarda uma imagem que veio em base64 (import de ficha/backup).
  static Future<String> salvarBase64(String b64) async =>
      salvar(base64Decode(b64.contains(',') ? b64.split(',').last : b64));

  /// Grava preservando o id — usado no import de backup, onde os cadernos
  /// já referenciam a imagem por esse id.
  static Future<void> gravar(String id, Uint8List bytes) async =>
      _box.put(id, base64Encode(reduzir(bytes)));

  static Uint8List? bytes(String id) {
    final s = _box.get(id);
    return s == null ? null : base64Decode(s);
  }

  static String? base64De(String id) => _box.get(id);

  static Future<void> excluir(String id) async => _box.delete(id);

  /// Apaga as imagens que ninguém mais referencia. Devolve quantas saíram.
  static Future<int> limpar(Set<String> usados) async {
    final orfas =
        _box.keys.cast<String>().where((k) => !usados.contains(k)).toList();
    await _box.deleteAll(orfas);
    return orfas.length;
  }
}
