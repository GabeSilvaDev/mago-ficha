import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuração do projeto Firebase `mago-mesa`.
///
/// Escrito à mão em vez de gerado pelo `flutterfire configure` — o container
/// deste projeto só tem o SDK do Flutter, sem Node para a CLI do Firebase.
///
/// **Pode ficar no git — mas só porque as chaves estão restritas.** Chave de
/// cliente Firebase é pública por desenho: ela vai dentro do APK e do bundle
/// web, e qualquer um a extrai com `strings` do apk que você distribui. Ela
/// identifica o projeto e não dá acesso a dado nenhum — quem protege a mesa é
/// `firestore.rules`.
///
/// O que NÃO é automático, e por isso está anotado aqui: chave sem restrição
/// de uso pode ser gastada por qualquer um fora do app (criar contas anônimas
/// em massa, por exemplo, e queimar a cota gratuita). No console do Google
/// Cloud, em APIs e serviços → Credenciais, as duas estão presas:
///
///   Android key — restrita aos pacotes `com.kodem.mago_a_ascensao` e
///                 `.beta`, com a assinatura SHA-1 do keystore de release
///   Browser key — restrita aos referenciadores `gabesilvadev.github.io/*`,
///                 `localhost:*/*` e `192.168.15.7:*/*`
///
/// Ao publicar em domínio novo, acrescente o referenciador lá, senão o login
/// anônimo passa a falhar só naquele endereço. Chave de conta de serviço não
/// entra aqui nunca — essa sim é segredo de verdade.
///
/// Cada canal do app tem seu próprio registro no console (`applicationId`
/// diferente), então o build do beta precisa dizer quem é:
///
/// ```
/// flutter build apk --release --flavor beta --dart-define=CANAL=beta
/// ```
///
/// Sem o `--dart-define` o app se identifica como o canal estável. Isso não
/// derruba nada — Auth e Firestore atendem os dois —, só embaralha as
/// métricas por app do console.
class DefaultFirebaseOptions {
  static const String _canal =
      String.fromEnvironment('CANAL', defaultValue: 'estavel');

  static const String _apiKeyWeb = 'AIzaSyAmTbrhjSAZ24KvvHURbFl1i3T6ABJNe1k';
  static const String _apiKeyAndroid = 'AIzaSyB9KOWboAgmTVBKkrZksR7B2q3DHu718gg';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKeyWeb,
    appId: '1:975812212550:web:22a41eebef92c3b73d5747',
    messagingSenderId: '975812212550',
    projectId: 'mago-mesa',
    authDomain: 'mago-mesa.firebaseapp.com',
    storageBucket: 'mago-mesa.firebasestorage.app',
  );

  static const FirebaseOptions androidEstavel = FirebaseOptions(
    apiKey: _apiKeyAndroid,
    appId: '1:975812212550:android:3a3698d5e8fd79aa3d5747',
    messagingSenderId: '975812212550',
    projectId: 'mago-mesa',
    storageBucket: 'mago-mesa.firebasestorage.app',
  );

  static const FirebaseOptions androidBeta = FirebaseOptions(
    apiKey: _apiKeyAndroid,
    appId: '1:975812212550:android:6c3beea609e241743d5747',
    messagingSenderId: '975812212550',
    projectId: 'mago-mesa',
    storageBucket: 'mago-mesa.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _canal == 'beta' ? androidBeta : androidEstavel;
      default:
        // iOS e desktop não têm app registrado: a mesa fica indisponível e o
        // app continua offline — ver `lib/mesa/firebase_app.dart`.
        throw UnsupportedError(
            'A mesa online só está configurada para Android e Web.');
    }
  }
}
