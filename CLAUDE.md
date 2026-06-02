# Vem Pro Parque — Flutter App

## Stack
- Flutter 3 + Dart, Provider (sem Riverpod), GoRouter
- Design system: verde `#669340`, fonte Poppins, Material 3
- ApiClient centralizado: `lib/core/api/api_client.dart`
- Backend base URL: `https://apps.sitw.com.br/backend-park/api/v1`

## Projetos relacionados
- **Backend Go** — `/Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK`
- **Admin Panel React** — `/Users/sitwcomunicacaoemarketing/Desktop/PAINEL-PARK`

## Estrutura de pastas relevante
```
lib/
  core/api/          — ApiClient e ApiConfig
  data/
    models/          — Park, Review, Space, Reservation, Participant, AppEvent
    repositories/    — go_park_repository, go_reviews_repository, go_reservation_repository, etc.
  screens/
    user/            — login, cadastro, perfil, senha, preferências, user_entry_screen
    reservations/    — park_selection, spaces_catalog, space_detail, booking_calendar,
                       reservation_form, my_reservations
  services/          — auth, favorites, parks, notification_service (FCM), run_tracker
  widgets/           — app_toast, favorite_button, login_required
  routes/            — app_router (bottom bar com pill deslizante)
docs/
  superpowers/specs/ — specs de design aprovadas
```

## Arquitetura de autenticação
- `UserEntryScreen` é a raiz da aba "Usuário" — usa `Consumer<AuthService>` para alternar entre `LoginScreen` e `UserScreen` automaticamente
- `LoginScreen` tem dois modos: (1) dentro de `UserEntryScreen` — `onLogged` callback; (2) via rota GoRouter — após login faz `context.go('/tabs/user')`
- Guard no botão Reservas: usuário não logado é redirecionado para `/tabs/user/login`

## Estado atual do sistema de reservas (implementado)
- Fluxo: Home → seleção de parque → espaços → calendário (semana atual) → formulário → "Minhas reservas"
- Regras: 1 reserva ativa por CPF, duração fixa 2h, aprovação pelo gestor
- Rejeição: gestor informa motivo (obrigatório) → usuário tem 2h para editar e reenviar
- Cancelamento: usuário pode cancelar Pendente/Aprovada antes do dia da reserva
- Push FCM: graceful degradation (funciona sem config Firebase; ativa ao plugar credenciais)
- `Space` é a única entidade para lugares físicos (unificou map_points + spaces)

## Pendências que dependem de ação humana
1. **Firebase**: criar projeto e adicionar `google-services.json` (Android), `GoogleService-Info.plist` (iOS), `FIREBASE_CREDENTIALS_JSON` (env backend) para ativar push notifications
2. **PAINEL-PARK**: não está no git — arquivos salvos localmente mas sem versionamento

## Componentes globais importantes
- `AppToast` (`lib/widgets/app_toast.dart`) — toast estilo Duolingo, usar em vez de SnackBar
- `FavoriteButton` (`lib/widgets/favorite_button.dart`) — animação Lottie
- `LoginRequired` (`lib/widgets/login_required.dart`) — guard para telas protegidas
- Bottom bar com pill deslizante — implementada em `lib/routes/app_router.dart`

---

## Histórico de mudanças

### 2026-06-02 (fix: login não navegava após sucesso)
- `LoginScreen` acessada via rota GoRouter ficava parada após login (onLogged era null)
- Fix: quando `onLogged == null`, faz `context.go('/tabs/user')` → `UserEntryScreen` detecta o auth e exibe `UserScreen`

### 2026-06-02 (fix/feat: 5 melhorias críticas no sistema de reservas)
- **Bug corrigido: reset semanal não expira mais reservas Aprovadas**
  - Pendentes de semanas anteriores → Expirada; Aprovadas só expiram após a data da reserva
- **Usuário pode cancelar a própria reserva** (status Pendente ou Aprovada, antes do dia)
  - Backend: `POST /reservations/:id/cancel` → status `Cancelada`
  - Flutter: botão "Cancelar reserva" em `MyReservationsScreen` com confirmação
- **Conflito de slot verificado no reenvio** — se outro usuário tomou o horário durante a janela de 2h, o reenvio é bloqueado com mensagem clara
- **Badge de pendentes na sidebar do admin** — contador âmbar atualiza a cada 30s
- **Slots passados filtrados no calendário** — quando a data selecionada é hoje, horários já decorridos não aparecem
- **SpaceRule não duplica mais** — upsert preserva o ID existente

### 2026-06-02 (feat: motivo de rejeição obrigatório)
- **Gestor deve informar o motivo ao rejeitar uma reserva**
  - Backend: campo `motivo_rejeicao` na Reservation; `AdminUpdateStatus` retorna 400 se vazio
  - Admin: clicar "Rejeitar" abre modal com textarea — "Confirmar" só habilita com texto preenchido
  - Push FCM: motivo incluído na mensagem de notificação
  - Flutter: motivo exibido no banner de edição (`ReservationFormScreen`) e no card rejeitado (`MyReservationsScreen`)
  - Motivo limpo automaticamente quando usuário reenvia a reserva

