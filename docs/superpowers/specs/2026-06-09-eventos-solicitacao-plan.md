# Plano de Implementação — Sistema de Eventos

**Spec:** `2026-06-09-eventos-solicitacao-design.md`  
**Pré-requisito:** RBAC gestores implementado (`2026-06-09-rbac-gestores-plan.md`)  
**Projetos:** Backend Go → Admin React → Flutter app

---

## Fase 1 — Backend Go (PARQUE-BACK)

### 1.1 Novas entidades
**Novos arquivos em** `internal/domain/entities/`

**`event_request.go`**
```go
type EventRequest struct {
    ID                 uint      `gorm:"primaryKey"`
    UserID             uint      `gorm:"index;not null"`
    User               *User     `gorm:"foreignKey:UserID"`
    ParkID             uint      `gorm:"index;not null"`
    Park               *Park     `gorm:"foreignKey:ParkID"`
    SpaceID            uint      `gorm:"index;not null"`
    Space              *Space    `gorm:"foreignKey:SpaceID"`
    DataEvento         time.Time `gorm:"not null"`
    HoraInicio         string    `gorm:"size:5;not null"`
    HoraFim            string    `gorm:"size:5;not null"`
    TipoAtividade      string    `gorm:"size:50;not null"`
    QuantidadePessoas  int       `gorm:"not null"`
    Objetivo           string    `gorm:"type:text;not null"`
    NomeResponsavel    string    `gorm:"size:120;not null"`
    ContatoResponsavel string    `gorm:"size:20;not null"`
    ApoioBPA           bool      `gorm:"default:false"`
    Status             string    `gorm:"size:20;default:'Pendente';index"`
    MotivoRejeicao     string    `gorm:"type:text"`
    ObservacoesAdmin   string    `gorm:"type:text"`
    CreatedAt          time.Time
    UpdatedAt          time.Time
}
```

**`park_event_rule.go`**
```go
type ParkEventRule struct {
    ID            uint   `gorm:"primaryKey"`
    ParkID        uint   `gorm:"index;not null"`
    TipoAtividade string `gorm:"size:50"`
    ThresholdMin  int    `gorm:"default:0"`
    ThresholdMax  int    `gorm:"default:0"`
    Texto         string `gorm:"type:text;not null"`
    Obrigatoria   bool   `gorm:"default:false"`
    Ordem         int    `gorm:"default:0"`
}
```

**`park_activity_type.go`**
```go
type ParkActivityType struct {
    ID     uint   `gorm:"primaryKey"`
    ParkID uint   `gorm:"index;not null"`
    Nome   string `gorm:"size:50;not null"`
    Ordem  int    `gorm:"default:0"`
}
```

**`space.go`** — novo campo
```go
PermiteEvento bool `json:"permite_evento" gorm:"default:false"`
```

### 1.2 AutoMigrate — main.go
Adicionar ao `db.AutoMigrate(...)`:
```go
&entities.EventRequest{},
&entities.ParkEventRule{},
&entities.ParkActivityType{},
```

### 1.3 Repositórios
**Novos arquivos em** `internal/infrastructure/persistence/`

- `mysql_event_request_repository.go` — Create, ListByUserID, ListAdmin (com filtro park_id), GetByID, UpdateStatus
- `mysql_park_event_rule_repository.go` — ListByParkID, Create, Update, Delete
- `mysql_park_activity_type_repository.go` — ListByParkID, Create, Update, Delete

### 1.4 Use Cases
**Novo arquivo:** `internal/application/usecases/event_request_usecase.go`

Métodos:
- `Create(ctx, userID, input)` — valida 15 dias, valida space.permite_evento, cria registro
- `Cancel(ctx, userID, id)` — só status Pendente, só o próprio usuário
- `ListMine(ctx, userID)` — lista do usuário logado
- `AdminList(ctx, parkID *uint, filters)` — lista admin com filtro opcional por park
- `AdminUpdateStatus(ctx, adminID, id, status, motivo)` — aprova/rejeita/cancela + dispara FCM

Validação de 15 dias (em `Create`):
```go
if input.DataEvento.Before(time.Now().AddDate(0, 0, 15)) {
    return nil, errors.New("solicitações devem ser feitas com mínimo 15 dias de antecedência")
}
```

### 1.5 Handlers HTTP
**Novo arquivo:** `internal/infrastructure/http/handlers/event_request_handler.go`

### 1.6 Rotas — main.go
```go
// Público / usuário autenticado
api.GET("/parks/:id/activity-types", parkHandler.ListActivityTypes)
api.GET("/event-requests/rules", eventRuleHandler.ListByPark) // ?park_id=X
eventReqs := api.Group("/event-requests")
eventReqs.Use(middleware.RequireUserAuth(userAuthUseCase))
{
    eventReqs.POST("", eventHandler.Create)
    eventReqs.POST("/:id/cancel", eventHandler.Cancel)
}
api.GET("/me/event-requests",
    middleware.RequireUserAuth(userAuthUseCase), eventHandler.ListMine)

// Admin
admin.GET("/event-requests/", eventHandler.AdminList)
admin.PUT("/event-requests/:id", eventHandler.AdminUpdateStatus)
adminParks.GET("/:id/event-rules", eventRuleHandler.List)
adminParks.POST("/:id/event-rules", eventRuleHandler.Create)
adminParks.PUT("/:id/event-rules/:ruleId", eventRuleHandler.Update)
adminParks.DELETE("/:id/event-rules/:ruleId", eventRuleHandler.Delete)
adminParks.GET("/:id/activity-types", activityTypeHandler.List)
adminParks.POST("/:id/activity-types", activityTypeHandler.Create)
adminParks.PUT("/:id/activity-types/:typeId", activityTypeHandler.Update)
adminParks.DELETE("/:id/activity-types/:typeId", activityTypeHandler.Delete)
```

