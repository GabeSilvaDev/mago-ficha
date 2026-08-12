# Fase 1 — Especialização de Esfera e teto 10 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir especialização por Esfera (com a regra do livro: escolhe quando quiser, só vale em 4) e elevar o teto de Esferas e Arete de 5 para 10 nas fichas em modo livre.

**Architecture:** As listas de especialidade saem do livro e entram em `assets/data/esferas.json`, carregadas por `GameData` como os outros dados estáticos. A ficha (`Map` livre) ganha a lista `especializacoesEsferas`. O teto pega carona no `modoLivre` que já existe: `GameData.esferasMax(livre)` e `GameData.areteMax(livre)` devolvem 5 ou 10, e as bolinhas encolhem quando a fileira passa de 5.

**Tech Stack:** Flutter 3.12+, Dart, `flutter_test`, JSON em `assets/data/`, pacote `pdf`.

## Global Constraints

- Projeto: `/home/gabriel/Documentos/rpg/fichas/MagoAAssencao` (repositório git próprio).
- Código, comentários, nomes de campo e textos de UI em português do Brasil, como todo o resto do projeto.
- Nenhum campo novo é obrigatório: ficha antiga sem o campo tem que abrir igual (getters defensivos, padrão já usado em `lib/models/ficha.dart`).
- Não alterar o significado dos campos existentes (`esferas`, `bonus`, `modoLivre`).
- Testes rodam com `flutter test`; todo teste começa com `TestWidgetsFlutterBinding.ensureInitialized()` e `setUpAll(() async => GameData.carregar())` — padrão de `test/ficha_test.dart`.
- Rodar `flutter analyze` antes de cada commit; zero warning novo.
- Commits em português, sem menção a IA/Claude/Anthropic.

---

### Task 1: Dados das especializações e dos tetos

**Files:**
- Modify: `assets/data/esferas.json`
- Modify: `assets/data/bonus.json`
- Modify: `lib/data/game_data.dart:115-122` (classe `Esfera`), `lib/data/game_data.dart:278-302` (campos estáticos), `lib/data/game_data.dart:341-357` e `379-387` (carregamento)
- Test: `test/game_data_test.dart` (criar)

**Interfaces:**
- Consumes: nada (primeira task).
- Produces:
  - `Esfera.especialidades` → `List<String>`
  - `GameData.esferasMaximo` → `int` (5)
  - `GameData.esferasMaximoLivre` → `int` (10)
  - `GameData.areteMaximo` → `int` (5)
  - `GameData.areteMaximoLivre` → `int` (10)
  - `GameData.esferasMax(bool livre)` → `int`
  - `GameData.areteMax(bool livre)` → `int`

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/game_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/data/game_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GameData.carregar());

  test('as nove Esferas trazem lista de especialidades do livro', () {
    expect(GameData.esferas.length, 9);
    for (final e in GameData.esferas) {
      expect(e.especialidades, isNotEmpty, reason: 'Esfera ${e.nome} sem especialidades');
    }
    final corresp = GameData.esferaPorChave('correspondence')!;
    expect(corresp.especialidades, contains('Teleportes'));
    final entropia = GameData.esferaPorChave('entropy')!;
    expect(entropia.especialidades, contains('Necromancia'));
  });

  test('tetos: 5 no modo iniciante, 10 no modo livre', () {
    expect(GameData.esferasMaximo, 5);
    expect(GameData.esferasMaximoLivre, 10);
    expect(GameData.areteMaximo, 5);
    expect(GameData.areteMaximoLivre, 10);
    expect(GameData.esferasMax(false), 5);
    expect(GameData.esferasMax(true), 10);
    expect(GameData.areteMax(false), 5);
    expect(GameData.areteMax(true), 10);
  });
}
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `flutter test test/game_data_test.dart`
Expected: FAIL — `The getter 'especialidades' isn't defined for the type 'Esfera'` e `esferasMaximo` não definido.

- [ ] **Step 3: Acrescentar as especialidades no `esferas.json`**

Em `assets/data/esferas.json`, cada objeto de `esferas` ganha a chave `especialidades`. As listas são as do livro (M20, Cap. Dez — linha `Especialidades:` na abertura de cada Esfera); Correspondência, Espírito e Primórdio recebem também os termos das variantes tecnocráticas (Esfera Dados, Ciência Dimensional e Primórdio hipereconômico), sem repetir nome:

