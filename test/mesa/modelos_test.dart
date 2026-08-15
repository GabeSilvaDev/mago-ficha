import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/mesa/modelos.dart';

void main() {
  final agora = DateTime.utc(2026, 8, 12, 20, 0, 0);

  Membro comVisto(Duration atras) => Membro(
        uid: 'u1',
        nome: 'Kaue',
        papel: PapelMesa.jogador,
        entrouEm: agora.subtract(const Duration(hours: 1)),
        visto: agora.subtract(atras),
      );

  test('online é quem bateu ponto há menos de 90s', () {
    expect(comVisto(const Duration(seconds: 5)).onlineEm(agora), isTrue);
    expect(comVisto(const Duration(seconds: 89)).onlineEm(agora), isTrue);
    expect(comVisto(const Duration(seconds: 91)).onlineEm(agora), isFalse);
    expect(comVisto(const Duration(minutes: 30)).onlineEm(agora), isFalse);
    expect(Membro.janelaOnline, const Duration(seconds: 90));
  });

  test('membro: roundtrip de json', () {
    final m = comVisto(const Duration(seconds: 10));
    final volta = Membro.fromJson('u1', m.toJson());
    expect(volta.uid, 'u1');
    expect(volta.nome, 'Kaue');
    expect(volta.papel, PapelMesa.jogador);
    expect(volta.visto, m.visto);
    expect(volta.entrouEm, m.entrouEm);
  });

  test('papel desconhecido cai em jogador, nunca em mestre', () {
    final m = Membro.fromJson('u2', {
      'nome': 'Estranho',
      'papel': 'sei-la',
      'entrouEm': agora.toIso8601String(),
      'visto': agora.toIso8601String(),
    });
    expect(m.papel, PapelMesa.jogador);
  });

  test('mesa: roundtrip de json', () {
    final mesa = Mesa(
      id: 'm1',
      nome: 'Sombras de SP',
      codigo: 'MAGO-4K7P',
      mestreUid: 'u9',
      criadaEm: agora,
    );
    final volta = Mesa.fromJson('m1', mesa.toJson());
    expect(volta.id, 'm1');
    expect(volta.nome, 'Sombras de SP');
    expect(volta.codigo, 'MAGO-4K7P');
    expect(volta.mestreUid, 'u9');
    expect(volta.criadaEm, agora);
  });
}
