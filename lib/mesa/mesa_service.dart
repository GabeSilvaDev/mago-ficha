import 'modelos.dart';

/// A mesa procurada não existe (ou o código foi trocado).
class MesaNaoEncontrada implements Exception {
  @override
  String toString() => 'Não encontrei essa mesa.';
}

/// A ação é só do mestre.
class SemPermissao implements Exception {
  @override
  String toString() => 'Só o mestre da mesa pode fazer isso.';
}

/// A chave de recuperação informada não é a da mesa.
class ChaveErrada implements Exception {
  @override
  String toString() => 'Chave não confere.';
}

/// Uma ficha publicada numa mesa. É uma cópia: a verdade continua no Hive do
/// dono. Só o dono escreve; o mestre lê.
class FichaNaMesa {
  final String donoUid;
  final String nome;
  final DateTime atualizadaEm;
  final Map<String, dynamic> ficha;

  const FichaNaMesa({
    required this.donoUid,
    required this.nome,
    required this.atualizadaEm,
    required this.ficha,
  });

  factory FichaNaMesa.fromJson(String donoUid, Map<String, dynamic> j) =>
      FichaNaMesa(
        donoUid: donoUid,
        nome: (j['nome'] ?? '') as String,
        atualizadaEm: DateTime.parse(j['atualizadaEm'] as String),
        ficha: (j['ficha'] as Map).cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'dono': donoUid,
        'nome': nome,
        'atualizadaEm': atualizadaEm.toIso8601String(),
        'ficha': ficha,
      };
}

/// Uma imagem na galeria da mesa, do jeito leve: sem a imagem cheia.
class ItemGaleria {
  final String id;
  final String legenda;
  final String porUid;
  final String miniaturaBase64;
  final DateTime em;

  const ItemGaleria({
    required this.id,
    required this.legenda,
    required this.porUid,
    required this.miniaturaBase64,
    required this.em,
  });

  factory ItemGaleria.fromJson(String id, Map<String, dynamic> j) => ItemGaleria(
        id: id,
        legenda: (j['legenda'] ?? '') as String,
        porUid: (j['porUid'] ?? '') as String,
        miniaturaBase64: (j['miniatura'] ?? '') as String,
        em: DateTime.parse(j['em'] as String),
      );

  Map<String, dynamic> toJson() => {
        'legenda': legenda,
        'porUid': porUid,
        'miniatura': miniaturaBase64,
        'em': em.toIso8601String(),
      };
}

/// O que está em destaque no mural agora. Aponta para uma imagem da galeria —
/// carregar a imagem aqui faria todo aparelho baixá-la de novo a cada mudança.
class ItemMural {
  final String imagemId;
  final DateTime em;

  const ItemMural({required this.imagemId, required this.em});

  factory ItemMural.fromJson(Map<String, dynamic> j) => ItemMural(
        imagemId: (j['imagemId'] ?? '') as String,
        em: DateTime.parse(j['em'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'imagemId': imagemId, 'em': em.toIso8601String()};
}

/// Tudo que o app precisa da mesa online.
///
/// Existe como interface para as telas serem testáveis sem rede: em produção
/// roda `MesaFirestore`, nos testes roda `MesaFake`. As duas implementações
/// precisam recusar exatamente as mesmas coisas — se divergirem, o teste passa
/// a mentir sobre o que as regras de segurança fazem de verdade.
abstract class MesaService {
  /// Login anônimo. Devolve o uid deste aparelho.
  Future<String> entrarAnonimo();

  /// uid da sessão atual, ou null se ainda não entrou.
  String? get uid;

  /// Cria a mesa e devolve, junto, a chave de recuperação. A chave é mostrada
  /// uma vez: quem a tem manda na mesa.
  Future<(Mesa, String)> criarMesa(String nome, String meuNome);

  /// Entra pelo código. Lança [MesaNaoEncontrada] se não existir.
  /// Entrar de novo na mesma mesa é idempotente.
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome);

  /// Irmã de [entrarPorCodigo], sem a etapa de resolver o código: usada para
  /// voltar a uma mesa já conhecida pelo aparelho. Grava o registro de membro
  /// PRIMEIRO e só então lê a mesa — depois de `encerrarSessao` ninguém é
  /// membro, e a regra de leitura só libera para quem já é. Lança
  /// [MesaNaoEncontrada] se a mesa não existir (mestre apagou).
  Future<Mesa> entrarPorId(String mesaId, String meuNome);

  /// Volta a ser o mestre de uma mesa provando a chave. Lança [ChaveErrada]
  /// se não bater, [MesaNaoEncontrada] se o código não existir.
  Future<Mesa> reassumirMesa(String codigo, String chave, String meuNome);

  /// Emite null quando a mesa deixa de existir (mestre apagou).
  Stream<Mesa?> observarMesa(String mesaId);

  Stream<List<Membro>> observarMembros(String mesaId);

  /// Batimento de presença.
  Future<void> baterPonto(String mesaId);

  /// Sai da mesa (remove só o próprio membro).
  Future<void> sair(String mesaId);

  /// Só o mestre. Lança [SemPermissao] caso contrário.
  Future<void> removerMembro(String mesaId, String uid);

  /// Só o mestre. Gera um código novo e invalida o anterior.
  Future<void> trocarCodigo(String mesaId);

  /// Só o mestre. Esvazia a mesa: tira todos os membros e as fichas
  /// publicadas. A mesa em si, o código, a chave e a galeria continuam de pé
  /// — é assim que a mesma crônica se reencontra no sábado seguinte.
  Future<void> encerrarSessao(String mesaId);

  /// Só o mestre. Apaga a mesa inteira, para sempre.
  Future<void> apagarMesa(String mesaId);

  /// Publica (ou atualiza) a MINHA ficha nesta mesa.
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome);

  /// Tira a minha ficha da mesa.
  Future<void> despublicarFicha(String mesaId);

  /// Mestre: todas as fichas publicadas. Jogador: só a dele (uma ou nenhuma).
  Stream<List<FichaNaMesa>> observarFichas(String mesaId);

  /// Uma ficha específica. Null se não existe ou se você não pode ver.
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid);

  /// Só o mestre. Guarda a imagem na galeria e devolve o id dela.
  Future<String> guardarNaGaleria(String mesaId, String imagemBase64,
      String miniaturaBase64, String legenda);

  /// Só o mestre. Tira a imagem da galeria, junto com a imagem cheia.
  Future<void> apagarDaGaleria(String mesaId, String imagemId);

  /// Mais recente primeiro. Só miniaturas.
  Stream<List<ItemGaleria>> observarGaleria(String mesaId);

  /// A imagem cheia, buscada só quando alguém abre. Null se não existe.
  Future<String?> imagemCheia(String mesaId, String imagemId);

  /// Só o mestre. Põe a imagem em destaque: abre na tela de todos.
  Future<void> mostrarAgora(String mesaId, String imagemId);

  /// Só o mestre. Tira o que estiver no mural.
  Future<void> limparMural(String mesaId);

  /// Null quando não há nada no mural.
  Stream<ItemMural?> observarMural(String mesaId);
}
