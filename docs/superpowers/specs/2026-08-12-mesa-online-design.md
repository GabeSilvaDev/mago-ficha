# Mesa online — design

Data: 2026-08-12
Branch: `mesa-online`

A mesa presencial ganha uma camada online opcional: o jogador publica a ficha
numa mesa, o mestre acompanha ao vivo, e o mestre mostra imagens que aparecem
no celular de todo mundo. Ao sair, tudo volta a ser 100% offline.

## A decisão que define o resto

**Cada ficha tem um único escritor: o dono.** O mestre lê e não escreve.

Disso decorre tudo:

- Não existe conflito de edição. Não há merge, não há "quem ganha", não há
  edição simultânea do mesmo campo.
- A cópia na nuvem é **projeção**, nunca fonte. O Hive local continua sendo a
  verdade.
- "As fichas alteradas continuam alteradas depois de sair" sai de graça: as
  mudanças sempre nasceram no aparelho do dono. Não há sincronização de volta.

Um desenho em que o mestre também edita exigiria escrita por campo, resolução de
conflito e sincronização bidirecional — a parte onde este tipo de projeto
costuma quebrar. O ganho de "o mestre marca o dano por você" não paga esse
custo, e a mesa é presencial: o mestre fala e o jogador marca.

## Objetivos

1. O app continua funcionando 100% offline para quem nunca entrar numa mesa.
2. O jogador entra numa mesa com um código curto e escolhe qual ficha publicar.
3. O que ele muda aparece para o mestre em segundos.
4. O mestre mostra uma imagem e ela abre no celular de todos.
5. Ao sair, o app volta ao offline e a ficha local mantém tudo.

## Não-objetivos

Fora desta entrega, e de propósito:

- Mestre editar ficha de jogador (decisão acima).
- Jogador ver a ficha de outro jogador.
- Compartilhar ficha de NPC. Os NPCs do mestre são fichas dele, no aparelho
  dele, e continuam locais.
- Chat, rolagem de dados compartilhada, cadernos na mesa.
- Firebase Storage. As imagens do mural cabem no próprio documento (ver Fase 3).
- Jogar remoto como caso principal. Funciona, mas o desenho assume presencial.

## Arquitetura

**Serviços:** Firebase Authentication (login anônimo) e Cloud Firestore. Só
isso.

**Isolamento:** todo o código novo vive em `lib/mesa/`. `MesaService` é uma
interface; a implementação Firestore roda em produção e um fake em memória roda
nos testes, então as telas são testáveis sem rede.

```
lib/mesa/
├── modelos.dart          # Mesa, Membro, papel, estado de presença
├── mesa_service.dart     # interface + erros de domínio
├── mesa_firestore.dart   # implementação Firestore
├── mesa_fake.dart        # implementação em memória (testes)
├── mesa_store.dart       # em que mesa este aparelho está (Hive, local)
├── codigo.dart           # gerador e validador do código da mesa
└── telas/                # aba Mesa, entrar, publicar ficha, visão do mestre
```

**Inicialização preguiçosa.** `Firebase.initializeApp` só roda quando o usuário
entra numa mesa pela primeira vez. Quem nunca usar mesa não abre conexão
nenhuma — a promessa de offline continua literal, não só no discurso.

**Estado local da mesa** (`mesa_store.dart`, box Hive `mesa`): id da mesa atual,
uid, papel e qual ficha está publicada. É o que permite reabrir o app já dentro
da mesa.

## Modelo de dados

```
codigos/{CODIGO}
  { mesaId }

mesas/{mesaId}
  { nome, codigo, mestreUid, criadaEm }

mesas/{mesaId}/membros/{uid}
  { nome, papel: 'mestre' | 'jogador', entrouEm, visto }

mesas/{mesaId}/fichas/{uid}
  { dono: uid, nome, atualizadaEm, ficha: <JSON da ficha, igual ao export> }

mesas/{mesaId}/mural/atual
  { imagem: <base64 JPEG>, legenda, porUid, em }
```

**Por que `codigos` é uma coleção separada.** Para entrar, o app precisa achar a
mesa pelo código *antes* de ser membro. Se essa busca fosse uma query em
`mesas`, qualquer pessoa autenticada conseguiria varrer todas as mesas
existentes. Com `codigos`, o não-membro só consegue resolver código → id; a mesa
em si só abre para membro.

**O `ficha` é o mesmo JSON do export** (`FichaIO.paraJson`), com o retrato
embutido. Nenhum formato novo para manter.

## Regras de segurança