### 1.7 Push Notifications
**Arquivo:** `internal/application/usecases/event_request_usecase.go`

Em `AdminUpdateStatus`, disparar FCM para o usuário nos mesmos eventos das reservas:
- `Aprovada` → "Seu evento foi aprovado!"
- `Rejeitada` → "Seu evento foi rejeitado. Motivo: {motivo}"
- `Cancelada` → "Seu evento foi cancelado pelo gestor"

---

## Fase 2 — Admin React (PAINEL-PARK)

### 2.1 Nova página: Eventos (`/eventos-admin`)
**Novo arquivo:** `src/pages/EventRequestsManagement/EventRequestsManagement.tsx`

Tabela: Solicitante, Parque/Local, Data e Horário, Pessoas, Tipo, Status, Ações.

Modal de detalhes:
- Todos os campos da solicitação
- Flags automáticas geradas (ex: "⚠️ 350 pessoas — verificar regra de ambulância")
- Botões: Aprovar / Rejeitar (motivo obrigatório) / Cancelar

### 2.2 Seção Regras de Eventos — dentro da página do parque
**Arquivo:** `src/pages/ParksManagement/ParksManagement.tsx` (ou nova sub-página)

Interface de listagem + CRUD inline de `ParkEventRule`:
- Tipo de atividade, threshold mín/máx, texto, obrigatória

### 2.3 Seção Tipos de Atividade — dentro da página do parque
Mesma estrutura que regras — lista + CRUD de `ParkActivityType`.

### 2.4 Espaços — toggle `permite_evento`
**Arquivo:** `src/pages/MapPointsManagement/MapPointFormPage.tsx`
- Adicionar toggle "Permite solicitação de evento" (`permite_evento`)

### 2.5 Sidebar
Adicionar item "Eventos" (solicitações) na sidebar, visível para super_admin e gestor.

---

## Fase 3 — Flutter App

### 3.1 Novos modelos
**Novos arquivos em** `lib/data/models/`
- `event_request.dart` — EventRequest com fromJson/toJson
- `park_event_rule.dart` — ParkEventRule com fromJson
- `park_activity_type.dart` — ParkActivityType com fromJson

### 3.2 Repositório
**Novo arquivo:** `lib/data/repositories/go_event_repository.dart`
- `fetchRules(int parkId)` → `GET /event-requests/rules?park_id=X`
- `fetchActivityTypes(int parkId)` → `GET /parks/:id/activity-types`
- `create(Map body)` → `POST /event-requests`
- `cancel(int id)` → `POST /event-requests/:id/cancel`
- `fetchMine()` → `GET /me/event-requests`

### 3.3 Modificar EventosListScreen
**Arquivo:** `lib/screens/eventos_list_screen.dart`
- Adicionar `TabBar` com abas "Eventos" e "Meus Pedidos"
- Aba "Meus Pedidos": `MyEventRequestsTab` com guard de login (`LoginRequired`)

### 3.4 Novas telas (fluxo de 5 passos)
**Novos arquivos em** `lib/screens/events/`

- `event_park_selection_screen.dart` — Passo 1: selecionar parque
- `event_space_selection_screen.dart` — Passo 2: selecionar espaço (filtra `permite_evento=true`)
- `event_datetime_screen.dart` — Passo 3: data (bloqueia < 15 dias) + hora início/fim
- `event_form_screen.dart` — Passo 4: tipo, quantidade, objetivo, responsável, BPA
- `event_rules_screen.dart` — Passo 5: exibir regras filtradas + checkboxes + submit

### 3.5 Tela "Meus Pedidos"
**Novo arquivo:** `lib/screens/events/my_event_requests_screen.dart`

Igual à `MyReservationsScreen`: tabs Ativos / Histórico, cards `#F9FAE8`, paginação.

### 3.6 Novas rotas — app_router.dart
```dart
GoRoute(
  path: 'eventos/solicitar',
  name: 'home_eventos_solicitar',
  builder: (_, __) => const EventParkSelectionScreen(),
),
GoRoute(
  path: 'eventos/solicitar/:parkId',
  builder: (_, state) => EventSpaceSelectionScreen(
    parkId: int.parse(state.pathParameters['parkId']!)),
),
GoRoute(
  path: 'eventos/solicitar/:parkId/espaco/:spaceId',
  builder: (_, state) => EventDateTimeScreen(...),
),
GoRoute(
  path: 'eventos/solicitar/:parkId/espaco/:spaceId/detalhes',
  builder: (_, state) => EventFormScreen(...),
),
```

---

## Ordem de execução

1. **Backend:** 1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 → 1.7 → `go build ./...`
2. **Admin:** 2.1 → 2.2 → 2.3 → 2.4 → 2.5
3. **Flutter:** 3.1 → 3.2 → 3.3 → 3.4 → 3.5 → 3.6 → `flutter analyze`
4. **Testar fluxo completo:** criar solicitação no app → aparecer no admin → aprovar → push chegar
