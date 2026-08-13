import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/firebase_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sem configuração, a mesa fica indisponível em vez de explodir',
      () async {
    if (FirebaseApp.configurado) {
      // projeto já configurado neste build: este teste não se aplica
      return;
    }
    expect(FirebaseApp.pronto, isFalse);
    expect(() => FirebaseApp.garantir(), throwsA(isA<MesaIndisponivel>()));
  });

  test('a mensagem de indisponível é legível para quem usa o app', () {
    const e = MesaIndisponivel('Este build não tem a mesa online configurada.');
    expect(e.toString(), contains('mesa online'));
  });
}