### 2026-06-02 (refactor: unificação MapPoint + Space)
- **`Space` agora é a única fonte de verdade para lugares físicos** (refactor de arquitetura)
  - Campo `exibir_no_mapa bool` + `lat/lng` + `categoria_mapa` adicionados ao Space
  - O endpoint `/map-points` virou adaptador sobre Space (Flutter não mudou nada)
  - `MapPointUseCase` reescrito — gerencia Spaces com flag de mapa, sem bridge hack
  - Migration automática no boot: copia `map_points` → `spaces` (idempotente)
  - Admin: formulário de ponto ganhou toggles separados "Exibir no mapa" e "Permite reserva"
  - Campos `pode_reservar`/`space_id` removidos do MapPoint legacy
  - Backend: `go build` ✅ · Admin: `tsc --noEmit` ✅

### 2026-06-02 (fix: pontos de interesse → reservas)
- **MapPoint conectado ao sistema de reservas**
  - Backend: adicionado `pode_reservar bool` e `space_id *uint` ao MapPoint
  - Quando `pode_reservar=true`, o backend auto-cria/sincroniza um `Space` + `SpaceRule` vinculado
  - Espaço criado passa a aparecer no catálogo de reservas do app automaticamente
  - Admin: formulário de ponto de interesse virou **página inteira** (rota `/pontos-de-interesse/novo` e `/:id/editar`)
  - Formulário tem toggle "Permite reserva" que revela campos de capacidade, horários e dias de funcionamento
  - Tabela de pontos ganhou coluna "Reserva" mostrando se o ponto aceita agendamento

### 2026-06-02 (implementação)
- **Sistema de Agendamento implementado** nos 3 projetos (branch `feat/reservations-redesign`)
  - **Backend Go** (`PARQUE-BACK`): entidade Reservation expandida (CPF, participantes JSON,
    rejected_at, week_of, status Pendente/Aprovada/Rejeitada/Expirada), ReservationUseCase
    com todas as regras, endpoints `POST/PUT /reservations`, `GET /me/reservations`,
    `GET/PUT /admin/reservations`, `POST /me/fcm-token`, jobs de expiração (ticker 5min),
    slots de disponibilidade em blocos de 2h. `go build` ✅
  - **FCM**: serviço de push com **graceful degradation** — backend e app funcionam sem
    as credenciais Firebase; push ativa ao plugar config (ver pendências abaixo).
  - **Flutter** (`PARQUE`): ParkSelectionScreen, SpacesCatalog com parkId, BookingCalendar
    refatorado (semana atual), ReservationFormScreen (participantes nome+CPF com máscara,
    termos, modo edição com countdown 2h), MyReservationsScreen no perfil, guard de auth
    no botão Reservas, NotificationService defensivo. `flutter analyze` limpo nos arquivos novos ✅
  - **Admin React** (`PAINEL-PARK`): ReservationsManagement reescrita para o contrato real,
    Aprovar/Rejeitar/Cancelar via `PUT /admin/reservations/:id`, modal de participantes,
    filtros por status/parque. `tsc --noEmit` ✅
  - ⚠️ **PENDÊNCIAS (humano):** (1) criar projeto Firebase e adicionar `google-services.json`,
    `GoogleService-Info.plist` e `FIREBASE_CREDENTIALS_JSON` (env do backend) para ativar push;
    (2) `PAINEL-PARK` não é repositório git — arquivos salvos mas não versionados.

### 2026-06-02
- **Spec criada: Redesign do Sistema de Agendamento** (`docs/superpowers/specs/2026-06-02-reservations-redesign.md`)
  - Entrada via "Reservas" na Home → lista de parques → espaços → calendário → formulário
  - Guard de autenticação no botão Reservas (não logado = bloqueado)
  - Semana dom–sáb com reset todo domingo às 6h
  - 1 reserva ativa por CPF em todo o app
  - Participantes obrigatórios: nome + CPF de cada um
  - Duração fixa de 2h por reserva
  - Admin aprova/rejeita no painel → push FCM ao usuário
  - Rejeição: usuário tem 2h para editar e reenviar, depois disso slot expira automaticamente
  - "Minhas reservas" no perfil com badges de status e contador regressivo
  - FCM configurado do zero (firebase_messaging)
  - Status: **spec aprovada — implementação pendente**

### 2026-06-01
- **Spec criada: Review Draft Mode** (`docs/superpowers/specs/2026-06-01-review-draft-mode-design.md`)
  - Reviews entram como `Pendente` no backend; só `Aprovadas` aparecem publicamente
  - App mescla endpoint público + `/mine` e exibe badge por status (só pro autor)
  - Painel admin ganha botões Aprovar / Rejeitar / Ocultar
  - Upload de foto na avaliação via `POST /reviews/media`
  - Validação de unicidade: 409 se usuário já tem review para o parque
  - Status: **spec aprovada — implementação pendente**

---

<!-- Adicionar novas entradas no topo do Histórico, formato:
### YYYY-MM-DD
- **O que mudou:** descrição curta
  - detalhe 1
  - detalhe 2
  - Status: implementado | spec aprovada | em progresso | revertido
-->
