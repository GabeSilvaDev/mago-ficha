import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chave_mesa.dart';
import 'codigo.dart';
import 'firebase_app.dart';
import 'mesa_service.dart';
import 'modelos.dart';

/// Mesa online de verdade.
///
/// Espelha, chamada por chamada, o que `MesaFake` faz em memória — e o que as
/// regras de segurança (`firestore.rules`) permitem. Se os três divergirem, os
/// testes passam a mentir sobre o comportamento real.
class MesaFirestore implements MesaService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  String? get uid => FirebaseApp.pronto
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  @override
  Future<String> entrarAnonimo() async {
    await FirebaseApp.garantir();
    final atual = FirebaseAuth.instance.currentUser;
    if (atual != null) return atual.uid;
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user!.uid;
  }

  DocumentReference<Map<String, dynamic>> _mesa(String id) =>
      _db.collection('mesas').doc(id);

  @override
  Future<(Mesa, String)> criarMesa(String nome, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final agora = DateTime.now();

    // A mesa vem primeiro: a regra de `codigos` consulta o mestreUid dela.
    final ref = _db.collection('mesas').doc();
    var codigo = CodigoMesa.gerar();
    await ref.set({
      'nome': nome,
      'codigo': codigo,
      'mestreUid': meuUid,
      'criadaEm': agora.toIso8601String(),
    });

    // Colisão de código é rara, mas custa pouco tentar de novo.
    for (var tentativa = 0; tentativa < 5; tentativa++) {
      final doc = _db.collection('codigos').doc(codigo);
      if (!(await doc.get()).exists) {
        await doc.set({'mesaId': ref.id});
        break;
      }
      codigo = CodigoMesa.gerar();
      await ref.update({'codigo': codigo});
    }

    await ref.collection('membros').doc(meuUid).set({
      'nome': meuNome,
      'papel': 'mestre',
      'entrouEm': agora.toIso8601String(),
      'visto': agora.toIso8601String(),
    });

    final chave = ChaveMesa.gerar();
    // documento que ninguém lê: só as regras enxergam, com get()
    await ref.collection('privado').doc('chave').set({'chave': chave});

    return (
      Mesa(
        id: ref.id,
        nome: nome,
        codigo: codigo,
        mestreUid: meuUid,
        criadaEm: agora,
      ),
      chave,
    );
  }

  @override
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final alvo = CodigoMesa.normalizar(codigo);

    final atalho = await _db.collection('codigos').doc(alvo).get();
    if (!atalho.exists) throw MesaNaoEncontrada();
    final mesaId = atalho.data()!['mesaId'] as String;

    final membros = _mesa(mesaId).collection('membros').doc(meuUid);
    final agora = DateTime.now();

    try {
      final jaEra = await membros.get();

      await membros.set({
        'nome': meuNome,
        // entrar de novo não rebaixa o mestre nem promove ninguém
        'papel': (jaEra.data()?['papel'] as String?) ?? 'jogador',
        'entrouEm':
            (jaEra.data()?['entrouEm'] as String?) ?? agora.toIso8601String(),
        'visto': agora.toIso8601String(),
      });

      // A mesa só é legível depois que o registro de membro existe — é assim
      // que a regra sabe que somos da casa.
      final doc = await _mesa(mesaId).get();
      if (!doc.exists) throw MesaNaoEncontrada();
      return Mesa.fromJson(mesaId, doc.data()!);
    } on FirebaseException catch (e) {
      // O código apontava para uma mesa que não existe mais: sem a mesa, a
      // regra não tem como reconhecer ninguém.
      if (e.code == 'permission-denied') throw MesaNaoEncontrada();
      rethrow;
    }
  }

  @override
  Future<Mesa> reassumirMesa(
      String codigo, String chave, String meuNome) async {
    final meuUid = await entrarAnonimo();
    final alvo = CodigoMesa.normalizar(codigo);
    final atalho = await _db.collection('codigos').doc(alvo).get();
    if (!atalho.exists) throw MesaNaoEncontrada();
    final mesaId = atalho.data()!['mesaId'] as String;

    try {
      // a tentativa vai num documento ilegível; a regra do update compara os
      // dois com get() e só deixa passar se baterem
      await _mesa(mesaId).collection('privado').doc('pedido').set({
        'chave': ChaveMesa.normalizar(chave),
        'uid': meuUid,
      });
      await _mesa(mesaId).update({'mestreUid': meuUid});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw ChaveErrada();
      rethrow;
    }

    await _mesa(mesaId).collection('membros').doc(meuUid).set({
      'nome': meuNome,
      'papel': 'mestre',
      'entrouEm': DateTime.now().toIso8601String(),
      'visto': DateTime.now().toIso8601String(),
    });

    final doc = await _mesa(mesaId).get();
    if (!doc.exists) throw MesaNaoEncontrada();
    return Mesa.fromJson(mesaId, doc.data()!);
  }

  @override
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome) async {
    final meuUid = uid;
    if (meuUid == null) throw SemPermissao();
    await _mesa(mesaId).collection('fichas').doc(meuUid).set({
      'dono': meuUid,
      'nome': nome,
      'atualizadaEm': DateTime.now().toIso8601String(),
      'ficha': ficha,
    });
  }

  @override
  Future<void> despublicarFicha(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    await _mesa(mesaId).collection('fichas').doc(meuUid).delete();
  }

  // Quem corta o que cada um vê é a regra de segurança: para o jogador comum
  // esta mesma consulta devolve só o documento dele. Não há filtro no cliente
  // porque filtro no cliente não protege nada.
  @override
  Stream<List<FichaNaMesa>> observarFichas(String mesaId) => _mesa(mesaId)
      .collection('fichas')
      .snapshots()
      .map((q) =>
          q.docs.map((d) => FichaNaMesa.fromJson(d.id, d.data())).toList());

  @override
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid) =>
      _mesa(mesaId).collection('fichas').doc(donoUid).snapshots().map(
          (d) => d.exists ? FichaNaMesa.fromJson(d.id, d.data()!) : null);

  DocumentReference<Map<String, dynamic>> _mural(String mesaId) =>
      _mesa(mesaId).collection('mural').doc('atual');

  CollectionReference<Map<String, dynamic>> _galeria(String mesaId) =>
      _mesa(mesaId).collection('galeria');

  CollectionReference<Map<String, dynamic>> _imagens(String mesaId) =>
      _mesa(mesaId).collection('imagens');

  @override
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda) async {
    final meuUid = uid;
    if (meuUid == null) throw SemPermissao();
    final ref = _galeria(mesaId).doc();
    try {
      // a imagem cheia primeiro: a entrada da galeria só aparece quando há o
      // que abrir, e não fica item pela metade se a rede cair no meio
      await _imagens(mesaId).doc(ref.id).set({'imagem': imagemBase64});
      await ref.set(ItemGaleria(
        id: ref.id,
        legenda: legenda,
        porUid: meuUid,
        miniaturaBase64: miniaturaBase64,
        em: DateTime.now(),
      ).toJson());
      return ref.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> apagarDaGaleria(String mesaId, String imagemId) async {
    try {
      // pesado primeiro: se o segundo delete falhar, o item continua na
      // galeria e ninguém fica com imagem grande órfã ocupando espaço
      await _imagens(mesaId).doc(imagemId).delete();
      await _galeria(mesaId).doc(imagemId).delete();
      final atual = await _mural(mesaId).get();
      if (atual.exists && atual.data()!['imagemId'] == imagemId) {
        await _mural(mesaId).delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Stream<List<ItemGaleria>> observarGaleria(String mesaId) => _galeria(mesaId)
      .orderBy('em', descending: true)
      .snapshots()
      .map((q) =>
          q.docs.map((d) => ItemGaleria.fromJson(d.id, d.data())).toList());

  @override
  Future<String?> imagemCheia(String mesaId, String imagemId) async {
    final doc = await _imagens(mesaId).doc(imagemId).get();
    if (!doc.exists) return null;
    return doc.data()!['imagem'] as String?;
  }

  @override
  Future<void> mostrarAgora(String mesaId, String imagemId) async {
    try {
      await _mural(mesaId).set(
          ItemMural(imagemId: imagemId, em: DateTime.now()).toJson());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> limparMural(String mesaId) async {
    try {
      await _mural(mesaId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Stream<ItemMural?> observarMural(String mesaId) => _mural(mesaId)
      .snapshots()
      .map((d) => d.exists ? ItemMural.fromJson(d.data()!) : null);

  @override
  Stream<Mesa?> observarMesa(String mesaId) => _mesa(mesaId)
      .snapshots()
      .map((d) => d.exists ? Mesa.fromJson(mesaId, d.data()!) : null);

  @override
  Stream<List<Membro>> observarMembros(String mesaId) => _mesa(mesaId)
      .collection('membros')
      .snapshots()
      .map((q) => q.docs.map((d) => Membro.fromJson(d.id, d.data())).toList());

  @override
  Future<void> baterPonto(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    await _mesa(mesaId)
        .collection('membros')
        .doc(meuUid)
        .update({'visto': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> sair(String mesaId) async {
    final meuUid = uid;
    if (meuUid == null) return;
    // primeiro a ficha: depois de deixar de ser membro a regra já não deixa
    // apagar nada aqui dentro
    await despublicarFicha(mesaId);
    await _mesa(mesaId).collection('membros').doc(meuUid).delete();
  }

  @override
  Future<void> removerMembro(String mesaId, String alvo) async {
    try {
      await _mesa(mesaId).collection('membros').doc(alvo).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> trocarCodigo(String mesaId) async {
    final doc = await _mesa(mesaId).get();
    if (!doc.exists) throw MesaNaoEncontrada();
    final antigo = doc.data()!['codigo'] as String;
    final novo = CodigoMesa.gerar();
    try {
      await _db.collection('codigos').doc(novo).set({'mesaId': mesaId});
      await _mesa(mesaId).update({'codigo': novo});
      await _db.collection('codigos').doc(antigo).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> encerrarSessao(String mesaId) async {
    try {
      final fichas = await _mesa(mesaId).collection('fichas').get();
      for (final f in fichas.docs) {
        await f.reference.delete();
      }
      final membros = await _mesa(mesaId).collection('membros').get();
      for (final m in membros.docs) {
        await m.reference.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }

  @override
  Future<void> apagarMesa(String mesaId) async {
    final doc = await _mesa(mesaId).get();
    if (!doc.exists) return;
    final codigo = doc.data()!['codigo'] as String;
    try {
      for (final c in ['galeria', 'imagens', 'fichas', 'membros', 'privado']) {
        final docs = await _mesa(mesaId).collection(c).get();
        for (final d in docs.docs) {
          await d.reference.delete();
        }
      }
      await _mural(mesaId).delete();
      await _db.collection('codigos').doc(codigo).delete();
      await _mesa(mesaId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw SemPermissao();
      rethrow;
    }
  }
}
