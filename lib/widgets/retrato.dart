import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../store/imagem_store.dart';
import '../theme.dart';

/// Retrato circular da ficha. Sem imagem (ou com id que não existe mais),
/// cai no ícone padrão do app.
class RetratoAvatar extends StatelessWidget {
  final String? retratoId;
  final double tamanho;
  const RetratoAvatar({super.key, required this.retratoId, this.tamanho = 40});

  @override
  Widget build(BuildContext context) {
    final bytes = retratoId == null ? null : ImagemStore.bytes(retratoId!);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Cores.indigo,
        border: Border.all(color: Cores.dourado, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(Icons.auto_awesome,
              color: Cores.dourado, size: tamanho * 0.55)
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

/// Abre a galeria, guarda a imagem escolhida e devolve o id.
/// Devolve null se o usuário cancelar.
Future<String?> escolherRetrato(BuildContext context) async {
  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final bytes = res.files.single.bytes;
    if (bytes == null) throw Exception('Não foi possível ler a imagem.');
    return await ImagemStore.salvar(bytes);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao abrir a imagem: $e')));
    }
    return null;
  }
}
