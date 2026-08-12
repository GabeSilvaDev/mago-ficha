# Atualização do app de Mago: A Ascensão — design

Data: 2026-08-11

Reúne seis pedidas acumuladas (do Kaue e do Gabriel) numa atualização só,
implementada em cinco fases independentes.

## Escopo

| # | Pedida | Fase |
|---|--------|------|
| 1 | Especialização de Esfera a partir do nível 4 | 1 |
| 2 | Teto 10 em Esferas e Arete (não 5) | 1 |
| 3 | Anexo no PDF quando o texto não cabe na ficha oficial | 2 |
| 4 | Retrato do personagem (imagem escolhida pelo usuário) | 3 |
| 5 | Importação/exportação de fichas em massa (.zip) | 4 |
| 6 | Área do Narrador: cadernos com imagens, galeria estilo Notion, campos customizados, NPCs | 5 |

Fora de escopo: arte do livro embutida no app (engorda o APK e é material
protegido), sincronização em nuvem, edição colaborativa.

## Arquitetura

O app hoje guarda cada ficha como uma string JSON na box Hive `fichas`
(`FichaStore`), e o model `Ficha` é um `Map<String, dynamic>` livre com getters
defensivos. Isso continua.

### Boxes novos

| Box | Chave | Valor | Dono |
|-----|-------|-------|------|
| `fichas` | id da ficha | JSON da ficha (existente) | `FichaStore` |
| `imagens` | uuid | JPEG em base64 | `ImagemStore` |
| `notas` | uuid | JSON do caderno | `NotaStore` |
| `narrador` | chave fixa (`campos`) | JSON de config | `NarradorStore` |

Cada store tem seu `init()`; `main.dart` chama os quatro antes de `runApp`.

Imagem mora em box separado de propósito: a ficha é reescrita inteira a cada
`salvar()`, e um retrato de 150 KB embutido no JSON viraria 150 KB reescritos a
cada toque numa bolinha.

### NPC

NPC é uma `Ficha` com `data['tipo'] = 'npc'`. O model já é um `Map` sem esquema,
então NPC reaproveita serialização, galeria, retrato, backup e PDF sem código
duplicado. O que muda é só o caminho de criação (formulário curto em vez do
wizard) e o fato de a galeria conseguir separar PC de NPC. `tipo` ausente = `pc`.

### Campos novos na `Ficha`

```
'tipo': 'pc' | 'npc'                      // ausente = 'pc'
'retratoId': String?                      // id no box `imagens`
'especializacoesEsferas': [ {esfera, nome} ]
'campos': { <campoId>: <valor> }          // campos customizados do narrador
```

Todos opcionais: ficha antiga sem eles funciona igual (getters defensivos, como
os que já existem).

### Dependências novas

- `image` — redimensionar/recomprimir retratos (puro Dart, funciona na web).
- `archive` — ler e escrever o .zip do backup.

---

## Fase 1 — Regras: especialização de Esfera e teto 10

### Especialização de Esfera

O livro traz, na abertura de cada Esfera, uma linha `Especialidades:` (ex.:
Entropia → Caos, Decaimento, Destino, Fortuna, Necromancia, Ordem;
Correspondência → Conjuração, Portais, Teleportes, Vidência, Vigilância). As
variantes tecnocráticas da mesma Esfera (Ciência Dimensional, Correspondência
tecnocrática etc.) entram na mesma lista, sem duplicar nome.

**Dados** — `assets/data/esferas.json`, cada esfera ganha:

```json
{"chave": "correspondence", "nome": "Correspondência", "descricao": "...",
 "especialidades": ["Conjuração", "Portais", "Teleportes", "Vidência", "Vigilância"]}
```

`Esfera` (em `game_data.dart`) ganha `List<String> especialidades`.

**Regra** — o livro (Cap. Seis, quadro "Especialidades") permite escolher a
especialidade antes da graduação 4; ela só passa a valer (10 conta como dois
sucessos) ao chegar em 4. O app segue isso:

- Escolher é sempre permitido.
- Abaixo de `esferaFinal >= 4` a especialização aparece esmaecida com a dica
  "sem efeito até a Esfera chegar em 4".
- Modo iniciante: no máximo 1 especialização por Esfera. Modo livre: sem
  limite de quantidade.

**Model** — `especializacoesEsferas` como lista de `{esfera: <chave>, nome: <String>}`,
com os mesmos helpers já usados por `especializacoes` (habilidades):
`especEsferaDe(chave)`, `addEspecEsfera`, `removerEspecEsfera`. Zerar uma Esfera
não apaga a especialização (o jogador pode estar remanejando pontos); apagar é
ação explícita.

**UI** — passo Esferas do wizard: sob cada Esfera, um chip `+ especialização`
que abre um seletor com a lista do livro mais a opção "Outra…" (campo de texto).
`ficha_view_screen` mostra o nome da especialização ao lado da Esfera, no mesmo
estilo já usado nas Habilidades.

**PDF** — sai à direita do nome da Esfera, fonte 6.2pt, como já é feito com as
especializações de Habilidade. Se não couber na largura da coluna, vai para o
anexo (fase 2).