```json
  "esferas": [
    {"chave": "correspondence", "nome": "Correspondência", "descricao": "Espaço, distância e conexões: mover-se e agir à distância, unir ou separar lugares.",
     "especialidades": ["Conjuração", "Portais", "Teleportes", "Vidência", "Vigilância", "Co-localização", "Criptografia", "Fabricação", "Proteção de Dados"]},
    {"chave": "entropy", "nome": "Entropia", "descricao": "Sorte, destino, ordem e decadência: probabilidades, azar, deterioração e fados.",
     "especialidades": ["Caos", "Decaimento", "Destino", "Fortuna", "Necromancia", "Ordem"]},
    {"chave": "forces", "nome": "Forças", "descricao": "Energias físicas: fogo, eletricidade, luz, som, gravidade e movimento.",
     "especialidades": ["Alquimia", "Armamentos", "Clima", "Elementos", "Física", "Movimento", "Tecnologia"]},
    {"chave": "life", "nome": "Vida", "descricao": "Os corpos vivos: curar, ferir, transformar e alterar seres orgânicos.",
     "especialidades": ["Aprimoramento", "Criação", "Clonagem", "Cura", "Evolução", "Lesão", "Metamorfose", "Transformação"]},
    {"chave": "mind", "nome": "Mente", "descricao": "Pensamento e consciência: telepatia, ilusões, controle mental e projeção.",
     "especialidades": ["Comunicação", "Ilusão", "Emoção", "Programação Social", "Auto-Aprimoramento", "Viagem Astral", "Escudo Mental", "Psicodinâmicas", "Combate Psíquico"]},
    {"chave": "matter", "nome": "Matéria", "descricao": "A matéria inanimada: transmutar, moldar e alterar objetos e substâncias.",
     "especialidades": ["Conjuração", "Modelagem", "Padrões Complexos", "Refinamento", "Transmutação"]},
    {"chave": "prime", "nome": "Primórdio", "descricao": "A energia primal (Quintessência) da criação: criar do nada e afetar padrões mágicos.",
     "especialidades": ["Artífice", "Canalização", "Criação", "Destruição", "Percepções", "Ressonância", "Avaliação", "Empreendimentos Primordiais", "Fontes", "Geração de Capital Energético", "Investimento", "Valor Pessoal"]},
    {"chave": "spirit", "nome": "Espírito", "descricao": "O mundo espiritual e a Umbra: espíritos, portais e as realidades além do véu.",
     "especialidades": ["Celestiais", "Espíritos Primordiais", "Espíritos Tecnológicos", "Infernais", "Manipulação de Película", "Negociações Espirituais", "Possessão", "Viagem Umbral", "Anomalia Dimensional", "Mapeamento", "Subdimensões", "Teoria Aplicada"]},
    {"chave": "time", "nome": "Tempo", "descricao": "Percepção e manipulação do tempo: presságios, acelerar, retardar e ver além do agora.",
     "especialidades": ["Controle Temporal", "Gatilhos", "Percepções", "Profecia", "Viagem no Tempo"]}
  ],
```

No mesmo arquivo, `regra_criacao` ganha os dois tetos (as outras chaves ficam como estão):

```json
  "regra_criacao": {
    "pontos_gratuitos": 6,
    "maximo_criacao": 3,
    "maximo": 5,
    "maximo_livre": 10,
    "arete_inicial": 1,
    "forca_vontade_inicial": 5,
    "paradoxo_inicial": 0,
    "texto": "Distribua 6 pontos livremente entre as Esferas. Uma delas é a sua Afinidade (definida pela Facção) e precisa receber pelo menos 1 ponto. Iniciantes têm limite de 3 em cada Esfera."
  },
```

Em `assets/data/bonus.json`, acrescentar ao objeto raiz (ao lado de `arete_maximo_criacao`, que continua valendo para os 15 pontos de bônus):

```json
  "arete_maximo": 5,
  "arete_maximo_livre": 10,
```

- [ ] **Step 4: Ler os campos novos no `game_data.dart`**

Na classe `Esfera`:

