import 'dart:async';

import 'codigo.dart';
import 'mesa_service.dart';
import 'modelos.dart';

/// Estado compartilhado entre vários `MesaFake` — é o que permite simular
/// mestre e jogador na mesma mesa dentro de um teste.
class MundoFake {
  final Map<String, Mesa> mesas = {};
  final Map<String, Map<String, Membro>> membros = {};
  final Map<String, Map<String, FichaNaMesa>> fichas = {};
  final Map<String, Map<String, ItemGaleria>> galeria = {};
  final Map<String, Map<String, String>> cheias = {};
  final Map<String, ItemMural> mural = {};

  final Map<String, StreamController<Mesa?>> _mesaCtrl = {};
  final Map<String, StreamController<List<Membro>>> _membrosCtrl = {};
  final Map<String, StreamController<int>> _fichasCtrl = {};
  final Map<String, StreamController<ItemMural?>> _muralCtrl = {};
  final Map<String, StreamController<int>> _galeriaCtrl = {};
  int _seq = 0;
  int _versao = 0;

  String novoId() => 'mesa-${++_seq}';

  void notificar(String mesaId) {
    _mesaCtrl[mesaId]?.add(mesas[mesaId]);
    _membrosCtrl[mesaId]?.add(membros[mesaId]?.values.toList() ?? const []);
    _fichasCtrl[mesaId]?.add(++_versao);
    _muralCtrl[mesaId]?.add(mural[mesaId]);
    _galeriaCtrl[mesaId]?.add(++_versao);
  }

  Stream<Mesa?> streamMesa(String id) {
    final c =
        _mesaCtrl.putIfAbsent(id, () => StreamController<Mesa?>.broadcast());
    scheduleMicrotask(() => c.add(mesas[id]));
    return c.stream;
  }

  Stream<List<Membro>> streamMembros(String id) {
    final c = _membrosCtrl.putIfAbsent(
        id, () => StreamController<List<Membro>>.broadcast());
    scheduleMicrotask(() => c.add(membros[id]?.values.toList() ?? const []));
    return c.stream;
  }

  /// Emite um número que só serve de gatilho: quem escuta relê `fichas` na
  /// hora, já filtrando pelo que aquele uid pode ver.
  Stream<int> streamFichas(String id) {
    final c =
        _fichasCtrl.putIfAbsent(id, () => StreamController<int>.broadcast());
    scheduleMicrotask(() => c.add(++_versao));
    return c.stream;
  }

  Stream<ItemMural?> streamMural(String id) {
    final c = _muralCtrl.putIfAbsent(
        id, () => StreamController<ItemMural?>.broadcast());
    scheduleMicrotask(() => c.add(mural[id]));
    return c.stream;
  }

  /// Mesmo truque de `streamFichas`: um número de gatilho, quem escuta relê
  /// `galeria` na hora.
  Stream<int> streamGaleria(String id) {
    final c = _galeriaCtrl.putIfAbsent(
        id, () => StreamController<int>.broadcast());
    scheduleMicrotask(() => c.add(++_versao));
    return c.stream;
  }
}

/// Implementação em memória, para testes.
///
/// Reproduz as mesmas permissões das regras de segurança do Firestore. Quando
/// mexer numa, confira a outra.
class MesaFake implements MesaService {
  final String uidFixo;
  final MundoFake mundo;
  DateTime Function() relogio = DateTime.now;

  String? _uid;

  MesaFake(this.uidFixo, {MundoFake? mundo}) : mundo = mundo ?? MundoFake();

  @override
  String? get uid => _uid;

  @override
  Future<String> entrarAnonimo() async => _uid = uidFixo;

  void _exigeLogin() {
    if (_uid == null) throw StateError('Chame entrarAnonimo primeiro.');
  }

  Mesa _exigeMesa(String id) {
    final m = mundo.mesas[id];
    if (m == null) throw MesaNaoEncontrada();
    return m;
  }

