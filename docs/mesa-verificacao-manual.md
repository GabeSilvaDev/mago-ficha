# Mesa online — verificação manual

As regras de segurança do Firestore só se testam de verdade com o emulador do
Firebase, que exige Node e Java — o container deste projeto só tem o SDK do
Flutter. Em vez de fingir cobertura automatizada, esta lista é executada à mão.

**Como rodar:** instale o canal `beta` em dois aparelhos (ou um aparelho e o
PWA numa aba anônima):

```bash
docker exec mago-ascensao-flutter sh -c "cd /app && flutter build apk --release --flavor beta"
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

## Simulador de regras

Console do Firebase → **Firestore Database** → aba **Regras** → **Simulador**.
Escolha a operação, o caminho (`/mesas/<id>`) e marque *Autenticado* com o uid
que quer testar. O uid aparece no console em **Authentication → Usuários**.

## Fases 2 e 3

Os itens de ficha espelhada e mural entram aqui quando essas fases forem
implementadas — ver os planos em `docs/superpowers/plans/`.
