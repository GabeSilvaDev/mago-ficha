import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// MARCADOR — este arquivo é substituído pelo `flutterfire configure`.
///
/// Ele existe com o mesmo formato do arquivo gerado (mesmo nome de classe,
/// mesmo tipo de retorno) para o projeto compilar antes de o Firebase existir.
/// Com `apiKey` vazio, a mesa online se declara indisponível e o app segue
/// 100% offline — ver `lib/mesa/firebase_app.dart`.
///
/// Passo a passo para gerar o de verdade:
/// docs/superpowers/plans/2026-08-12-fase-1-mesa-e-identidade.md (Task 1).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: '',
        appId: '',
        messagingSenderId: '',
        projectId: '',
      );
}
