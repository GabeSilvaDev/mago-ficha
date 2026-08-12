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

  /// Fixadas primeiro (a nota da sessão de hoje fica sempre à mão), depois
  /// da mais recente para a mais antiga.
  static List<Nota> todas() {
    final lista = _box.values
        .map((s) => Nota.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) {
      if (a.fixada != b.fixada) return a.fixada ? -1 : 1;
      return b.atualizadoEm.compareTo(a.atualizadoEm);
    });
    return lista;
  }

  /// Todas as tags em uso, em ordem alfabética — alimenta os chips de filtro.
  static List<String> tags() {
    final t = <String>{for (final n in todas()) ...n.tags}.toList();
    t.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return t;
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
  /// Com [tag], devolve só as notas que têm exatamente aquela tag.
  static List<Nota> buscar(String termo, {String? tag}) {
    final t = termo.trim().toLowerCase();
    return todas().where((n) {
      if (tag != null && tag.isNotEmpty && !n.tags.contains(tag)) return false;
      if (t.isEmpty) return true;
      return n.titulo.toLowerCase().contains(t) ||
          n.texto.toLowerCase().contains(t) ||
          n.tags.any((tag) => tag.toLowerCase().contains(t));
    }).toList();
  }

  static Set<String> imagensUsadas() => {for (final n in todas()) ...n.imagens};
}