  void _exigeMestre(String mesaId) {
    if (_exigeMesa(mesaId).mestreUid != _uid) throw SemPermissao();
  }

  @override
  Future<Mesa> criarMesa(String nome, String meuNome) async {
    _exigeLogin();
    final id = mundo.novoId();
    final mesa = Mesa(
      id: id,
      nome: nome,
      codigo: CodigoMesa.gerar(),
      mestreUid: _uid!,
      criadaEm: relogio(),
    );
    mundo.mesas[id] = mesa;
    mundo.membros[id] = {
      _uid!: Membro(
        uid: _uid!,
        nome: meuNome,
        papel: PapelMesa.mestre,
        entrouEm: relogio(),
        visto: relogio(),
      )
    };
    mundo.notificar(id);
    return mesa;
  }

  @override
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome) async {
    _exigeLogin();
    final alvo = CodigoMesa.normalizar(codigo);
    Mesa? mesa;
    for (final m in mundo.mesas.values) {
      if (m.codigo == alvo) mesa = m;
    }
    if (mesa == null) throw MesaNaoEncontrada();

    final atual = mundo.membros[mesa.id]?[_uid!];
    (mundo.membros[mesa.id] ??= {})[_uid!] = Membro(
      uid: _uid!,
      nome: meuNome,
      // já era mestre? continua mestre
      papel: atual?.papel ?? PapelMesa.jogador,
      entrouEm: atual?.entrouEm ?? relogio(),
      visto: relogio(),
    );
    mundo.notificar(mesa.id);
    return mesa;
  }

  // Observar exige login como no Firestore de verdade, onde `instance` sem
  // `Firebase.initializeApp` estoura. Sem esta exigência o fake deixa passar
  // a tela que assina o stream antes de entrar.
  @override
  Stream<Mesa?> observarMesa(String mesaId) {
    _exigeLogin();
    return mundo.streamMesa(mesaId);
  }

  @override
  Stream<List<Membro>> observarMembros(String mesaId) {
    _exigeLogin();
    return mundo.streamMembros(mesaId);
  }

  @override
  Future<void> baterPonto(String mesaId) async {
    _exigeLogin();
    final m = mundo.membros[mesaId]?[_uid!];
    if (m == null) return;
    mundo.membros[mesaId]![_uid!] = Membro(
      uid: m.uid,
      nome: m.nome,
      papel: m.papel,
      entrouEm: m.entrouEm,
      visto: relogio(),
    );
    mundo.notificar(mesaId);
  }

  @override
  Future<void> sair(String mesaId) async {
    _exigeLogin();
    // a ficha sai junto: quem não está na mesa não deixa cópia para trás
    mundo.fichas[mesaId]?.remove(_uid);
    mundo.membros[mesaId]?.remove(_uid);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> removerMembro(String mesaId, String alvo) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.membros[mesaId]?.remove(alvo);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> trocarCodigo(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    final m = _exigeMesa(mesaId);
    mundo.mesas[mesaId] = Mesa(
      id: m.id,
      nome: m.nome,
      codigo: CodigoMesa.gerar(),
      mestreUid: m.mestreUid,
      criadaEm: m.criadaEm,
    );
    mundo.notificar(mesaId);
  }

  // Esvazia a mesa mas não toca em `mundo.mesas`: o documento da mesa (e o
  // `mestreUid` nele) sobrevive, e é só por isso que o mestre continua
  // mandando na mesa depois de encerrar a sessão.
  @override
  Future<void> encerrarSessao(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.membros.remove(mesaId);
    mundo.fichas.remove(mesaId);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> apagarMesa(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mesas.remove(mesaId);
    mundo.membros.remove(mesaId);
    mundo.fichas.remove(mesaId);
    mundo.galeria.remove(mesaId);
    mundo.cheias.remove(mesaId);
    mundo.mural.remove(mesaId);
    mundo.notificar(mesaId);
  }

  @override
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome) async {
    _exigeLogin();
    _exigeMesa(mesaId);
    (mundo.fichas[mesaId] ??= {})[_uid!] = FichaNaMesa(
      donoUid: _uid!,
      nome: nome,
      atualizadaEm: relogio(),
      ficha: Map<String, dynamic>.from(ficha),
    );
    mundo.notificar(mesaId);
  }

  @override
  Future<void> despublicarFicha(String mesaId) async {
    _exigeLogin();
    mundo.fichas[mesaId]?.remove(_uid);
    mundo.notificar(mesaId);
  }

  /// Só existe no fake, para provar nos testes que o mestre NÃO pode.
  Future<void> despublicarFichaDe(String mesaId, String donoUid) async {
    if (donoUid != _uid) throw SemPermissao();
    await despublicarFicha(mesaId);
  }

  bool _souMestreDe(String mesaId) => mundo.mesas[mesaId]?.mestreUid == _uid;

  /// O que ESTE uid pode ver. No Firestore quem corta é a regra de segurança;
  /// aqui o corte é na mão, para o fake não mentir sobre o que o jogador
  /// enxerga.
  List<FichaNaMesa> _visiveis(String mesaId) {
    final todas = mundo.fichas[mesaId]?.values.toList() ?? const <FichaNaMesa>[];
    if (_souMestreDe(mesaId)) return todas;
    return todas.where((f) => f.donoUid == _uid).toList();
  }

  @override
  Stream<List<FichaNaMesa>> observarFichas(String mesaId) {
    _exigeLogin();
    return mundo.streamFichas(mesaId).map((_) => _visiveis(mesaId));
  }

  @override
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid) =>
      observarFichas(mesaId).map((lista) {
        for (final f in lista) {
          if (f.donoUid == donoUid) return f;
        }
        return null;
      });

  @override
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    final id = 'img-${mundo.galeria[mesaId]?.length ?? 0}-${relogio()
        .microsecondsSinceEpoch}';
    (mundo.cheias[mesaId] ??= {})[id] = imagemBase64;
    (mundo.galeria[mesaId] ??= {})[id] = ItemGaleria(
      id: id,
      legenda: legenda,
      porUid: _uid!,
      miniaturaBase64: miniaturaBase64,
      em: relogio(),
    );
    mundo.notificar(mesaId);
    return id;
  }

  @override
  Future<void> apagarDaGaleria(String mesaId, String imagemId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.cheias[mesaId]?.remove(imagemId);
    mundo.galeria[mesaId]?.remove(imagemId);
    // a imagem em destaque acabou de sumir: o mural não pode apontar para ela
    if (mundo.mural[mesaId]?.imagemId == imagemId) {
      mundo.mural.remove(mesaId);
    }
    mundo.notificar(mesaId);
  }

  @override
  Stream<List<ItemGaleria>> observarGaleria(String mesaId) =>
      mundo.streamGaleria(mesaId).map((_) {
        final itens = mundo.galeria[mesaId]?.values.toList() ??
            const <ItemGaleria>[];
        final ordenados = [...itens]..sort((a, b) => b.em.compareTo(a.em));
        return ordenados;
      });

  @override
  Future<String?> imagemCheia(String mesaId, String imagemId) async =>
      mundo.cheias[mesaId]?[imagemId];

  @override
  Future<void> mostrarAgora(String mesaId, String imagemId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mural[mesaId] = ItemMural(imagemId: imagemId, em: relogio());
    mundo.notificar(mesaId);
  }

  @override
  Future<void> limparMural(String mesaId) async {
    _exigeLogin();
    _exigeMestre(mesaId);
    mundo.mural.remove(mesaId);
    mundo.notificar(mesaId);
  }

  @override
  Stream<ItemMural?> observarMural(String mesaId) {
    _exigeLogin();
    return mundo.streamMural(mesaId);
  }
}
