import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/nota.dart';

/// Cadernos do narrador, um JSON por registro (mesmo desenho do `FichaStore`).
class NotaStore {
  static const String boxName = 'notas';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static List<Nota> todas() {
    final lista = _box.values
        .map((s) => Nota.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) => b.atualizadoEm.compareTo(a.atualizadoEm));
    return lista;
  }

  static Nota? porId(String id) {
    final s = _box.get(id);
    return s == null
        ? null
        : Nota.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  /// [tocar] false mantém o `atualizadoEm` que veio na nota — usado no
  /// import de backup, onde a data original importa.
  static Future<void> salvar(Nota n, {bool tocar = true}) async {
    if (tocar) n.atualizadoEm = DateTime.now().toIso8601String();
    await _box.put(n.id, jsonEncode(n.toJson()));
  }

  static Future<void> excluir(String id) async => _box.delete(id);

  /// Busca em título, texto e tags, ignorando maiúsculas.
  static List<Nota> buscar(String termo) {
    final t = termo.trim().toLowerCase();
    if (t.isEmpty) return todas();
    return todas()
        .where((n) =>
            n.titulo.toLowerCase().contains(t) ||
            n.texto.toLowerCase().contains(t) ||
            n.tags.any((tag) => tag.toLowerCase().contains(t)))
        .toList();
  }

  static Set<String> imagensUsadas() => {for (final n in todas()) ...n.imagens};
}
