import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ficha.dart';
import '../store/ficha_store.dart';
import 'ficha_io.dart';

/// O que fazer quando a ficha do backup já existe no aparelho.
enum PoliticaColisao { duplicar, substituir, pular }

/// O que veio no zip, antes de qualquer gravação.
class ResumoBackup {
  final int versao;
  final List<Map<String, dynamic>> fichas;

  /// Nomes das fichas cujo id já existe neste aparelho.
  final List<String> colidem;

  const ResumoBackup(this.versao, this.fichas, this.colidem);

  int get total => fichas.length;
}

/// Backup de tudo em um `.zip`. Cada ficha vira um arquivo dentro de
/// `fichas/`, no mesmo formato do export individual — dá para tirar uma
/// ficha só do zip e importar sozinha.
class BackupIO {
  /// Formato do backup. Sobe quando a estrutura do zip mudar de um jeito
  /// que uma versão antiga do app não consiga ler.
  static const int versao = 1;
  static const String app = 'mago-a-ascensao';

  static Uint8List montarZip(List<Ficha> fichas) {
    final arquivo = Archive();
    final json = const JsonEncoder.withIndent('  ');

    void add(String caminho, String conteudo) {
      final dados = utf8.encode(conteudo);
      arquivo.addFile(ArchiveFile(caminho, dados.length, dados));
    }

    final usados = <String>{};
    for (final f in fichas) {
      var nome = FichaIO.nomeArquivo(f);
      // dois personagens com o mesmo nome não podem virar o mesmo arquivo
      if (!usados.add(nome)) {
        nome = '$nome-${f.id.substring(0, 8)}';
        usados.add(nome);
      }
      add('fichas/$nome.json', json.convert(FichaIO.paraJson(f)));
    }

    add(
      'manifest.json',
      json.convert({
        'versao': versao,
        'app': app,
        'fichas': fichas.length,
      }),
    );

    return Uint8List.fromList(ZipEncoder().encode(arquivo));
  }

  /// Lê o zip sem gravar nada. Lança `Exception` com mensagem em português
  /// quando o arquivo não é um backup do app.
  static ResumoBackup lerZip(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw Exception('Arquivo não é um .zip válido.');
    }

    final man = zip.files.where((f) => f.name == 'manifest.json').toList();
    if (man.isEmpty) {
      throw Exception('Zip sem manifest.json — não é um backup do app.');
    }
    final dados =
        jsonDecode(utf8.decode(man.first.content as List<int>)) as Map;
    final v = (dados['versao'] as num?)?.toInt() ?? 0;
    if (dados['app'] != app) {
      throw Exception('Backup de outro aplicativo.');
    }
    if (v > versao) {
      throw Exception(
          'Backup na versão $v; este app lê até a $versao. Atualize o app.');
    }

    final fichas = <Map<String, dynamic>>[];
    for (final arq in zip.files) {
      if (!arq.name.startsWith('fichas/') || !arq.name.endsWith('.json')) {
        continue;
      }
      final j = jsonDecode(utf8.decode(arq.content as List<int>));
      if (j is Map<String, dynamic>) fichas.add(j);
    }

    final colidem = <String>[
      for (final j in fichas)
        if (j['id'] is String && FichaStore.porId(j['id'] as String) != null)
          '${j['nome'] ?? 'Sem nome'}',
    ];

    return ResumoBackup(v, fichas, colidem);
  }

  /// Grava as fichas do resumo. Devolve quantas foram gravadas.
  static Future<int> aplicar(ResumoBackup r, PoliticaColisao politica) async {
    var gravadas = 0;
    for (final j in r.fichas) {
      final id = j['id'];
      final existe = id is String && FichaStore.porId(id) != null;

      if (existe && politica == PoliticaColisao.pular) continue;

      if (existe && politica == PoliticaColisao.substituir) {
        // `deJson` trocaria o id para não sobrescrever; aqui a intenção é
        // justamente sobrescrever, então o id do backup é preservado.
        final ficha = await FichaIO.deJson(Map<String, dynamic>.from(j));
        ficha.data['id'] = id;
        await FichaStore.salvar(ficha);
        gravadas++;
        continue;
      }

      // não existe, ou existe e a política é duplicar: `deJson` resolve o id
      await FichaStore.salvar(
          await FichaIO.deJson(Map<String, dynamic>.from(j)));
      gravadas++;
    }
    return gravadas;
  }

  /// Compartilha o backup de todas as fichas.
  static Future<void> exportarTudo() async {
    final fichas = FichaStore.todas();
    if (fichas.isEmpty) throw Exception('Não há fichas para exportar.');
    final bytes = montarZip(fichas);
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final nome = 'magos-backup-$hoje.zip';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: nome, mimeType: 'application/zip')],
      subject: 'Backup das fichas de Mago',
      fileNameOverrides: [nome],
    );
  }

  /// Abre o seletor aceitando ficha única (.json) ou backup (.zip).
  static Future<(String, Uint8List)?> escolherArquivo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final arq = res.files.single;
    final bytes = arq.bytes;
    if (bytes == null) throw Exception('Não foi possível ler o arquivo.');
    return (arq.name, bytes);
  }
}
