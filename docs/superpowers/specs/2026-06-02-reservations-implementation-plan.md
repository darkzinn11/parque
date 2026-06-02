# Plano de Implementação — Sistema de Agendamento
**Spec:** `2026-06-02-reservations-redesign.md`  
**Ordem:** Backend → Flutter → Admin Panel

---

## Fase 1 — Backend Go (`PARQUE-BACK`)

### 1.1 — Entidades e migration
- Adicionar struct `Reservation` em `internal/domain/entities/collections.go`
  - Campos: ID, SpaceID, UserID, CPF, Data, HoraInicio, HoraFim, Status, RejectedAt, WeekOf, Participants (JSON), CreatedAt, UpdatedAt
- Adicionar struct `FCMToken` no mesmo arquivo
  - Campos: UserID (PK), Token, Platform, UpdatedAt
- Registrar ambas no AutoMigrate em `cmd/api/main.go`
- Rodar migration de dados: reservas existentes recebem `status = 'Aprovada'` e `week_of` calculado

### 1.2 — Repositório de reservas
- Criar interface `ReservationRepository` em `internal/domain/repositories/reservation_repository.go`
  - `Create(ctx, reservation) error`
  - `GetByID(ctx, id) (*Reservation, error)`
  - `GetActiveByUserCPF(ctx, cpf) (*Reservation, error)` — busca Pendente ou Aprovada
  - `GetBySpaceAndSlot(ctx, spaceID, data, horaInicio) (*Reservation, error)` — verifica conflito
  - `ListByUserID(ctx, userID) ([]Reservation, error)`
  - `ListAll(ctx, filters) ([]Reservation, error)` — para admin
  - `UpdateStatus(ctx, id, status, rejectedAt) error`
  - `UpdateParticipantsAndStatus(ctx, id, participants, status) error` — reenvio
  - `ExpireRejected(ctx, before time.Time) error` — cron
  - `ExpireWeekly(ctx, weekBefore time.Time) error` — cron

### 1.3 — Repositório de FCMToken
- Criar interface `FCMTokenRepository`
  - `Upsert(ctx, userID, token, platform) error`
  - `GetByUserID(ctx, userID) (*FCMToken, error)`
- Implementar em `internal/infrastructure/persistence/mysql_fcm_token_repository.go`

### 1.4 — Implementação MySQL do repositório de reservas
- Criar `internal/infrastructure/persistence/mysql_reservation_repository.go`
- Implementar todos os métodos da interface

### 1.5 — Serviço de notificações FCM
- Criar `internal/infrastructure/notifications/fcm_service.go`
- Usar Firebase Admin SDK (`firebase.google.com/go/v4`)
- Método `SendToUser(ctx, userID, title, body, data map[string]string) error`
  - Busca token do usuário via `FCMTokenRepository`
  - Envia via `messaging.Client.Send()`
- Adicionar credenciais Firebase ao `.env` (`FIREBASE_CREDENTIALS_JSON`)

### 1.6 — Use case de reservas
- Criar `internal/application/usecases/reservation_usecase.go`
- Método `CreateReservation(ctx, req)`:
  1. Valida que `data` está na semana atual (dom–sáb, reset dom às 6h)
  2. Valida que usuário tem CPF
  3. Verifica reserva ativa pelo CPF → 409 se existir
  4. Verifica conflito de slot → 409 se ocupado
  5. Calcula `hora_fim = hora_inicio + 2h` e `week_of`
  6. Salva com `status = "Pendente"`
- Método `ResubmitReservation(ctx, id, userID, participants)`:
  1. Busca reserva, valida owner
  2. Valida `status = "Rejeitada"`
  3. Valida `rejected_at + 2h > now()`
  4. Atualiza participantes, volta status para `"Pendente"`, limpa `rejected_at`
- Método `AdminUpdateStatus(ctx, id, status)`:
  1. Atualiza status
  2. Se `"Rejeitada"`: preenche `rejected_at = now()`
  3. Dispara FCM para o usuário

### 1.7 — Handlers HTTP
- Criar `internal/infrastructure/http/handlers/reservation_handler.go`
  - `POST /reservations` — CreateReservation
  - `PUT /reservations/:id` — ResubmitReservation
  - `GET /me/reservations` — ListByUser
  - `GET /reservations/:id` — GetByID
  - `GET /admin/reservations` — ListAll (com filtros: status, park_id, data)
  - `PUT /admin/reservations/:id` — AdminUpdateStatus
