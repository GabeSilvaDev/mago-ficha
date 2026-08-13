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

  Future<Mesa> criarMesa(String nome, String meuNome);

  /// Entra pelo código. Lança [MesaNaoEncontrada] se não existir.
  /// Entrar de novo na mesma mesa é idempotente.
  Future<Mesa> entrarPorCodigo(String codigo, String meuNome);

  /// Emite null quando a mesa deixa de existir (mestre fechou).
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

  /// Só o mestre. Apaga a mesa inteira.
  Future<void> fecharMesa(String mesaId);

  /// Publica (ou atualiza) a MINHA ficha nesta mesa.
  Future<void> publicarFicha(
      String mesaId, Map<String, dynamic> ficha, String nome);

  /// Tira a minha ficha da mesa.
  Future<void> despublicarFicha(String mesaId);

  /// Mestre: todas as fichas publicadas. Jogador: só a dele (uma ou nenhuma).
  Stream<List<FichaNaMesa>> observarFichas(String mesaId);

  /// Uma ficha específica. Null se não existe ou se você não pode ver.
  Stream<FichaNaMesa?> observarFicha(String mesaId, String donoUid);
}
