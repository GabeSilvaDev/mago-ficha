import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ficha.dart';
import 'imagem_store.dart';

/// Persistência local offline das fichas (Hive). Cada ficha é guardada como
/// uma string JSON na box 'fichas', com a chave = id da ficha.
class FichaStore {
  static const String boxName = 'fichas';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  /// Para reconstruir a lista quando algo muda (usado em ValueListenableBuilder).
  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static List<Ficha> todas() {
    final lista = _box.values
        .map((s) => Ficha(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) => (b.data['atualizadoEm'] ?? '')
        .toString()
        .compareTo((a.data['atualizadoEm'] ?? '').toString()));
    return lista;
  }

  static Ficha? porId(String id) {
    final s = _box.get(id);
    if (s == null) return null;
    return Ficha(jsonDecode(s) as Map<String, dynamic>);
  }

  /// Avisado ao fim de cada `salvar`. A mesa online usa isso para espelhar a
  /// ficha publicada; fora de mesa é null e nada acontece.
  static void Function(Ficha)? observador;

  static Future<void> salvar(Ficha f) async {
    f.data['atualizadoEm'] = DateTime.now().toIso8601String();
    await _box.put(f.id, jsonEncode(f.data));
    observador?.call(f);
  }

  static Future<void> excluir(String id) async => _box.delete(id);

  /// Ids de imagem referenciados por alguma ficha.
  static Set<String> imagensUsadas() =>
      {for (final f in todas()) if (f.retratoId != null) f.retratoId!};

  /// Apaga imagens que nenhuma ficha usa mais. Devolve quantas saíram.
  static Future<int> limparImagensOrfas() =>
      ImagemStore.limpar(imagensUsadas());
}