```dart
class Esfera {
  final String chave;
  final String nome;
  final String descricao;
  final List<String> especialidades;
  Esfera(this.chave, this.nome, this.descricao, this.especialidades);
  factory Esfera.fromJson(Map<String, dynamic> j) => Esfera(
      j['chave'] as String,
      j['nome'] as String,
      (j['descricao'] ?? '') as String,
      List<String>.from(j['especialidades'] ?? const <String>[]));
}
```

Nos campos estáticos de `GameData`, ao lado de `esferasMaximoCriacao`:

```dart
  static late int esferasMaximo; // teto de uma Esfera na ficha pronta
  static late int esferasMaximoLivre; // teto no modo livre (mesa opcional)
  static late int areteMaximo;
  static late int areteMaximoLivre;
```

No `carregar()`, logo depois de `esferasMaximoCriacao`:

```dart
    esferasMaximo = (rc['maximo'] as num?)?.toInt() ?? 5;
    esferasMaximoLivre = (rc['maximo_livre'] as num?)?.toInt() ?? 10;
```

e, no bloco do `bonus.json`, depois de `areteMaximoCriacao`:

```dart
    areteMaximo = (bon['arete_maximo'] as num?)?.toInt() ?? 5;
    areteMaximoLivre = (bon['arete_maximo_livre'] as num?)?.toInt() ?? 10;
```

Por fim, os dois helpers, junto dos outros métodos estáticos:

```dart
  /// Teto de uma Esfera: 5 na regra padrão, 10 na mesa que joga em modo livre.
  static int esferasMax(bool livre) => livre ? esferasMaximoLivre : esferasMaximo;

  /// Teto do Arete, mesma lógica das Esferas.
  static int areteMax(bool livre) => livre ? areteMaximoLivre : areteMaximo;
```

- [ ] **Step 5: Rodar o teste e ver passar**

Run: `flutter test test/game_data_test.dart`
Expected: PASS (2 testes)

- [ ] **Step 6: Commit**

```bash
git add assets/data/esferas.json assets/data/bonus.json lib/data/game_data.dart test/game_data_test.dart
git commit -m "dados: especialidades por Esfera e tetos de 5/10"
```

---

### Task 2: Especializações de Esfera no model

**Files:**
- Modify: `lib/models/ficha.dart:43-47` (criação), `lib/models/ficha.dart:240-265` (bloco de Esferas)
- Test: `test/ficha_test.dart`

**Interfaces:**
- Consumes: `GameData.esferasMax(bool)` da Task 1.
- Produces:
  - `Ficha.especializacoesEsferas` → `List<Map<String, dynamic>>` de `{esfera, nome}`
  - `Ficha.especEsferaDe(String chave)` → `List<String>`
  - `Ficha.addEspecEsfera(String chave, String nome)` → `void`
  - `Ficha.removerEspecEsfera(String chave, String nome)` → `void`
  - `Ficha.especEsferaAtiva(String chave)` → `bool`

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar ao fim de `test/ficha_test.dart` (dentro do `main()`):

```dart
  test('especialização de Esfera: adiciona, lista e remove', () {
    final f = Ficha.criar();
    f.addEspecEsfera('correspondence', 'Teleportes');
    f.addEspecEsfera('correspondence', 'Portais');
    f.addEspecEsfera('entropy', 'Fortuna');
    expect(f.especEsferaDe('correspondence'), ['Teleportes', 'Portais']);
    expect(f.especEsferaDe('entropy'), ['Fortuna']);
    expect(f.especEsferaDe('time'), isEmpty);

    f.removerEspecEsfera('correspondence', 'Portais');
    expect(f.especEsferaDe('correspondence'), ['Teleportes']);
  });

  test('especialização de Esfera não duplica nem aceita vazio', () {
    final f = Ficha.criar();
    f.addEspecEsfera('life', 'Cura');
    f.addEspecEsfera('life', 'Cura');
    f.addEspecEsfera('life', '   ');
    expect(f.especEsferaDe('life'), ['Cura']);
  });

  test('especialização de Esfera só fica ativa a partir de 4', () {
    final f = Ficha.criar();
    f.addEspecEsfera('forces', 'Clima');
    f.setEsfera('forces', 3);
    expect(f.especEsferaAtiva('forces'), isFalse);
    f.setBonusEsfera('forces', 1); // final = 4
    expect(f.especEsferaAtiva('forces'), isTrue);
  });

  test('ficha antiga sem o campo abre com lista vazia', () {
    final f = Ficha({'id': 'x', 'nome': 'Antigo'});
    expect(f.especializacoesEsferas, isEmpty);
    expect(f.especEsferaDe('mind'), isEmpty);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_test.dart`