- Criar `internal/infrastructure/http/handlers/fcm_handler.go`
  - `POST /me/fcm-token` — Upsert token

### 1.8 — Registrar rotas em `cmd/api/main.go`
- Adicionar todas as rotas do passo 1.7 nos grupos corretos (user auth / admin auth)

### 1.9 — Jobs automáticos
- Criar `internal/infrastructure/jobs/expiry_job.go`
  - Roda a cada 5 minutos
  - Chama `ReservationRepository.ExpireRejected(ctx, now()-2h)`
- Criar `internal/infrastructure/jobs/weekly_reset_job.go`
  - Roda todo domingo às 6h
  - Chama `ReservationRepository.ExpireWeekly(ctx, domingo_atual)`
- Inicializar ambos os crons em `cmd/api/main.go` usando `robfig/cron` ou `gocron`

### 1.10 — Atualizar endpoint de disponibilidade
- `GET /spaces/:id/disponibilidade` já existe
- Garantir que slots de reservas com status `Pendente` ou `Aprovada` também aparecem como indisponíveis (não só `Aprovada`)

---

## Fase 2 — Flutter App (`PARQUE`)

### 2.1 — Dependências Firebase
- Adicionar ao `pubspec.yaml`:
  - `firebase_core`
  - `firebase_messaging`
- Configurar `google-services.json` em `android/app/`
- Configurar `GoogleService-Info.plist` em `ios/Runner/`
- Inicializar Firebase em `lib/main.dart`

### 2.2 — Models
- Criar `lib/data/models/reservation.dart`
  - Class `Reservation` com todos os campos da spec
  - Class `Participant` com `nome` e `cpf`
  - `Reservation.fromJson()` e `toJson()`
  - Helper `timeRemainingForResubmit` → `Duration?` (nulo se expirado)

### 2.3 — Repositório de reservas
- Criar `lib/data/repositories/reservation_repository.dart` (interface abstrata)
  - `createReservation({spaceId, data, horaInicio, horaFim, participants}) → Map`
  - `resubmitReservation({id, participants}) → Map`
  - `fetchMyReservations() → List<Reservation>`
  - `fetchReservationById(id) → Reservation?`
- Criar `lib/data/repositories/go_reservation_repository.dart` (implementação)
  - Usa `ApiClient` — endpoints da Fase 1

### 2.4 — Serviço de notificações
- Criar `lib/services/notification_service.dart`
  - `initialize()` — setup FCM, request permission
  - `_saveTokenToBackend(token)` — chama `POST /me/fcm-token`
  - `handleForegroundMessage(message)` — exibe `AppToast`
  - `handleBackgroundTap(message)` — navega via GoRouter para o deep link
- Chamar `NotificationService.initialize()` em `lib/main.dart` após login

### 2.5 — `ParkSelectionScreen` (nova)
- Criar `lib/screens/reservations/park_selection_screen.dart`
- Busca parques via `ParksService` ou endpoint dedicado (parques com espaços ativos)
- Lista de cards: foto do parque, nome, quantidade de espaços
- Toque → navega para `/tabs/home/reservas/:parkId/espacos`

### 2.6 — Atualizar rotas no GoRouter
- Abrir `lib/routes/app_router.dart`
- Adicionar rotas:
  - `/tabs/home/reservas` → `ParkSelectionScreen`
  - `/tabs/home/reservas/:parkId/espacos` → `SpacesCatalogScreen`
  - `/tabs/home/reservas/:parkId/espacos/:spaceId` → `SpaceDetailScreen`
  - `/tabs/home/reservas/:parkId/espacos/:spaceId/agendar` → `BookingCalendarScreen`
  - `/tabs/home/reservas/:parkId/espacos/:spaceId/formulario` → `ReservationFormScreen`
  - `/tabs/usuario/minhas-reservas` → `MyReservationsScreen`
  - `/tabs/usuario/minhas-reservas/:id/editar` → `ReservationFormScreen` (modo edição)

### 2.7 — Guard de autenticação na Home
- Abrir `lib/screens/home_screen.dart`
- No botão "Reservas": checar `AuthService.isLoggedIn`
  - Não logado → exibir `LoginRequiredWidget` ou navegar para login
  - Logado → navegar para `/tabs/home/reservas`

