import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/ficha.dart';
import '../store/ficha_store.dart';
import '../store/imagem_store.dart';

/// Exporta/importa uma ficha como arquivo .json — fácil de passar entre
/// aparelhos e versões do app (os campos que não existirem numa versão
/// antiga são recriados com valores padrão pelos getters defensivos).
class FichaIO {
  /// Nome de arquivo (sem extensão) a partir do nome do personagem.
  static String nomeArquivo(Ficha f) => f.nome.trim().isEmpty
      ? 'ficha-mago'
      : f.nome
          .trim()
          .replaceAll(RegExp(r'[^\w\- À-ÿ]'), '')
          .replaceAll(RegExp(r'\s+'), '-');

  /// Ficha em JSON pronta para virar arquivo: o retrato vai embutido em
  /// base64 para o arquivo ser self-contained em qualquer aparelho.
  static Map<String, dynamic> paraJson(Ficha f) {
    final copia = Map<String, dynamic>.from(f.data);
    final id = f.retratoId;
    final b64 = id == null ? null : ImagemStore.base64De(id);
    copia.remove('retratoId');
    if (b64 != null) copia['retrato'] = b64;
    return copia;
  }

  /// Caminho inverso: extrai o retrato para o `ImagemStore` e resolve
  /// colisão de id com uma ficha já existente.
  static Future<Ficha> deJson(Map<String, dynamic> json) async {
    final data = Map<String, dynamic>.from(json);
    final b64 = data.remove('retrato');
    if (b64 is String && b64.isNotEmpty) {
      data['retratoId'] = await ImagemStore.salvarBase64(b64);
    }
    final id = data['id'];
    if (id is! String || id.isEmpty || FichaStore.porId(id) != null) {
      data['id'] = const Uuid().v4();
    }
    return Ficha(data);
  }

  /// Compartilha a ficha como um arquivo `<nome>.json`.
  static Future<void> exportarJson(Ficha f) async {
    final nome = nomeArquivo(f);
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(paraJson(f))));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: '$nome.json', mimeType: 'application/json')],
      subject: 'Ficha ${f.nome.isEmpty ? 'de Mago' : f.nome}',
      fileNameOverrides: ['$nome.json'],
    );
  }

  /// Abre o seletor de arquivo e devolve a Ficha importada (null se cancelar).
  /// Se já existir uma ficha com o mesmo id, gera um id novo (não sobrescreve).
  static Future<Ficha?> importarJson() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final bytes = res.files.single.bytes;
    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Arquivo não é uma ficha válida.');
    }
    return deJson(decoded);
  }
}
