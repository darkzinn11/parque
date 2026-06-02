# Sistema de Agendamento de Espaços — Design Spec
**Data:** 2026-06-02  
**Status:** Aprovado

---

## Contexto

O agendamento de espaços nos parques do Governo do Maranhão hoje ocorre presencialmente ou via WhatsApp. O app Vem Pro Parque digitaliza esse processo para os 15 parques estaduais, com regras baseadas nos fluxos do Itapiracó, Rangedor e Lagoa da Jansen.

---

## Regras de negócio

| Regra | Detalhe |
|-------|---------|
| Janela de agendamento | Semana atual (domingo a sábado). Reseta todo domingo às 6h |
| Limite por CPF | 1 reserva ativa por CPF em todo o app (status Pendente ou Aprovada) |
| Duração fixa | Toda reserva = 2 horas |
| Participantes | Obrigatório informar nome + CPF de cada participante |
| Fluxo de aprovação | Toda reserva vai para "Pendente" → gestor aprova ou rejeita |
| Rejeição | Usuário tem 2h para editar e reenviar. Após 2h sem ação → slot reabre automaticamente |
| Autenticação | Somente usuários logados podem iniciar o fluxo de reserva |
| Notificações | Push FCM ao aprovar e ao rejeitar |

---

## Seção 1 — Navegação

### Fluxo principal (entrada via Home)

```
Home → botão "Reservas"
  │
  ├─ [Não logado] → LoginRequiredWidget (bloqueia o fluxo)
  │
  └─ [Logado] → ParkSelectionScreen
                  └─► SpacesCatalogScreen (filtrada por parkId)
                        └─► SpaceDetailScreen
                              └─► BookingCalendarScreen
                                    └─► ReservationFormScreen
```

### Fluxo de acompanhamento (entrada via Perfil)

```
UserScreen → "Minhas reservas"
  └─► MyReservationsScreen
        └─► [Rejeitada dentro de 2h] → ReservationFormScreen (modo edição)
```

### Rotas GoRouter

```
/tabs/home/reservas                                           → ParkSelectionScreen
/tabs/home/reservas/:parkId/espacos                           → SpacesCatalogScreen
/tabs/home/reservas/:parkId/espacos/:spaceId                  → SpaceDetailScreen
/tabs/home/reservas/:parkId/espacos/:spaceId/agendar          → BookingCalendarScreen
/tabs/home/reservas/:parkId/espacos/:spaceId/formulario       → ReservationFormScreen
/tabs/usuario/minhas-reservas                                 → MyReservationsScreen
/tabs/usuario/minhas-reservas/:id/editar                      → ReservationFormScreen (modo edição)
```

---

## Seção 2 — Modelos de dados

### Backend — entidade `Reservation`

```go
type Reservation struct {
  ID           uint           `json:"id" gorm:"primaryKey"`
  SpaceID      uint           `json:"space_id"`
  UserID       uint           `json:"user_id"`
  CPF          string         `json:"cpf"`
  Data         time.Time      `json:"data"`
  HoraInicio   string         `json:"hora_inicio"`
  HoraFim      string         `json:"hora_fim"`
  Status       string         `json:"status" gorm:"default:'Pendente'"`
  RejectedAt   *time.Time     `json:"rejected_at"`
  WeekOf       time.Time      `json:"week_of"`
  Participants  datatypes.JSON `json:"participants"`
  CreatedAt    time.Time      `json:"created_at"`
  UpdatedAt    time.Time      `json:"updated_at"`
}

// Participant (dentro do JSON)
// { "nome": "string", "cpf": "string" }
```

Estados válidos: `Pendente` | `Aprovada` | `Rejeitada` | `Expirada`

### Backend — entidade `FCMToken`

```go
type FCMToken struct {
  UserID    uint      `json:"user_id" gorm:"primaryKey"`
  Token     string    `json:"token"`
  Platform  string    `json:"platform"` // "android" | "ios"
  UpdatedAt time.Time `json:"updated_at"`
}
```

### Flutter — model `Reservation`

```dart
class Reservation {
  final int id;
  final int spaceId;
  final String spaceName;
  final String parkName;
  final String data;
  final String horaInicio;
  final String horaFim;
  final String status;
  final DateTime? rejectedAt;
  final List<Participant> participants;
}

class Participant {
  final String nome;
  final String cpf;
}
```

---

## Seção 3 — Endpoints

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| `POST` | `/reservations` | User | Cria reserva |
| `PUT` | `/reservations/:id` | User | Edita e reenvia reserva rejeitada |
| `GET` | `/me/reservations` | User | Lista reservas do usuário |
| `GET` | `/reservations/:id` | User | Detalhe de uma reserva |
| `POST` | `/me/fcm-token` | User | Salva/atualiza token FCM |
| `GET` | `/admin/reservations` | Admin | Lista todas com filtros |
| `PUT` | `/admin/reservations/:id` | Admin | Aprova ou rejeita |