Expected: FAIL — `The method 'addEspecEsfera' isn't defined for the type 'Ficha'`.

- [ ] **Step 3: Implementar no model**

Em `lib/models/ficha.dart`, dentro do mapa de `Ficha.criar()`, logo abaixo de `'afinidade': ''`:

```dart
      // Especializações de Esfera (livro: escolhe quando quiser, só vale em 4)
      'especializacoesEsferas': <Map<String, dynamic>>[], // {esfera, nome}
```

E no bloco "Esferas + vantagens-base", depois de `setEsfera`:

```dart
  /// Especializações de Esfera: {esfera: <chave>, nome: <String>}.
  /// O livro permite escolher antes da graduação 4; o bônus (cada 10 conta
  /// como dois sucessos) só passa a valer quando a Esfera chega em 4.
  List<Map<String, dynamic>> get especializacoesEsferas =>
      _lista('especializacoesEsferas');

  List<String> especEsferaDe(String chave) => [
        for (final e in especializacoesEsferas)
          if (e['esfera'] == chave) '${e['nome']}',
      ];

  void addEspecEsfera(String chave, String nome) {
    final n = nome.trim();
    if (n.isEmpty || especEsferaDe(chave).contains(n)) return;
    adicionar('especializacoesEsferas', {'esfera': chave, 'nome': n});
  }

  void removerEspecEsfera(String chave, String nome) => especializacoesEsferas
      .removeWhere((e) => e['esfera'] == chave && e['nome'] == nome);

  /// A especialização já dá bônus nesta Esfera?
  bool especEsferaAtiva(String chave) => esferaFinal(chave) >= 4;
```

`_lista()` já cria a lista vazia quando o campo não existe, então ficha antiga funciona sem migração.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_test.dart`
Expected: PASS (todos, inclusive os quatro novos)

- [ ] **Step 5: Commit**

```bash
git add lib/models/ficha.dart test/ficha_test.dart
git commit -m "ficha: especializacoes de Esfera com regra de ativacao em 4"
```

---

### Task 3: Bolinhas que cabem em 10

**Files:**
- Modify: `lib/widgets/dots.dart`
- Test: `test/dots_test.dart` (criar)

**Interfaces:**
- Consumes: nada.
- Produces:
  - `LinhaBolinhas.tamanhoDe(int max)` → `double` (20 até 5 bolinhas, 14 acima)
  - `LinhaBolinhas.espacoDe(int max)` → `double` (2 até 5, 1 acima)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/dots_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_a_ascensao/widgets/dots.dart';

void main() {
  test('fileira de até 5 mantém a bolinha grande', () {
    expect(LinhaBolinhas.tamanhoDe(5), 20);
    expect(LinhaBolinhas.espacoDe(5), 2);
  });

  test('fileira de 10 encolhe a bolinha para caber no celular', () {
    expect(LinhaBolinhas.tamanhoDe(10), 14);
    expect(LinhaBolinhas.espacoDe(10), 1);
    // largura total = max * (tamanho + 2 * espaco)
    final larg10 = 10 * (LinhaBolinhas.tamanhoDe(10) + 2 * LinhaBolinhas.espacoDe(10));
    final larg5 = 5 * (LinhaBolinhas.tamanhoDe(5) + 2 * LinhaBolinhas.espacoDe(5));
    expect(larg10, lessThan(larg5 * 1.4));
  });

  testWidgets('desenha uma bolinha por ponto do teto', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LinhaBolinhas(valor: 7, max: 10, onChanged: (_) {}),
      ),
    ));
    expect(find.byType(Container), findsNWidgets(10));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/dots_test.dart`
Expected: FAIL — `The method 'tamanhoDe' isn't defined for the class 'LinhaBolinhas'`.

- [ ] **Step 3: Implementar**