### Teto 10

Liga junto do `modoLivre` que já existe: ficha em modo livre desenha e permite
até 10 em Esferas e Arete; ficha iniciante continua em 5. Nenhuma opção nova
para o usuário decidir.

**Dados**

- `esferas.json` → `regra_criacao.maximo: 5`, `regra_criacao.maximo_livre: 10`.
- `bonus.json` → `arete_maximo: 5`, `arete_maximo_livre: 10`
  (`arete_maximo_criacao: 3` continua valendo durante a criação).

`GameData` expõe `esferasMaximo`, `esferasMaximoLivre`, `areteMaximo`,
`areteMaximoLivre`. Força de Vontade continua em 10 como já é hoje.

**UI** — `LinhaBolinhas` já aceita `max`; ganha ajuste automático de tamanho:
com `max > 5`, bolinha de 20→14px e espaçamento 2→1px, para a fileira de 10
caber na largura de celular (10×16 = 160px contra os 120px de hoje). O mesmo
vale para `_pontos()` em `ficha_view_screen`.

**PDF** — a ficha oficial tem 5 círculos impressos. `fileira()` continua
pintando no máximo 5 e, quando o valor final passa de 5, escreve o número logo
depois da última bolinha (`●●●●● 7`, 6.2pt). Vale para Esferas, Arete,
Atributos e Habilidades — qualquer traço que estoure a fileira.

**Migração** — nada a migrar: fichas antigas não passam de 5 e continuam
iguais.

---

## Fase 2 — Anexo do PDF

Hoje `paragrafo()` corta o texto que não cabe e emenda "..."; listas
(antecedentes, qualidades, defeitos, combate, maravilhas) somem em silêncio
quando passam do número de linhas da ficha oficial.

**Como fica**

1. As duas páginas oficiais continuam idênticas.
2. Onde o conteúdo foi cortado, o app escreve `(continua no anexo)` no lugar do
   `...`.
3. Depois da página 2 entram páginas de anexo (A4, `pw.MultiPage`, fundo branco,
   tipografia simples) com:
   - retrato do personagem, quando houver (fase 3);
   - os blocos de texto completos que foram cortados;
   - as entradas de lista que não couberam;
   - especializações de Esfera que não couberam na coluna;
   - valores acima de 5, escritos por extenso.
4. Anexo só existe se houver excedente. Ficha pequena continua com 2 páginas.

**Mudanças de código** — `paragrafo()` passa a devolver o texto que sobrou em
vez de descartá-lo, e as funções de lista passam a acumular o excedente numa
estrutura `_anexo` (mesmo padrão do `_sobrasPg2` que já existe). No fim de
`gerar()`, se `_anexo` não está vazio, as páginas extras são montadas.

---

## Fase 3 — Retrato e armazenamento de imagens

**`ImagemStore`** (`lib/store/imagem_store.dart`):

- `Future<String> salvar(Uint8List bytes)` — redimensiona para no máximo 1024px
  no maior lado, recomprime em JPEG q80, guarda em base64 no box `imagens` e
  devolve o id.
- `Uint8List? bytes(String id)`
- `Future<void> excluir(String id)`
- `Future<int> limpar()` — remove imagens que nenhuma ficha nem nota referencia
  (roda na abertura do app).

**Escolha da imagem** — `file_picker` (já é dependência) com
`type: FileType.image, withData: true`. Funciona em Android e na web.

**Onde aparece**

- Card da home: avatar circular com o retrato no lugar do ícone genérico.
- Topo da `ficha_view_screen`: retrato maior, tocável (trocar/remover).
- Passo Identidade do wizard: botão "Escolher retrato".
- Galeria do narrador (fase 5): capa do card.
- PDF: primeira página do anexo (a ficha oficial não tem espaço para foto).

**Export JSON** — a ficha exportada embute a imagem como
`"retrato": "data:image/jpeg;base64,..."` para o arquivo ser self-contained; na
importação o app extrai para o box `imagens` e guarda só o `retratoId`. Ficha
sem retrato não ganha o campo.

---

## Fase 4 — Backup em massa (.zip)

**Exportar** — gera `magos-backup-AAAA-MM-DD.zip`:

```
manifest.json              {versao: 1, app: "mago-a-ascensao", geradoEm, fichas: N, notas: N}
fichas/<slug>-<id8>.json   uma por ficha (PC e NPC), self-contained (retrato embutido)
narrador/campos.json       definições dos campos customizados
narrador/notas.json        cadernos (texto, tags, referências)
narrador/imagens/<id>.jpg  imagens usadas nos cadernos
```

Cada arquivo em `fichas/` é exatamente o formato do export individual que já
existe, então dá para pescar uma ficha do zip na mão e importar sozinha.

**Importar** — o mesmo botão aceita `.json` (ficha única, como hoje) ou `.zip`.
Com zip, o app lê o `manifest.json`, monta um resumo e **pede confirmação antes
de gravar**:

> 12 fichas · 3 cadernos · 5 campos
> 3 fichas já existem neste aparelho.