### Validações — `POST /reservations`

1. `data` pertence à semana atual (dom–sáb com reset domingo às 6h) → senão `400`
2. Usuário tem CPF cadastrado → senão `400`
3. Usuário já tem reserva com status `Pendente` ou `Aprovada` → `409 "Você já tem uma reserva ativa"`
4. Slot já ocupado (mesmo space_id + data + hora_inicio) → `409 "Horário indisponível"`
5. Salva com `status = "Pendente"`, `week_of = domingo da semana atual`, `hora_fim = hora_inicio + 2h`

### Validações — `PUT /reservations/:id` (reenvio)

1. Reserva pertence ao usuário → senão `403`
2. `status = "Rejeitada"` → senão `403`
3. `rejected_at + 2h > agora` → senão `403 "Prazo de edição encerrado"`
4. Atualiza `participants`, volta `status = "Pendente"`, limpa `rejected_at`

### Validações — `PUT /admin/reservations/:id`

- Aceita `{ "status": "Aprovada" | "Rejeitada" }`
- Se `Rejeitada`: preenche `rejected_at = now()`
- Dispara FCM para o usuário após salvar

---

## Seção 4 — Jobs automáticos (backend)

### Cron 1 — Expirar rejeições (a cada 5 minutos)

```
Busca reservas WHERE status = 'Rejeitada' AND rejected_at < now() - 2h
→ Atualiza status = 'Expirada'
→ Slot reabre automaticamente (sem reserva ativa no horário)
```

### Cron 2 — Reset semanal (domingo às 6h)

```
Arquiva reservas com status IN ('Pendente', 'Aprovada')
WHERE week_of < domingo_atual
→ Atualiza status = 'Expirada'
```

> O backend calcula `semana atual` como: domingo mais recente às 6h00 até o próximo sábado às 23h59. **Edge case:** se o horário atual for domingo antes das 6h, a semana atual ainda é a anterior — o usuário não consegue agendar até as 6h daquele domingo.

---

## Seção 5 — Telas Flutter

### `ParkSelectionScreen` (nova)

- Lista todos os parques que têm ao menos um espaço com `ativo = true`
- Card por parque: foto, nome, quantidade de espaços disponíveis
- Toque → navega para `SpacesCatalogScreen` com `parkId`

### `BookingCalendarScreen` (refatorada)

**Mudanças em relação ao atual:**
- Carrossel de datas: exibe apenas os dias restantes da semana atual (dom–sáb). Ex: se hoje é quarta, mostra qua/qui/sex/sáb
- Remove formulário de submissão da tela
- Botão "Confirmar Agendamento" → vira **"Continuar"**
- Ao tocar "Continuar": navega para `ReservationFormScreen` passando `{spaceId, data, horaInicio, horaFim}`
- Remove checkbox de termos (vai para o formulário)

### `ReservationFormScreen` (nova)

Tela em scroll com 4 seções:

**1. Resumo (somente leitura)**
```
Espaço: [nome do espaço] — [nome do parque]
Data: [dia da semana], [dd mmm] · [HH:mm] – [HH:mm]
```

**2. Responsável (somente leitura — vem do perfil)**
```
Nome: [nome do usuário]    CPF: [cpf do usuário]
```

**3. Participantes (dinâmico)**
- Botão "+ Adicionar participante" → expande campos Nome + CPF inline
- CPF com máscara `000.000.000-00` e validação de formato
- Ícone × para remover participante
- Máximo: `capacidade_max do espaço - 1` (responsável já conta)
- Mínimo: 0 participantes adicionais (pode ser só o responsável)

**4. Termos de uso + envio**
- Box scrollável com termos do espaço (mesmo componente atual)
- Checkbox "Li e concordo com os termos de uso"
- Botão "Enviar solicitação" — desabilitado até termos aceitos

**Comportamentos após envio:**
| Resultado | Ação |
|-----------|------|
| Sucesso (201) | Dialog "Solicitação enviada! Aguarde a aprovação do gestor." → volta para Home |
| 409 CPF duplicado | AppToast erro "Você já tem uma reserva ativa" |
| 409 slot ocupado | AppToast erro "Este horário acabou de ser reservado. Escolha outro." → pop para BookingCalendarScreen |
| Erro de rede | AppToast erro "Erro de conexão. Tente novamente." |

**Modo edição (reenvio após rejeição):**
- Mesma tela, dados pré-preenchidos
- Resumo mostra banner vermelho "Reserva recusada — edite e reenvie"
- Contador regressivo visível (tempo restante das 2h)
- Botão vira "Reenviar solicitação" → chama `PUT /reservations/:id`

### `MyReservationsScreen` (nova)

