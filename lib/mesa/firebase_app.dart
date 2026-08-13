import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// A mesa online depende de configuração que pode não existir neste build.
class MesaIndisponivel implements Exception {
  final String mensagem;
  const MesaIndisponivel(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Liga o Firebase só quando alguém entra numa mesa.
///
/// O app é offline por padrão: quem nunca abre a aba Mesa não faz uma única
/// chamada de rede. Por isso a inicialização não mora no `main()` — mexer
/// nisso quebra a promessa que o app faz na primeira linha do README.
class FirebaseApp {
  static bool _pronto = false;
  static bool get pronto => _pronto;

  /// Existe um projeto Firebase de verdade neste build?
  /// Com o `firebase_options.dart` marcador, `apiKey` é vazio e isto é false.
  static bool get configurado {
    try {
      return DefaultFirebaseOptions.currentPlatform.apiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Inicializa uma vez só. Chamar de novo é barato e seguro.
  static Future<void> garantir() async {
    if (_pronto) return;
    if (!configurado) {
      throw const MesaIndisponivel(
          'Este build não tem a mesa online configurada.');
    }
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _pronto = true;
  }
}