com escolha para as colidentes: **duplicar** (id novo, padrão), **substituir**
ou **pular**. Sem `manifest.json` ou com `versao` desconhecida, o import é
recusado com mensagem clara. Zip sem a pasta `narrador/` importa só as fichas.

**Onde fica** — menu ⋮ da home: "Importar…", "Exportar tudo (.zip)".

---

## Fase 5 — Área do Narrador

`HomeScreen` ganha uma `BottomNavigationBar` de duas abas: **Magos** (a lista de
hoje, intocada) e **Narrador**. A aba Narrador tem duas seções: **Galeria** e
**Cadernos**.

### Campos customizados

Definidos uma vez, valem para todos os personagens. Guardados em
`narrador/campos`:

```json
{"campos": [
  {"id": "uuid", "nome": "Status", "tipo": "tag",
   "opcoes": ["Vivo", "Morto", "Desaparecido"]},
  {"id": "uuid", "nome": "Sessão de entrada", "tipo": "numero"},
  {"id": "uuid", "nome": "Arete", "tipo": "derivado", "origem": "arete"}
]}
```

Tipos: `texto`, `numero`, `tag` (uma opção de uma lista), `derivado`. Campo
derivado lê direto da ficha (`arete`, `afiliacao`, `conceito`, `forcaVontade`,
`vitalidade`, `experiencia`) e não é editável — serve para ordenar e filtrar por
característica sem redigitar nada. Os outros tipos guardam o valor em
`ficha.data['campos'][campoId]`.

Apagar uma definição de campo remove também os valores dele nas fichas, com
confirmação.

### Galeria

Cards com retrato de capa, nome e até três campos escolhidos (o narrador decide
quais na engrenagem). Traz PCs e NPCs juntos, com filtro por tipo. Ordenação por
nome, atualização ou qualquer campo (inclusive derivado); filtro por valor de
tag. Tocar num card abre a ficha (PC) ou o editor de NPC.

### Cadernos

Box `notas`, um registro por caderno:

```json
{"id": "uuid", "titulo": "Sessão 4 — o Nodo", "texto": "...",
 "imagens": ["imgId"], "tags": ["sessão", "nodo"],
 "fichas": ["fichaId"], "criadoEm": "...", "atualizadoEm": "..."}
```

Texto simples (sem editor rico), imagens em linha no fim do bloco, tags para
filtrar, e referências a fichas que viram atalho para abrir o personagem. Busca
por título, texto e tag.

### NPC

Formulário curto: nome, retrato, conceito, afiliação, notas e traços livres
(reaproveita `outrasCaracteristicas`, que já existe e já sai no PDF). Um botão
"Abrir no criador completo" promove o NPC para o wizard, já que por baixo ele é
uma `Ficha` normal.

---

## Compatibilidade e migração

Nada de migração destrutiva. Toda leitura nova usa getter defensivo, do jeito
que o model já faz:

- `tipo` ausente → `pc`
- `retratoId` ausente → sem retrato
- `especializacoesEsferas` ausente → lista vazia
- `campos` ausente → `{}`
- boxes `imagens`, `notas` e `narrador` ausentes → criados vazios no `init()`

Ficha exportada por uma versão nova e importada numa antiga perde os campos
novos, mas continua abrindo — que é como o app já se comporta hoje.

## Testes

Cada fase entra com teste em `test/`, seguindo os três arquivos que já existem
(`ficha_test.dart`, `wizard_test.dart`, `ficha_pdf_test.dart`):

- **Fase 1** — limite de 5 em modo iniciante e 10 em modo livre; especialização
  de Esfera permitida abaixo de 4 mas marcada como inativa; uma por Esfera no
  modo iniciante; `esferas.json` traz `especialidades` nas nove Esferas.
- **Fase 2** — ficha com história de 5.000 caracteres gera anexo, o texto do
  anexo termina igual ao original (nada truncado), e ficha pequena continua com
  2 páginas.
- **Fase 3** — `ImagemStore.salvar` reduz uma imagem grande abaixo do teto de
  1024px; `limpar()` remove órfã e preserva referenciada; roundtrip de export e
  import de ficha com retrato.
- **Fase 4** — roundtrip: exportar N fichas em zip, limpar as boxes, importar,
  comparar os JSONs; colisão de id com as três políticas; zip sem manifesto é
  recusado.
- **Fase 5** — campo derivado ordena a galeria pelo valor certo; apagar campo
  limpa os valores nas fichas; caderno com imagem sobrevive ao roundtrip do zip.

## Ordem de implementação

1. Regras (especialização de Esfera + teto 10)
2. Anexo do PDF
3. Retrato + `ImagemStore`
4. Backup .zip
5. Área do Narrador

As fases 1 e 2 mexem em `wizard_screen.dart`, `ficha_view_screen.dart` e
`ficha_pdf.dart`; 3 a 5 acrescentam arquivos novos e tocam `home_screen.dart`.
Cada fase fecha com o app rodando e os testes passando, e pode ser lançada
sozinha se você quiser soltar antes do pacote inteiro.