Cards de reservas ordenados por data decrescente. Cada card mostra:
- Nome do espaço + parque
- Data e horário
- N participantes
- Badge de status

| Status | Badge | Ação disponível |
|--------|-------|-----------------|
| Pendente | Âmbar · "Aguardando aprovação" | — |
| Aprovada | Verde · "Confirmada" | — |
| Rejeitada (dentro de 2h) | Vermelho · contador regressivo | Botão "Editar e reenviar" |
| Rejeitada (2h expiradas) / Expirada | Cinza · "Expirada" | — |

Toque no card → expande detalhes completos com lista de participantes (nome + CPF).

---

## Seção 6 — Push Notifications (FCM)

### Configuração (do zero)

- Adicionar `firebase_messaging` ao `pubspec.yaml`
- Configurar `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)
- Solicitar permissão ao usuário no primeiro login
- Salvar token via `POST /me/fcm-token` após login e toda vez que o token for atualizado

### Disparo (backend — via Firebase Admin SDK ou HTTP v1 API)

| Evento | Título | Corpo | Deep link |
|--------|--------|-------|-----------|
| Aprovação | "Reserva confirmada! ✓" | "Sua reserva em [espaço] no dia [data] foi aprovada." | `/tabs/usuario/minhas-reservas` |
| Rejeição | "Reserva recusada" | "Você tem 2 horas para corrigir e reenviar sua solicitação." | `/tabs/usuario/minhas-reservas/:id/editar` |

### Handling no Flutter

- **Background/terminated:** `FirebaseMessaging.onMessageOpenedApp` → navega para deep link
- **Foreground:** `FirebaseMessaging.onMessage` → exibe `AppToast` com a mensagem

---

## Seção 7 — Painel Admin (React)

### Nova página `ReservationsManagement`

Tabela com colunas: Usuário, CPF, Parque, Espaço, Data/Hora, Participantes, Status, Ações

**Botões contextuais por status:**

| Status | Botões |
|--------|--------|
| Pendente | Aprovar (verde) + Rejeitar (vermelho) |
| Aprovada | Cancelar (cinza) |
| Rejeitada / Expirada | — (somente leitura) |

- Coluna "Participantes" exibe "N pessoas" — toque abre modal com lista nome + CPF
- Filtros: por status, por parque, por data
- Pendentes aparecem primeiro por padrão
- Ações chamam `PUT /admin/reservations/:id` com invalidação da query `['reservations']`

---

## Arquivos a modificar/criar

### Backend (`PARQUE-BACK`)
- `internal/domain/entities/collections.go` — structs `Reservation` e `FCMToken`
- `internal/domain/repositories/reservation_repository.go` — interface
- `internal/application/usecases/reservation_usecase.go` — regras de negócio + validações
- `internal/infrastructure/persistence/mysql_reservation_repository.go` — implementação
- `internal/infrastructure/http/handlers/reservation_handler.go` — handlers dos endpoints
- `internal/infrastructure/http/handlers/fcm_handler.go` — handler do token FCM
- `cmd/api/main.go` — registrar rotas + inicializar crons
- `internal/infrastructure/jobs/expiry_job.go` — cron de expiração de rejeições
- `internal/infrastructure/jobs/weekly_reset_job.go` — cron de reset semanal
- `internal/infrastructure/notifications/fcm_service.go` — envio de push via Firebase

### Flutter App (`PARQUE`)
- `pubspec.yaml` — adicionar `firebase_messaging`, `firebase_core`
- `lib/data/models/reservation.dart` — models `Reservation` e `Participant`
- `lib/data/repositories/reservation_repository.dart` — interface
- `lib/data/repositories/go_reservation_repository.dart` — implementação HTTP
- `lib/services/notification_service.dart` — setup FCM, token, deep link handler
- `lib/screens/reservations/park_selection_screen.dart` — nova tela
- `lib/screens/reservations/spaces_catalog_screen.dart` — aceitar `parkId` como parâmetro obrigatório e filtrar espaços por parque
- `lib/screens/reservations/space_detail_screen.dart` — ajustar rota para incluir `parkId`
- `lib/screens/reservations/booking_calendar_screen.dart` — refatorar datas + remover form
- `lib/screens/reservations/reservation_form_screen.dart` — nova tela
- `lib/screens/reservations/my_reservations_screen.dart` — nova tela
- `lib/routes/app_router.dart` — adicionar novas rotas
- `lib/screens/home_screen.dart` — guard de auth no botão Reservas
- `lib/screens/user/user_screen.dart` — link "Minhas reservas" (já existe no UI)

### Painel Admin (`PAINEL-PARK`)
- `src/pages/ReservationsManagement/ReservationsManagement.tsx` — nova página completa
- `src/App.tsx` (ou router) — registrar rota `/reservas`
- `src/components/Sidebar` — adicionar item "Reservas"
