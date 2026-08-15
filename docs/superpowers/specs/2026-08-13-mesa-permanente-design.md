# Mesa online · Fase 4 — Mesa permanente e galeria da crônica

**Problema.** A mesa já sobrevive no Firestore, mas o mural guarda uma imagem
só: pôr a segunda apaga a primeira. Numa crônica que joga todo sábado, o mapa
mostrado na primeira sessão não existe mais na quinta. E "Fechar mesa" é um
botão único que apaga tudo para sempre — o oposto de permanente.

**Objetivo.** A mesa dura enquanto o mestre quiser, e tudo que ele mostrou
continua lá: acervo da crônica, não da sessão.

## Decisões

| Assunto | Decisão |
|---|---|
| Imagens antigas | Acumulam numa galeria da mesa; nada é sobrescrito |
| Abrir na tela de todos | Escolha do mestre a cada envio: *Guardar na galeria* ou *Mostrar agora* |
| Volume esperado | Dezenas de imagens (~50) por mesa |
| Fim de sessão | *Encerrar sessão* (mesa continua) separado de *Apagar mesa* (destrutivo) |
| Voltar na semana seguinte | O aparelho lembra as mesas conhecidas; volta com um toque |
| Identidade do mestre | Chave de recuperação. Sem login com Google |
| Armazenamento | Firestore em base64, miniatura separada. Sem Firebase Storage (exige plano pago) |

## Dados

```
mesas/{mesaId}
  nome, codigo, mestreUid, criadaEm

mesas/{mesaId}/galeria/{imagemId}     leve   (~10 KB)
  legenda, porUid, em, miniatura(base64 ~200px q60)

mesas/{mesaId}/imagens/{imagemId}     pesado (~300 KB)
  imagem(base64, até 1024px q80)

mesas/{mesaId}/mural/atual            ponteiro
  imagemId, em

mesas/{mesaId}/privado/chave          ilegível pelo cliente
  chave

mesas/{mesaId}/privado/pedido         ilegível pelo cliente
  chave, uid
```

**Por que dois documentos por imagem.** Abrir a galeria com tudo junto baixaria
50 × 300 KB = 15 MB por vez; com seis pessoas, a cota gratuita de 10 GiB/mês
acaba em semanas. Lendo só as miniaturas são ~500 KB — trinta vezes menos. A
imagem grande é buscada apenas quando alguém a abre.

**`mural/atual` deixa de carregar a imagem** e passa a apontar para um
`imagemId`. É o que dispara a abertura em tela cheia nos outros aparelhos.

## Regras de segurança

```
match /mesas/{mesaId} {
  allow update: if souMestre(mesaId) || reassumindoComChave(mesaId);
}

match /mesas/{mesaId}/galeria/{img}  { read: membro; write: mestre }
match /mesas/{mesaId}/imagens/{img}  { read: membro; write: mestre }
match /mesas/{mesaId}/privado/chave  { read: nunca; create: mestre; update/delete: nunca }
match /mesas/{mesaId}/privado/pedido { read: nunca; create/update: logado }
```

`reassumindoComChave` exige, ao mesmo tempo: que o único campo alterado seja
`mestreUid`, que o novo valor seja o próprio uid, e que o `pedido` gravado por
esse uid traga a mesma chave do documento `chave`. As regras leem os dois
documentos com `get()`; o cliente nunca consegue lê-los.

Chave de 8 caracteres no alfabeto de 22 do código da mesa: ~5,4 × 10¹⁰
combinações, duas escritas por tentativa. Força bruta não é ameaça real.

**Quem tem a chave é o mestre** — o peso é o de uma senha, e a tela que a
mostra diz isso.

## Telas

**Galeria da mesa** (aba Mesa, todos veem). Grade de miniaturas, mais recente
primeiro, legenda embaixo. Tocar abre em tela cheia — só então a imagem grande
é baixada — com o modo mostrar que já existe. Para o mestre, cada item tem
*Mostrar agora* e *Apagar*.

**Pôr imagem** (mestre). Escolhe o arquivo, escreve a legenda, decide entre
*Guardar na galeria* e *Mostrar agora*. Miniatura e imagem grande são geradas no
aparelho; indicador de progresso enquanto sobe.

**Encerrar sessão** (mestre). Tira todos da lista de membros — o mestre
inclusive — e retira as fichas publicadas. Mesa, código, chave e galeria
continuam. Todo mundo volta para a tela de fora de mesa, com a mesa presente na
lista de mesas conhecidas.

Entrar pela lista de mesas conhecidas segue a mesma ordem que entrar por código:
**cria o registro de membro antes de ler a mesa**. A regra só libera a leitura
para quem já é membro, e depois de encerrada a sessão ninguém é.

**Apagar mesa** (mestre). Atrás do menu ⋮, confirmando com o nome da mesa
digitado. Apaga tudo, inclusive a galeria.

**Minhas mesas.** Cada aparelho guarda as mesas em que já entrou (id, nome,
papel, chave quando é o mestre). Fora de mesa, a aba lista "Sombras de SP —
entrar" e um toque volta, sem código. Sair não remove da lista; só *Esquecer
esta mesa* remove.

**Recuperar mesa.** Na tela de entrar, "já sou o mestre desta mesa": digita
código e chave. Certo, volta a ser mestre com a galeria intacta; errado, "Chave
não confere."

**Mudança de comportamento.** Hoje, quando a mesa some, o app avisa "o mestre
encerrou a mesa" e joga para fora. Agora são dois casos distintos: *sessão
encerrada* (a mesa continua na lista de mesas conhecidas) e *mesa apagada* (sai
da lista).

## Erros

- Apagar imagem: apaga o documento pesado primeiro, o leve depois. Se o segundo
  falhar, o item continua na galeria — nunca sobra imagem grande órfã.
- Subir imagem: a entrada da galeria só é criada depois que a imagem grande
  está gravada. Nada de item pela metade.
- Miniatura corrompida vira ícone quebrado; não derruba a tela.
- Sem internet: a aba avisa e oferece tentar de novo; o resto do app segue
  offline igual.

## Testes

**Automatizados.** O `MesaFake` ganha galeria, mural por ponteiro e chave,
espelhando o Firestore como nas outras fases: acumular sem sobrescrever, apagar,
*Mostrar agora*, encerrar sessão (mesa sobrevive) contra apagar mesa (some
tudo), recuperação com chave certa e errada. Telas: galeria com miniaturas,
jogador sem os botões do mestre, *Mostrar agora* abrindo no aparelho dos outros,
lista de mesas conhecidas sobrevivendo a sair da mesa.

**Manuais** (regras de segurança só se testam de verdade no console): jogador
tentando escrever na galeria, jogador tentando trocar o `mestreUid` sem a chave,
e o teste que resume a fase — pôr imagem, encerrar sessão, fechar o app, voltar
no sábado seguinte e a imagem continuar lá.

## Fora de escopo

- Login com Google (a chave de recuperação resolve o caso desta mesa).
- Álbuns, marcação por sessão ou busca na galeria: dezenas de imagens cabem numa
  grade simples. Revisitar se virar centenas.
- Jogador pôr imagem na galeria.
