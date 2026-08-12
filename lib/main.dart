import 'package:flutter/material.dart';
import 'data/game_data.dart';
import 'store/ficha_store.dart';
import 'store/imagem_store.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameData.carregar();
  await FichaStore.init();
  await ImagemStore.init();
  // imagem de ficha apagada não fica ocupando espaço para sempre
  await FichaStore.limparImagensOrfas();
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
