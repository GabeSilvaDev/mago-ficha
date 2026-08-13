import 'dart:math';

import 'codigo.dart';

/// A senha da mesa: quem tem a chave é o mestre.
///
/// O login é anônimo, e o uid vive no aparelho — limpar os dados do app o
/// destrói. Sem esta chave a crônica ficaria sem dono, com a galeria inteira
/// presa numa mesa que ninguém mais comanda.
///
/// Mesmo alfabeto do código da mesa: sem I, L, O, S e 0, 1, 5, que a pessoa
/// erra ao ler em voz alta ou copiar de um papel.
class ChaveMesa {
  static const String prefixo = 'MAGO-';
  static const int _porBloco = 4;

  static final Random _sorte = Random.secure();

  static String gerar() {
    String bloco() => List.generate(
        _porBloco,
        (_) => CodigoMesa
            .alfabeto[_sorte.nextInt(CodigoMesa.alfabeto.length)]).join();
    return '$prefixo${bloco()}-${bloco()}';
  }

  /// Aceita com ou sem prefixo, com ou sem hífen, em qualquer caixa.
  static String normalizar(String bruta) {
    final limpa = bruta
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceFirst(RegExp('^MAGO'), '');
    if (limpa.length != _porBloco * 2) return bruta.trim().toUpperCase();
    return '$prefixo${limpa.substring(0, _porBloco)}-'
        '${limpa.substring(_porBloco)}';
  }

  static bool valida(String chave) {
    final c = normalizar(chave);
    if (c.length != prefixo.length + _porBloco * 2 + 1) return false;
    if (!c.startsWith(prefixo)) return false;
    final corpo = c.substring(prefixo.length).replaceAll('-', '');
    return corpo.length == _porBloco * 2 &&
        corpo.split('').every(CodigoMesa.alfabeto.contains);
  }
}
