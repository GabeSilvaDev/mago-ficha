import 'package:flutter/material.dart';

import '../../theme.dart';
import '../codigo.dart';

/// Pergunta o nome da mesa e o seu nome. Devolve (nomeDaMesa, meuNome).
Future<(String, String)?> pedirDadosDaMesa(BuildContext context) {
  final mesa = TextEditingController();
  final eu = TextEditingController();
  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Cores.pergaminho,
      title: const Text('Criar mesa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: mesa,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da mesa',
              hintText: 'Ex.: Sombras de SP',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: eu,
            decoration: const InputDecoration(
              labelText: 'Seu nome',
              hintText: 'Como o pessoal te vê na lista',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final n = mesa.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(ctx, (
              n,
              eu.text.trim().isEmpty ? 'Mestre' : eu.text.trim(),
            ));
          },
          child: const Text('Criar', style: TextStyle(color: Cores.indigo)),
        ),
      ],
    ),
  );
}

/// Pergunta o código e o seu nome. Devolve (codigo, meuNome).
Future<(String, String)?> pedirCodigo(BuildContext context) {
  final codigo = TextEditingController();
  final eu = TextEditingController();
  String? erro;

  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: Cores.pergaminho,
        title: const Text('Entrar com código'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codigo,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Código da mesa',
                hintText: 'MAGO-XXXX',
                errorText: erro,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: eu,
              decoration: const InputDecoration(
                labelText: 'Seu nome',
                hintText: 'Como o mestre te vê na lista',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final c = CodigoMesa.normalizar(codigo.text);
              if (!CodigoMesa.valido(c)) {
                setLocal(() => erro = 'Código inválido.');
                return;
              }
              Navigator.pop(ctx, (
                c,
                eu.text.trim().isEmpty ? 'Jogador' : eu.text.trim(),
              ));
            },
            child: const Text('Entrar', style: TextStyle(color: Cores.indigo)),
          ),
        ],
      ),
    ),
  );
}
