import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'modelos.dart';

/// Em que mesa este aparelho está. Fica no Hive para o app reabrir já dentro
/// da mesa, sem pedir o código de novo.
class EstadoMesa {
  final String mesaId;
  final String nome;
  final String uid;
  final PapelMesa papel;

  /// Ficha local espelhada nesta mesa (Fase 2). Null = ainda não publicou.
  final String? fichaPublicadaId;

  const EstadoMesa({
    required this.mesaId,
    required this.nome,
    required this.uid,
    required this.papel,
    this.fichaPublicadaId,
  });

  EstadoMesa comFicha(String? fichaId) => EstadoMesa(
        mesaId: mesaId,
        nome: nome,
        uid: uid,
        papel: papel,
        fichaPublicadaId: fichaId,
      );

  factory EstadoMesa.fromJson(Map<String, dynamic> j) => EstadoMesa(
        mesaId: j['mesaId'] as String,
        nome: (j['nome'] ?? '') as String,
        uid: j['uid'] as String,
        papel: j['papel'] == 'mestre' ? PapelMesa.mestre : PapelMesa.jogador,
        fichaPublicadaId: j['fichaPublicadaId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'nome': nome,
        'uid': uid,
        'papel': papel.name,
        if (fichaPublicadaId != null) 'fichaPublicadaId': fichaPublicadaId,
      };
}

/// Guarda só o estado local da mesa. Abrir esta box é leitura de disco, não
/// conexão de rede — o app continua offline até alguém entrar numa mesa.
class MesaStore {
  static const String boxName = 'mesa';
  static const String _chave = 'atual';

  static Future<void> init() async {
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  static ValueListenable<Box<String>> get listenable => _box.listenable();

  static EstadoMesa? get atual {
    final s = _box.get(_chave);
    if (s == null) return null;
    return EstadoMesa.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> entrar(EstadoMesa e) async =>
      _box.put(_chave, jsonEncode(e.toJson()));

  static Future<void> limpar() async => _box.delete(_chave);
}