Em `lib/widgets/dots.dart`, dentro da classe `LinhaBolinhas`, antes do `build`:

```dart
  /// Bolinha encolhe quando a fileira passa de 5: dez bolinhas de 20px não
  /// cabem na linha de um celular junto do nome do traço.
  static double tamanhoDe(int max) => max > 5 ? 14 : 20;
  static double espacoDe(int max) => max > 5 ? 1 : 2;
```

E no `build`, trocar os valores fixos:

```dart
  @override
  Widget build(BuildContext context) {
    final teto = maxInterativo ?? max;
    final tam = tamanhoDe(max);
    final espaco = espacoDe(max);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= max; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: i > teto
                ? null
                : () {
                    final novo = (valor == i) ? i - 1 : i;
                    onChanged(novo.clamp(min, teto));
                  },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: espaco, vertical: 4),
              child: Container(
                width: tam,
                height: tam,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= valor ? Cores.indigo : Colors.transparent,
                  border: Border.all(
                    color: i > teto ? Colors.grey.shade400 : Cores.dourado,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/dots_test.dart`
Expected: PASS (3 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dots.dart test/dots_test.dart
git commit -m "bolinhas: fileira de 10 encolhe para caber na linha"
```

---

### Task 4: Wizard — teto 10 e escolha da especialização

**Files:**
- Modify: `lib/screens/wizard_screen.dart:1255-1382` (`_pgEsferas`), `:1384-1430` (`_linhaEsfera`), `:2502-2530` (Esferas nos Toques Finais)
- Test: `test/wizard_test.dart`

**Interfaces:**
- Consumes: `GameData.esferasMax`, `Ficha.especEsferaDe`, `Ficha.addEspecEsfera`, `Ficha.removerEspecEsfera`, `Ficha.especEsferaAtiva`, `LinhaBolinhas`.
- Produces: nada consumido por outras tasks (só UI).

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar em `test/wizard_test.dart` (dentro do `main()`; o arquivo já monta a `WizardScreen` com `tester.pumpWidget` — siga o helper que já existe lá para abrir o passo de Esferas):

```dart
  testWidgets('modo livre desenha 10 bolinhas por Esfera', (tester) async {
    final f = Ficha.criar();
    f.modoLivre = true;
    await tester.pumpWidget(MaterialApp(home: WizardScreen(
      existente: f, passos: const [3], titulo: 'Esferas')));
    await tester.pumpAndSettle();

    final linhas = tester.widgetList<LinhaBolinhas>(find.byType(LinhaBolinhas));
    expect(linhas.where((l) => l.max == 10).length, greaterThanOrEqualTo(9));
  });

  testWidgets('modo iniciante mantém 5 bolinhas por Esfera', (tester) async {
    final f = Ficha.criar();
    f.modoLivre = false;
    await tester.pumpWidget(MaterialApp(home: WizardScreen(
      existente: f, passos: const [3], titulo: 'Esferas')));
    await tester.pumpAndSettle();

    final linhas = tester.widgetList<LinhaBolinhas>(find.byType(LinhaBolinhas));
    expect(linhas.every((l) => l.max <= 5), isTrue);
  });

  testWidgets('chip de especialização aparece e grava na ficha', (tester) async {
    final f = Ficha.criar();
    f.modoLivre = true;
    f.setEsfera('correspondence', 4);
    await tester.pumpWidget(MaterialApp(home: WizardScreen(
      existente: f, passos: const [3], titulo: 'Esferas')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('espec-correspondence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teleportes'));
    await tester.pumpAndSettle();

    expect(f.especEsferaDe('correspondence'), ['Teleportes']);
    expect(find.text('Teleportes'), findsOneWidget);
  });
```

Importar no topo do arquivo, se ainda não estiver: `package:mago_a_ascensao/widgets/dots.dart`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/wizard_test.dart`
Expected: FAIL — as bolinhas continuam com `max: 5` e não existe widget com a key `espec-correspondence`.

- [ ] **Step 3: Trocar o teto e acrescentar os chips**

Em `_pgEsferas()`, o teto de criação continua sendo cobrado no checklist; o que muda é quantas bolinhas são desenhadas. Substituir a chamada dentro do `Column` das Esferas:

```dart
                for (final e in GameData.esferas)
                  _linhaEsfera(e, teto, afin, bloqueadas.contains(e.chave)),
```

(mantém igual — quem muda é `_linhaEsfera`).

Reescrever `_linhaEsfera` para desenhar a fileira no teto certo e mostrar as especializações abaixo:

```dart
  Widget _linhaEsfera(Esfera e, int teto, String? afin, bool bloqueada) {
    final v = f.esfera(e.chave);
    final ehAfin = afin == e.chave;
    final maxBolinhas = GameData.esferasMax(_livre);
    final specs = f.especEsferaDe(e.chave);
    final ativa = f.especEsferaAtiva(e.chave);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                child: ehAfin
                    ? const Icon(Icons.star, size: 16, color: Cores.dourado)
                    : (bloqueada
                        ? const Icon(Icons.block, size: 15, color: Colors.grey)
                        : null),
              ),
              Expanded(
                child: _dica(
                  '${e.nome} — ${e.descricao}'
                  '${bloqueada ? '\n\n⚠ Bloqueada para a sua Facção.' : ''}',
                  Text(e.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: bloqueada ? Colors.grey : Cores.tinta)),
                ),
              ),
              LinhaBolinhas(
                valor: v,
                max: maxBolinhas,
                min: ehAfin ? 1 : 0,
                // Evolução: sem teto de iniciante (e Esfera bloqueada só avisa).
                maxInterativo: _livre ? maxBolinhas : (bloqueada ? 0 : teto),
                onChanged: (nv) => setState(() => f.setEsfera(e.chave, nv)),
              ),
              SizedBox(
                width: 20,
                child: Text('$v',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in specs)
                  InputChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    labelStyle: TextStyle(
                        color: ativa ? Cores.tinta : Colors.grey.shade600),
                    backgroundColor: Cores.pergaminhoEscuro,
                    visualDensity: VisualDensity.compact,
                    onDeleted: () =>
                        setState(() => f.removerEspecEsfera(e.chave, s)),
                  ),
                if (specs.isEmpty || _livre)
                  ActionChip(
                    key: ValueKey('espec-${e.chave}'),
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('especialização',
                        style: TextStyle(fontSize: 12)),
                    backgroundColor: Cores.pergaminhoEscuro,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _escolherEspecEsfera(e),
                  ),
                if (specs.isNotEmpty && !ativa)
                  Text('sem efeito até a Esfera chegar em 4',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seletor da especialização: a lista do livro mais "Outra…" (texto livre).
  Future<void> _escolherEspecEsfera(Esfera e) async {
    final jaTem = f.especEsferaDe(e.chave);
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Cores.pergaminho,
        title: Text('Especialização — ${e.nome}'),
        children: [
          for (final s in e.especialidades)
            if (!jaTem.contains(s))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s),
                child: Text(s),
              ),
          const Divider(color: Cores.dourado),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '__outra__'),
            child: const Text('Outra…',
                style: TextStyle(fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
    if (escolha == null) return;
    var nome = escolha;
    if (escolha == '__outra__') {
      final ctrl = TextEditingController();
      final digitado = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Cores.pergaminho,
          title: Text('Especialização — ${e.nome}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex.: Teleporte curto'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Adicionar')),
          ],
        ),
      );
      if (digitado == null || digitado.trim().isEmpty) return;
      nome = digitado;
    }
    setState(() => f.addEspecEsfera(e.chave, nome));
  }
```

No passo Toques Finais (por volta da linha 2502), a Esfera comprada com bônus também respeita o teto novo: trocar `maxFinal: GameData.esferasMaximoCriacao` por

```dart
                      maxFinal: _livre
                          ? GameData.esferasMax(true)
                          : GameData.esferasMaximoCriacao,
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/wizard_test.dart`
Expected: PASS (todos, inclusive os três novos)

- [ ] **Step 5: Conferir no app**

Run: `flutter run -d chrome`
Conferir: numa ficha em modo livre, o passo Esferas mostra 10 bolinhas e o chip `+ especialização`; numa ficha iniciante, 5 bolinhas com as acima de 3 travadas.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/wizard_screen.dart test/wizard_test.dart
git commit -m "wizard: teto 10 nas Esferas em modo livre e escolha de especializacao"
```

---

### Task 5: Tela da ficha — mostrar especializações e valores acima de 5

**Files:**
- Modify: `lib/screens/ficha_view_screen.dart:332-351` (`_pontos`), `:354-384` (`_cardEsferas`), `:392-405` (Arete)
- Test: `test/ficha_view_test.dart` (criar)

**Interfaces:**
- Consumes: `Ficha.especEsferaDe`, `Ficha.especEsferaAtiva`, `GameData.esferasMaximoLivre`, `GameData.areteMaximoLivre`.
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/ficha_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mago_a_ascensao/data/game_data.dart';
import 'package:mago_a_ascensao/models/ficha.dart';
import 'package:mago_a_ascensao/screens/ficha_view_screen.dart';
import 'package:mago_a_ascensao/store/ficha_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GameData.carregar();
    Hive.init('build/test-hive-view');
    await Hive.openBox<String>(FichaStore.boxName);
  });

  tearDown(() async => Hive.box<String>(FichaStore.boxName).clear());

  testWidgets('Esfera acima de 5 mostra as dez bolinhas e a especialização',
      (tester) async {
    final f = Ficha.criar();
    f.data['nome'] = 'Teste';
    f.setEsfera('correspondence', 7);
    f.addEspecEsfera('correspondence', 'Teleportes');
    await FichaStore.salvar(f);

    await tester.pumpWidget(MaterialApp(home: FichaViewScreen(fichaId: f.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esferas'));
    await tester.pumpAndSettle();

    expect(find.text('Teleportes'), findsOneWidget);
  });
}
```

Se `path_provider_platform_interface` não estiver disponível, remover o import — `Hive.init` com caminho fixo não precisa dele.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ficha_view_test.dart`
Expected: FAIL — o texto "Teleportes" não é encontrado.

- [ ] **Step 3: Implementar**

Em `_cardEsferas`, mostrar as especializações e ajustar o teto visual. Substituir o corpo do `for`:

```dart
            for (final e in GameData.esferas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (ficha.afinidade == e.chave)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star,
                                size: 14, color: Cores.dourado),
                          ),
                        Expanded(
                          child: Text(e.nome,
                              style: const TextStyle(color: Cores.tinta)),
                        ),
                        _pontos(ficha.esferaFinal(e.chave),
                            _tetoVisual(ficha.esferaFinal(e.chave))),
                      ],
                    ),
                    if (ficha.especEsferaDe(e.chave).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 18, top: 2),
                        child: Text(
                          ficha.especEsferaDe(e.chave).join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: ficha.especEsferaAtiva(e.chave)
                                ? Cores.indigo
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
```

E, junto de `_pontos`, o helper do teto visual:

```dart
  /// A ficha pronta mostra 5 bolinhas; só abre para 10 quando o valor passa
  /// de 5 (mesa que usa o teto opcional).
  int _tetoVisual(int v) => v > 5 ? GameData.esferasMaximoLivre : 5;
```

O Arete já é desenhado com 10 bolinhas (`_pontos(ficha.areteFinal, 10, ...)`), então não muda; trocar o `10` fixo por `GameData.areteMaximoLivre` para o número sair de um lugar só:

```dart
            FittedBox(
                fit: BoxFit.scaleDown,
                child: _pontos(ficha.areteFinal, GameData.areteMaximoLivre,
                    tam: 24, espaco: 5)),
```

O `_pontos` como está já desenha `max` bolinhas; com `tam: 22` padrão e 10 bolinhas a linha das Esferas fica larga, então envolver a chamada das Esferas num `FittedBox(fit: BoxFit.scaleDown, ...)` quando o teto passar de 5 — mais simples: passar `tam` menor:

```dart
                        _pontos(ficha.esferaFinal(e.chave),
                            _tetoVisual(ficha.esferaFinal(e.chave)),
                            tam: ficha.esferaFinal(e.chave) > 5 ? 15 : 22,
                            espaco: ficha.esferaFinal(e.chave) > 5 ? 2 : 3),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ficha_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/ficha_view_screen.dart test/ficha_view_test.dart
git commit -m "ficha: exibe especializacoes de Esfera e valores acima de 5"
```

---

### Task 6: PDF — valor acima de 5 escrito ao lado da fileira

**Files:**
- Modify: `lib/services/ficha_pdf.dart:130-136` (`fileira`) e as chamadas nas linhas 164, 185, 203, 240-241
- Test: `test/ficha_pdf_test.dart`

**Interfaces:**
- Consumes: `Ficha.esferaFinal`, `Ficha.areteFinal`.
- Produces: `fileira(...)` com parâmetro opcional `fonte` — usado pela Fase 2.

**Nota de escopo:** as especializações de Esfera **não** entram na página oficial. A coluna de Esferas da ficha impressa não tem folga entre o nome e as bolinhas (diferente das Habilidades, onde a especialização já cabe à esquerda), então elas vão para o anexo, na Fase 2 — é a cláusula de fallback do spec.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar em `test/ficha_pdf_test.dart`:

```dart
  test('ficha com Esfera 7 e Arete 8 gera PDF sem estourar', () async {
    final f = Ficha.criar();
    f.data['nome'] = 'Mestre da mesa livre';
    f.modoLivre = true;
    f.setEsfera('correspondence', 7);
    f.setEsfera('forces', 6);
    f.afinidade = 'correspondence';
    f.data['arete'] = 8;

    final bytes = await FichaPdf.gerar(f);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(100000));

    final out = File('build/ficha_test_teto10.pdf');
    out.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  });