### 2.8 — Atualizar `SpacesCatalogScreen`
- Aceitar `parkId` como parâmetro obrigatório via rota
- Passar `parkId` para `SpaceRepository.fetchSpaces(parkId: parkId)`
- Manter filtro de categoria funcionando dentro do parque selecionado

### 2.9 — Refatorar `BookingCalendarScreen`
- Alterar `_generateDates()`:
  - Calcular domingo da semana atual (com regra do reset às 6h)
  - Retornar apenas dias de hoje até o sábado da semana atual
- Remover lógica de `_submitBooking()`, `_agreeTerms` e checkbox de termos
- Trocar botão "Confirmar Agendamento" por "Continuar"
- Ao tocar "Continuar": navegar para `ReservationFormScreen` passando `{spaceId, data, horaInicio, horaFim}`

### 2.10 — `ReservationFormScreen` (nova)
- Criar `lib/screens/reservations/reservation_form_screen.dart`
- Aceita parâmetros: `spaceId`, `data`, `horaInicio`, `horaFim`, e opcionalmente `reservationId` (modo edição)
- Seção 1: resumo somente leitura (espaço, parque, data/hora)
- Seção 2: responsável somente leitura (nome + CPF do perfil via `AuthService`)
- Seção 3: lista dinâmica de participantes
  - Botão "+ Adicionar participante"
  - Campo nome (TextFormField)
  - Campo CPF com máscara (`flutter_masked_text2` ou implementação manual)
  - Botão × para remover
  - Validação: CPF com formato válido, máximo `capacidade_max - 1`
- Seção 4: termos de uso (box scrollável) + checkbox
- Botão "Enviar solicitação" / "Reenviar solicitação" (modo edição)
- Modo edição: banner vermelho + contador regressivo + dados pré-preenchidos
- Handlers de resposta da API (sucesso, 409 CPF, 409 slot)

### 2.11 — `MyReservationsScreen` (nova)
- Criar `lib/screens/reservations/my_reservations_screen.dart`
- Busca `GoReservationRepository.fetchMyReservations()`
- Cards expansíveis com badge de status
- Lógica de countdown: `Timer.periodic` para atualizar contador a cada segundo quando há reserva rejeitada dentro de 2h
- Botão "Editar e reenviar" navega para `ReservationFormScreen` em modo edição
- Pull-to-refresh

### 2.12 — Link "Minhas reservas" no perfil
- Abrir `lib/screens/user/user_screen.dart`
- O item "Minhas reservas" já existe na UI — conectar ao `GoRouter.push('/tabs/usuario/minhas-reservas')`

---

## Fase 3 — Admin Panel React (`PAINEL-PARK`)

### 3.1 — Serviço de API para reservas
- Criar `src/services/reservationsService.ts`
  - `getReservations(filters)` → `GET /admin/reservations`
  - `updateReservationStatus(id, status)` → `PUT /admin/reservations/:id`

### 3.2 — Página `ReservationsManagement`
- Criar `src/pages/ReservationsManagement/ReservationsManagement.tsx`
- Tabela com colunas: Usuário, CPF, Parque, Espaço, Data/Hora, Participantes, Status, Ações
- Filtros: por status (select), por parque (select), por data (date input)
- Ordenação padrão: Pendentes primeiro
- Botões por status:
  - `Pendente` → Aprovar (verde) + Rejeitar (vermelho)
  - `Aprovada` → Cancelar (cinza)
- Modal de participantes: abre ao clicar em "N pessoas", lista nome + CPF
- Mutations com TanStack Query + invalidação de `['reservations']`

### 3.3 — Registrar rota e sidebar
- Adicionar rota `/reservas` no router do admin
- Adicionar item "Reservas" na sidebar com ícone de calendário
- Adicionar badge de contador de pendentes na sidebar (query separada)

---

## Ordem de entrega sugerida

```
1.1 → 1.2 → 1.3 → 1.4   (modelos e repositórios)
1.5                        (FCM service — pode ser paralelo)
1.6 → 1.7 → 1.8           (use case + handlers + rotas)
1.9 → 1.10                 (jobs + fix disponibilidade)

2.1 → 2.2 → 2.3 → 2.4    (base Flutter — deps, models, repositório, notif)
2.5 → 2.6 → 2.7 → 2.8    (navegação e entry points)
2.9 → 2.10 → 2.11 → 2.12 (telas)

3.1 → 3.2 → 3.3           (admin panel)
```