Não existe servidor: as regras **são** a segurança. Elas cabem em uma tela e é
proposital — regra que ninguém consegue ler inteira é regra que ninguém audita.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    function logado()  { return request.auth != null; }
    function uid()     { return request.auth.uid; }
    function mesa(id)  { return get(/databases/$(db)/documents/mesas/$(id)).data; }
    function souMestre(id) { return logado() && mesa(id).mestreUid == uid(); }
    function souMembro(id) {
      return logado() &&
        exists(/databases/$(db)/documents/mesas/$(id)/membros/$(uid()));
    }

    // resolver código -> mesa: qualquer logado lê.
    // Só o mestre da mesa apontada cria e apaga a entrada, e nunca a altera —
    // por isso a mesa é criada primeiro e o código depois.
    match /codigos/{codigo} {
      allow read: if logado();
      allow create: if logado() &&
        get(/databases/$(db)/documents/mesas/$(request.resource.data.mesaId))
          .data.mestreUid == uid();
      allow delete: if logado() &&
        get(/databases/$(db)/documents/mesas/$(resource.data.mesaId))
          .data.mestreUid == uid();
      allow update: if false;
    }

    match /mesas/{mesaId} {
      allow read:   if souMembro(mesaId);
      allow create: if logado() && request.resource.data.mestreUid == uid();
      allow update, delete: if souMestre(mesaId);

      match /membros/{membroUid} {
        allow read:   if souMembro(mesaId);
        // entrar e bater ponto: só o próprio
        allow create, update: if logado() && membroUid == uid();
        // sair (o próprio) ou ser removido (o mestre)
        allow delete: if logado() && (membroUid == uid() || souMestre(mesaId));
      }

      match /fichas/{donoUid} {
        // a ficha do jogador: ele e o mestre. Mais ninguém.
        allow read: if logado() && (donoUid == uid() || souMestre(mesaId));
        allow write: if logado() && donoUid == uid();
      }

      match /mural/{doc} {
        allow read:  if souMembro(mesaId);
        allow write: if souMestre(mesaId);
      }
    }
  }
}
```

O `create` da mesa deixa qualquer logado criar uma mesa em que ele é o mestre —
é o que permite criar mesa sem servidor nenhum. O código é gravado logo depois,
já com a mesa existindo, porque a regra de `codigos` consulta o `mestreUid` dela.

## Ciclo de vida dos dados

| Ação | O que acontece na nuvem | O que acontece no aparelho |
|---|---|---|
| Publicar ficha | cria `fichas/{uid}` | marca a ficha como publicada |
| Editar a ficha | reescreve `fichas/{uid}` (agrupado) | salva no Hive, como hoje |
| Sair da mesa | apaga `fichas/{uid}` e `membros/{uid}` | limpa o estado da mesa; ficha intacta |
| Mestre fecha a mesa | apaga a mesa inteira e o código | cada aparelho detecta e volta ao offline |

A ficha do jogador não fica hospedada na internet fora da sessão. É a razão de
apagar ao sair, e não só desligar o espelho.

## Fase 1 — Mesa e identidade

**Entrar.** Login anônimo. A identidade mora no aparelho: quem reinstala vira um
membro novo e o mestre reconecta com um toque. Ninguém cria conta nem senha.

**Código.** 8 caracteres em alfabeto sem ambiguidade (sem `O`/`0`, sem `I`/`1`),
formato `MAGO-4K7P`, feito para ser ditado em voz alta. Um QR opcional na mesma
tela para quem preferir apontar a câmera.

**Entrada direta:** quem tem o código entra. O mestre vê a lista e remove quem
não devia estar lá, e pode trocar o código a qualquer momento.

**Presença** por heartbeat: com o app aberto na mesa, grava `visto` a cada 30s;
"online" é `visto` de menos de 90s atrás. Sem serviço extra, sem socket.

**Interface:** a barra de baixo passa de duas para três abas —
**Magos · Mesa · Narrador**. A Mesa precisa ser alcançável pelo jogador, que
nunca abre a aba Narrador. Sem mesa: "Criar mesa" ou "Entrar com código". Com
mesa: nome, código com copiar e QR, membros com bolinha de presença e papel,
botão de sair. Para o mestre: remover membro, trocar código, fechar a mesa.

## Fase 2 — Ficha espelhada

**Publicar.** Na aba Mesa, o jogador escolhe uma das fichas locais. Uma por
pessoa nesta entrega.

**Espelhar.** `FichaStore.salvar` é o único ponto de escrita do app — o espelho
entra ali. Como o app salva a cada toque numa bolinha, as escritas são agrupadas
numa janela de 2 segundos: uma rajada de toques vira uma escrita só.

**Visão do mestre.** Lista das fichas publicadas com nome, retrato e o estado de
jogo (vitalidade, Força de Vontade, Quintessência, Paradoxo, XP); tocar abre a
ficha inteira em modo leitura, reaproveitando a tela que já existe.

**Somente leitura, de verdade:** a tela do mestre não é a tela de edição com
botões escondidos. É a `FichaViewScreen` com os controles de tracker
desabilitados e sem o lápis de editar.

## Fase 3 — Mural de imagens

O mestre escolhe uma imagem (a mesma do `ImagemStore`, já reduzida para 1024px
JPEG q80) e ela vai para `mural/atual`. Todo aparelho na mesa recebe e abre no
`VisualizadorImagens` que já existe, incluindo o modo mostrar.

**Sem Firebase Storage.** Uma imagem de 1024px q80 dá 150–250 KB; em base64,
200–330 KB — cabe no limite de 1 MiB por documento do Firestore. Se passar de
700 KB, o app reencoda a 800px antes de enviar. Isso evita configurar e proteger
um bucket inteiro para um caso que cabe no documento.

O mestre tira a imagem do mural quando quiser; sair da mesa não apaga o mural
(ele é do mestre), fechar a mesa apaga.

## Offline e erros

O Firestore mantém cache local e fila de escrita: se o wifi cair no meio da
sessão, cada um continua jogando e o espelho sobe quando a rede volta. É o
motivo de escolher Firebase e não uma solução com sincronização própria.

| Situação | O que o app faz |
|---|---|
| Sem internet ao criar/entrar | "Sem conexão para entrar na mesa." O resto do app segue normal. |
| Código não existe | "Não encontrei essa mesa." |
| Já é membro | Entra direto; a operação é idempotente. |
| Mestre fechou a mesa | Aviso na tela e volta ao modo offline, com a ficha local intacta. |
| Removido pelo mestre | Mesmo caminho do item acima. |

## Testes

**Automatizados** (rodam no container, sem rede):

- `codigo.dart`: formato, alfabeto sem ambíguos, validação de entrada digitada.
- Presença: `visto` vira online/offline nos limites de 90s.
- `MesaFake`: criar, entrar por código, listar membros, sair, remover, fechar.
- Telas da aba Mesa contra o fake: estados sem mesa, como jogador e como mestre.
- Espelho: `FichaStore.salvar` dispara uma escrita por janela de 2s (agrupamento).
- Mural: imagem grande é reencodada antes de enviar; a que cabe passa direto.

**Não automatizados, e é uma limitação assumida:** as regras de segurança só se
testam com o emulador do Firebase, que não está no container deste projeto. As
regras serão escritas junto com um roteiro de verificação manual — entrar com
dois aparelhos, tentar ler a ficha do outro, confirmar a recusa.

## O que só você pode fazer

Criar o projeto no Firebase exige login na sua conta Google. Passo a passo na
implementação; em resumo: criar o projeto, habilitar Authentication anônimo e
Firestore, e rodar `flutterfire configure` registrando **os dois canais**
(`com.kodem.mago_a_ascensao` e `com.kodem.mago_a_ascensao.beta`), que gera o
`firebase_options.dart`.

O arquivo gerado não é segredo (chaves de cliente Firebase são públicas por
desenho; quem protege é a regra de segurança), então pode ser versionado.

## Custo

Mesa de 6 pessoas, sessão de 4 horas: na ordem de alguns milhares de leituras e
centenas de escritas. O plano gratuito do Firestore dá 50 mil leituras e 20 mil
escritas por dia. Dobrar a mesa não muda a conclusão.

## Riscos

**Criar mesa não é atômico.** São duas escritas: a mesa e depois o código. Se a
segunda falhar, sobra uma mesa sem código — invisível para quem quer entrar. O
app trata isso repetindo a gravação do código ao abrir a mesa sem código, e o
mestre sempre pode gerar um novo.

**Colisão de código.** 8 caracteres num alfabeto de 32 dão espaço de sobra, mas
a criação verifica se já existe antes de gravar e tenta de novo.

**Aparelho perdido.** Quem tem o aparelho tem a identidade — não há senha. Para
uma mesa de amigos é aceitável; está registrado aqui como escolha consciente.

**A ficha trafega inteira.** História, retrato, tudo. É o que o mestre precisa
ver em jogo, e é o mesmo JSON que hoje vocês trocam por WhatsApp.