```

- [ ] **Step 2: Rodar e ver o comportamento atual**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS na geração, mas o PDF em `build/ficha_test_teto10.pdf` mostra só 5 bolinhas e nenhum número — é isso que a implementação vai corrigir. (Este teste é a rede de segurança contra exceção; a conferência do número é visual, no arquivo gerado.)

- [ ] **Step 3: Implementar**

Em `lib/services/ficha_pdf.dart`, trocar `fileira` por:

```dart
    /// Pinta as bolinhas da fileira. A ficha oficial tem 5 círculos impressos;
    /// quando o valor final passa disso (mesa com teto 10), escreve o número
    /// logo depois da última bolinha.
    void fileira(PdfGraphics g, Map fila, int valor,
        {double rPx = 7, PdfFont? fonte}) {
      final xs = (fila['xs'] as List).cast<num>();
      final y = fila['y'] as num;
      for (var k = 0; k < valor.clamp(0, xs.length); k++) {
        bola(g, xs[k], y, rPx);
      }
      if (fonte != null && valor > xs.length) {
        texto(g, fonte, '$valor', xs.last + 13, y + 4, tam: 7.0);
      }
    }
```

Passar a fonte nas chamadas de Atributos, Habilidades, Esferas e Arete da página 1:

```dart
          fileira(g, filas[i], f.atributoFinal(cat.tracos[i].nome), fonte: fonte);
