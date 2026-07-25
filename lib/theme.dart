import 'package:flutter/material.dart';

/// Paleta inspirada na ficha oficial de Mago: A Ascensão (Edição 20º Aniversário):
/// pergaminho creme + dourado + o índigo/roxo profundo da logo MAGO.
class Cores {
  static const pergaminho = Color(0xFFF3EAD0);
  static const pergaminhoEscuro = Color(0xFFE7D9B2);
  static const indigo = Color(0xFF241E45); // roxo/azul profundo da logo
  static const indigoClaro = Color(0xFF3D3466);
  static const dourado = Color(0xFFB08A32);
  static const douradoClaro = Color(0xFFCBA45A);
  static const tinta = Color(0xFF2B2618);
}

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Cores.indigo,
      primary: Cores.indigo,
      secondary: Cores.dourado,
      surface: Cores.pergaminho,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Cores.pergaminho,
    fontFamily: 'serif',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.indigo,
      foregroundColor: Cores.pergaminho,
      centerTitle: true,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: Cores.pergaminhoEscuro,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Cores.dourado, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFBF5E2),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Cores.dourado),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Cores.dourado),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Cores.indigo, width: 2),
      ),
      labelStyle: const TextStyle(color: Cores.tinta),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Cores.indigo,
        foregroundColor: Cores.pergaminho,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Cores.tinta,
      displayColor: Cores.indigo,
    ),
  );
}

/// Cabeçalho de seção no estilo da ficha (faixa índigo com texto dourado/claro).
/// Com [onEditar], ganha um lápis à direita que edita SÓ aquela seção.
class FaixaSecao extends StatelessWidget {
  final String titulo;
  final VoidCallback? onEditar;
  const FaixaSecao(this.titulo, {super.key, this.onEditar});
  @override
  Widget build(BuildContext context) {
    final texto = Text(
      titulo.toUpperCase(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Cores.dourado,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 14,
      ),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: EdgeInsets.fromLTRB(12, 6, onEditar == null ? 12 : 4, 6),
      decoration: BoxDecoration(
        color: Cores.indigo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Cores.dourado),
      ),
      child: onEditar == null
          ? texto
          : Row(
              children: [
                const SizedBox(width: 32),
                Expanded(child: texto),
                InkWell(
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit, size: 18, color: Cores.dourado),
                  ),
                ),
              ],
            ),
    );
  }
}
