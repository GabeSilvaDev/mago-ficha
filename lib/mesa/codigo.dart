import 'dart:math';

/// Código curto da mesa, feito para ser **ditado em voz alta** numa sala:
/// prefixo fixo `MAGO-` e quatro caracteres de um alfabeto sem nada que se
/// confunda ao falar ou ao ler — fora O/0, I/1/L e S/5.
class CodigoMesa {
  /// 22 caracteres. Quatro posições dão ~234 mil combinações: sobra folga
  /// para uma mesa de amigos, e a criação ainda confere colisão.
  static const String alfabeto = 'ABCDEFGHJKMNPQRTUVWXYZ';
  static const String prefixo = 'MAGO-';
  static const int tamanho = 4;

  static final Random _sorte = Random.secure();

  static String gerar() {
    final b = StringBuffer(prefixo);
    for (var i = 0; i < tamanho; i++) {
      b.write(alfabeto[_sorte.nextInt(alfabeto.length)]);
    }
    return b.toString();
  }

  /// Aceita o que a pessoa digita: minúscula, com espaço, sem hífen, ou só a
  /// parte variável.
  static String normalizar(String bruto) {
    var t = bruto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.startsWith('MAGO')) t = t.substring(4);
    return '$prefixo$t';
  }

  static bool valido(String codigo) {
    final c = codigo.toUpperCase();
    if (!c.startsWith(prefixo)) return false;
    final corpo = c.substring(prefixo.length);
    if (corpo.length != tamanho) return false;
    return corpo.split('').every(alfabeto.contains);
  }
}
