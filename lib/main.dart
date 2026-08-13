import 'package:flutter/material.dart';
import 'data/game_data.dart';
import 'store/ficha_store.dart';
import 'mesa/mesa_store.dart';
import 'store/imagem_store.dart';
import 'store/narrador_store.dart';
import 'store/nota_store.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameData.carregar();
  await FichaStore.init();
  await ImagemStore.init();
  await NarradorStore.init();
  await NotaStore.init();
  // só o estado local de "estou na mesa X": abrir a box é leitura de disco,
  // não conexão. O Firebase continua desligado até alguém entrar numa mesa.
  await MesaStore.init();
  // imagem que ninguém mais referencia (ficha ou caderno apagado) não fica
  // ocupando espaço para sempre
  await ImagemStore.limpar(
      {...FichaStore.imagensUsadas(), ...NotaStore.imagensUsadas()});
  runApp(const AppMagoAscensao());
}

class AppMagoAscensao extends StatelessWidget {
  const AppMagoAscensao({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mago: A Ascensão',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: const HomeScreen(),
    );
  }
}
