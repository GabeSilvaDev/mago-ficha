import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/campo_narrador.dart';
import 'ficha_store.dart';

/// Configuração do narrador que vale para todas as fichas — hoje, as
/// definições dos campos customizados.
class NarradorStore {
  static const String boxName = 'narrador';
  static const String _chaveCampos = 'campos';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static List<CampoNarrador> campos() {
    final s = _box.get(_chaveCampos);
    if (s == null) return [];
    final lista = jsonDecode(s) as List;
    return [
      for (final e in lista)
        CampoNarrador.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  static Future<void> salvarCampos(List<CampoNarrador> campos) async {
    await _box.put(
        _chaveCampos, jsonEncode([for (final c in campos) c.toJson()]));
  }

  /// Apaga a definição e também os valores guardados nas fichas — deixar
  /// valor órfão só engorda o JSON e reaparece se o id for reaproveitado.
  static Future<void> excluirCampo(String id) async {
    await salvarCampos(campos().where((c) => c.id != id).toList());
    for (final f in FichaStore.todas()) {
      if (f.campos.containsKey(id)) {
        f.setCampo(id, null);
        await FichaStore.salvar(f);
      }
    }
  }
}
