# Mesa online — verificação manual

As regras de segurança do Firestore só se testam de verdade com o emulador do
Firebase, que exige Node e Java — o container deste projeto só tem o SDK do
Flutter. Em vez de fingir cobertura automatizada, esta lista é executada à mão.

**Como rodar:** instale o canal `beta` em dois aparelhos (ou um aparelho e o
PWA numa aba anônima):

O `--dart-define=CANAL=beta` faz o app se identificar como o registro beta no
console do Firebase (ver `lib/firebase_options.dart`).

**Antes de gerar um APK que vai para o celular, rode `flutter clean`.** O
Gradle já entregou um `app-beta-release.apk` novo por fora com o `libapp.so`
de um build anterior — o app abria sem a aba Mesa e nada no log acusava. O
sintoma é o build do Gradle terminar rápido demais (~50s em vez de ~100s).
Para conferir sem instalar:

```bash
unzip -p build/app/outputs/flutter-apk/app-beta-release.apk lib/arm64-v8a/libapp.so \
  | strings -a | grep -c 'Criar mesa'   # 0 = APK velho
```

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter clean && flutter pub get"
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta --dart-define=CANAL=beta"
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb \
  -v /home/gabriel/Documentos/rpg/fichas/MagoAAssencao:/app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "adb install -r /app/build/app/outputs/flutter-apk/app-beta-release.apk"
```

Chame de **A** o mestre e **B** o jogador. Marque o resultado ao lado.

## Fase 1 — mesa e identidade

| # | O quê | Esperado | OK? |
|---|---|---|---|
| 1 | A cria a mesa; B entra com o código | B aparece na lista de A como *jogador*; A aparece como *mestre* | |
| 2 | B fecha o app e espera | em até 90s a bolinha de B fica cinza na tela de A | |
| 3 | A troca o código; um terceiro tenta o antigo | "Não encontrei essa mesa." | |
| 4 | A remove B | B volta sozinho para a tela "não está em nenhuma mesa" | |
| 5 | A fecha a mesa | B recebe "O mestre encerrou a mesa." | |
| 6 | B tenta editar a mesa (simulador de regras do console, uid de B, `update` em `mesas/{id}`) | **negado** | |
| 7 | Alguém que não é membro tenta `get` em `mesas/{id}` (simulador) | **negado** | |
| 8 | A está na mesa; desligar o wifi, mexer no app, religar | a lista volta a atualizar sem reiniciar o app | |
| 9 | Ninguém entra em mesa nenhuma; usar o app normalmente sem internet | tudo funciona: criar ficha, PDF, backup | |

O item 9 é o mais importante: é a promessa de que o app continua offline para
quem não usa mesa.

## Fase 2 — ficha espelhada

| # | O quê | Esperado | OK? |
|---|---|---|---|
| 10 | B publica a ficha na aba Mesa | ela aparece no painel de A com Arete, FdV e vitalidade | |
| 11 | B marca dano | em poucos segundos o nível muda na tela de A, sem A tocar em nada | |
| 12 | C (outro jogador) entra e publica a ficha dele | C **não** vê a ficha de B em lugar nenhum | |
| 13 | A abre a ficha de B | sem lápis de editar; os `+`/`−` não respondem | |
| 14 | B sai da mesa | a ficha some do painel de A; no aparelho de B o dano continua marcado | |
| 15 | A fecha a mesa com fichas publicadas | some tudo; ninguém fica com cópia órfã no Firestore | |

## Fase 3 — mural de imagens

| # | O quê | Esperado | OK? |
|---|---|---|---|
| 16 | A põe uma foto no mural | em segundos ela abre em tela cheia no aparelho de B | |
| 17 | B toca na imagem | o modo mostrar funciona igual ao do caderno | |
| 18 | A escolhe uma foto direto da câmera (vários MB) | o app reduz e envia sem erro, com indicador enquanto sobe | |
| 19 | A tira do mural | B fecha a tela e ela não reabre sozinha | |
| 19b | B fecha a imagem e volta na aba Mesa | a miniatura continua lá; *Ver em tela cheia* reabre quantas vezes quiser | |
| 20 | B fecha a imagem e alguém entra na mesa | a imagem **não** reabre: só o que é novo abre | |
| 21 | B tenta `set` em `mesas/{id}/mural/atual` (simulador de regras) | **negado** | |
| 22 | A fecha a mesa com imagem no mural | o mural some junto, sem documento órfão | |

## Simulador de regras

Console do Firebase → **Firestore Database** → aba **Regras** → **Simulador**.
Escolha a operação, o caminho (`/mesas/<id>`) e marque *Autenticado* com o uid
que quer testar. O uid aparece no console em **Authentication → Usuários**.

## Fases 2 e 3

Os itens de ficha espelhada e mural entram aqui quando essas fases forem
implementadas — ver os planos em `docs/superpowers/plans/`.