```
```dart
          fileira(g, filas[i], f.habilidadeFinal(nomeHab), fonte: fonte);
```
```dart
          fileira(g, filas[i], f.esferaFinal(chaves[i]), fonte: fonte);
```
```dart
      fileira(g, p1['arete'] as Map, f.areteFinal, fonte: fonte);
      fileira(g, p1['fdvCirc'] as Map, f.forcaVontadeFinal, fonte: fonte);
```

As chamadas de Antecedentes e Outras Características ficam sem `fonte`: ali o excedente já tem tratamento próprio (as sobras vão para a página 2).

- [ ] **Step 4: Rodar e conferir**

Run: `flutter test test/ficha_pdf_test.dart`
Expected: PASS (2 testes)

Abrir `build/ficha_test_teto10.pdf` e conferir: Correspondência com 5 bolinhas cheias e `7` ao lado; Arete com `8`.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ficha_pdf.dart test/ficha_pdf_test.dart
git commit -m "pdf: escreve o numero quando o traco passa das cinco bolinhas"
```

---

### Task 7: Fechamento da fase

- [ ] **Step 1: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS em todos os arquivos.

- [ ] **Step 2: Analisar**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Conferir a ficha demo antiga**

Run: `flutter run -d chrome`, importar `docs/ficha-demo.json` pelo menu ⋮.
Expected: abre normal, sem especializações de Esfera, bolinhas em 5.

- [ ] **Step 4: Commit final**

```bash
git add -A
git commit -m "fase 1: especializacao de Esfera e teto 10 concluidos"
```
