import 'package:flutter/material.dart';

/// A partir daqui a tela deixa de ser de celular: o mestre no PC ganha a barra
/// lateral, e o conteúdo para de esticar de ponta a ponta.
const double larguraTelaLarga = 900;

/// Largura máxima de leitura confortável. Numa tela de 27 polegadas, uma lista
/// esticada até a borda vira um exercício de virar a cabeça.
const double larguraMioloPadrao = 1100;

bool telaLarga(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= larguraTelaLarga;

/// Centraliza e limita a largura do conteúdo. Em celular não faz nada — a tela
/// é mais estreita que o teto e o filho ocupa tudo, como sempre ocupou.
class Miolo extends StatelessWidget {
  final Widget child;
  final double max;

  const Miolo({super.key, required this.child, this.max = larguraMioloPadrao});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}
