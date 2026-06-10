# Sistema de Eventos — Solicitação pelo App

**Data:** 2026-06-09  
**Status:** Aprovado — aguardando implementação  
**Projetos afetados:** Backend Go (PARQUE-BACK), Admin React (PAINEL-PARK), Flutter app

---

## Contexto

Cada parque possui um fluxo formal de solicitação de eventos baseado em fluxogramas oficiais da SEGOV/MA (Rangedor, Lagoa da Jansen, APA do Itapiracó). O cidadão precisa solicitar autorização com antecedência mínima de 15 dias, informando local, horário, quantidade de pessoas, objetivo e responsável.

---

## Regras Universais (aplicam a todos os parques)

- **Antecedência mínima de 15 dias** — enforçada no backend (HTTP 400) e no app (datas bloqueadas no calendário)
- **Responsável pelo evento garante limpeza** — regra obrigatória exibida para todos
- Cada parque configura suas próprias regras adicionais via admin

---

## Entidades Backend

### `EventRequest`

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
    HoraInicio         string    `gorm:"size:5;not null"`   // "08:00"
    HoraFim            string    `gorm:"size:5;not null"`   // "17:00"
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

**Status possíveis:** `Pendente` → `Aprovada` | `Rejeitada` | `Cancelada`

### `ParkActivityType`

```go
type ParkActivityType struct {
    ID     uint   `gorm:"primaryKey"`
    ParkID uint   `gorm:"index;not null"`
    Nome   string `gorm:"size:50;not null"` // "Corrida", "Trilha", "Piquenique"...
    Ordem  int    `gorm:"default:0"`
}
```

Endpoint adicional: `GET /parks/:id/activity-types` — público, usado pelo app no Passo 4.  
Admin: `GET/POST/PUT/DELETE /admin/parks/:id/activity-types`

### `ParkEventRule`

```go
type ParkEventRule struct {
    ID            uint   `gorm:"primaryKey"`
    ParkID        uint   `gorm:"index;not null"`
    TipoAtividade string `gorm:"size:50"`    // "" = aplica a todas as atividades
    ThresholdMin  int    `gorm:"default:0"`  // qtd mínima de pessoas (0 = sem mínimo)
    ThresholdMax  int    `gorm:"default:0"`  // qtd máxima de pessoas (0 = sem máximo)
    Texto         string `gorm:"type:text;not null"` // exibido ao usuário
    Obrigatoria   bool   `gorm:"default:false"` // sempre exibida
    Ordem         int    `gorm:"default:0"`     // ordenação na exibição
}
```

### `Space` — novo campo

```go
PermiteEvento bool `json:"permite_evento" gorm:"default:false"`
```

---

## Endpoints Backend

### Usuário autenticado

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/event-requests/rules?park_id=X` | Regras do parque (app filtra por seleção do usuário) |
| `POST` | `/event-requests` | Criar solicitação — valida 15 dias + space.permite_evento |
| `GET` | `/me/event-requests` | Listar meus pedidos |
| `POST` | `/event-requests/:id/cancel` | Cancelar (só status Pendente) |

**Validações no POST /event-requests:**
- `data_evento < hoje + 15 dias` → 400 `"Solicitações devem ser feitas com mínimo 15 dias de antecedência"`
- `space.permite_evento == false` → 400
- `space.park_id != park_id` do body → 400

### Admin (filtrado por park_id se gestor — ver spec RBAC)

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/admin/event-requests` | Listar solicitações (com filtros: status, parque, data) |
| `PUT` | `/admin/event-requests/:id` | Aprovar / Rejeitar / Cancelar |
| `GET` | `/admin/parks/:id/event-rules` | Listar regras do parque |
| `POST` | `/admin/parks/:id/event-rules` | Criar regra |
| `PUT` | `/admin/parks/:id/event-rules/:ruleId` | Editar regra |
| `DELETE` | `/admin/parks/:id/event-rules/:ruleId` | Remover regra |

---

## Flutter App

### Modificação na `EventosListScreen`

Adicionar `TabBar` com duas abas:
1. **"Eventos"** — conteúdo existente (lista de eventos do parque, sem mudança)
2. **"Meus Pedidos"** — lista de solicitações do usuário + botão "Solicitar Evento"

Aba "Meus Pedidos" só aparece se usuário estiver logado. Se não logado, exibe `LoginRequired` widget.

### Fluxo de solicitação — 5 passos

Mesmo padrão visual das reservas: AppBar verde, cards `#F9FAE8`, fonte Poppins.

#### Passo 1 — Selecionar Parque
Rota: `/tabs/home/eventos/solicitar`  
Lista de parques com espaços marcados como `permite_evento = true`.

#### Passo 2 — Selecionar Local
Rota: `/tabs/home/eventos/solicitar/:parkId`  
Espaços do parque filtrados por `permite_evento = true`. Card com nome, foto, capacidade máxima.

#### Passo 3 — Data e Horário
Rota: `/tabs/home/eventos/solicitar/:parkId/espaco/:spaceId`  
- Calendário: datas nos próximos 15 dias cinzas e não clicáveis
- Banner fixo: "Solicitações devem ser feitas com mínimo 15 dias de antecedência"
- Após selecionar data: campos hora_inicio e hora_fim (time picker)

#### Passo 4 — Detalhes do Evento
Rota: `/tabs/home/eventos/solicitar/:parkId/espaco/:spaceId/detalhes`
- Tipo de atividade (chips/select baseado nos tipos configurados no parque)
- Quantidade de pessoas (campo numérico)
- Objetivo do evento (textarea)
- Nome do responsável (pré-preenchido com nome do usuário)
- Contato do responsável (pré-preenchido com telefone do cadastro)
- Apoio BPA (toggle Sim/Não)

#### Passo 5 — Regras + Confirmação
Regras carregadas de `GET /event-requests/rules?park_id=X` e filtradas no cliente:
- Regras obrigatórias: sempre exibidas
- Regras por threshold: exibidas se `quantidade_pessoas >= threshold_min`
- Regras por atividade: exibidas se `tipo_atividade == rule.tipo_atividade`

Cada regra = item com checkbox. Botão "Enviar Solicitação" desabilitado até todos marcados.

### Tela "Meus Pedidos"

Duas abas internas:
- **"Ativos"** — status Pendente + Aprovada
- **"Histórico"** — status Rejeitada + Cancelada

**Card — Pendente:**
```
[ Em análise ]                          🗑️ (cancela)
[Nome do Espaço] — [Nome do Parque]
[dia da semana], [data] · [HH:MM] às [HH:MM]
[X] pessoas · [Tipo de Atividade]
```

**Card — Aprovada:**
```
[ Confirmado ✓ ]
[Nome do Espaço] — [Nome do Parque]
[dia da semana], [data] · [HH:MM] às [HH:MM]
[X] pessoas · [Tipo de Atividade]
```

**Card — Rejeitada:**
```
[ Rejeitado ]
[Nome do Espaço] — [Nome do Parque]
[data]
─────────────────────────────────────
ⓘ Motivo: [texto do motivo]
```

### Push Notifications

Enviadas pelo backend nos mesmos eventos das reservas:
- Solicitação aprovada
- Solicitação rejeitada (com motivo)
- Solicitação cancelada pelo gestor

### Novos modelos Flutter

```dart
// lib/data/models/event_request.dart
class EventRequest {
  final int id;
  final int parkId;
  final String parkName;
  final int spaceId;
  final String spaceName;
  final String dataEvento;       // "YYYY-MM-DD"
  final String horaInicio;
  final String horaFim;
  final String tipoAtividade;
  final int quantidadePessoas;
  final String objetivo;
  final String nomeResponsavel;
  final String contatoResponsavel;
  final bool apoioBPA;
  final String status;
  final String motivoRejeicao;
}

// lib/data/models/park_event_rule.dart
class ParkEventRule {
  final int id;
  final int parkId;
  final String tipoAtividade;  // "" = todas
  final int thresholdMin;       // 0 = sem mínimo
  final int thresholdMax;       // 0 = sem máximo
  final String texto;
  final bool obrigatoria;
  final int ordem;
}
```

### Novas rotas (GoRouter)

```
/tabs/home/eventos                                                    → EventosListScreen (TabBar)
/tabs/home/eventos/solicitar                                          → ParkSelectionScreen (eventos)
/tabs/home/eventos/solicitar/:parkId                                  → EventSpaceScreen
/tabs/home/eventos/solicitar/:parkId/espaco/:spaceId                  → EventDateTimeScreen
/tabs/home/eventos/solicitar/:parkId/espaco/:spaceId/detalhes         → EventFormScreen
/tabs/home/eventos/meus-pedidos/:id                                   → EventRequestDetailScreen
```

---

## Admin Panel React

### Nova página "Eventos"

Na sidebar (visível para super_admin e gestor do parque).

**Tabela com colunas:** Solicitante, Parque / Local, Data e Horário, Pessoas, Tipo, Status, Ações.

**Filtros:** parque (super_admin), status, data, tipo de atividade.

**Modal de detalhes:**
- Todos os campos preenchidos pelo usuário
- Flags automáticas geradas pelo sistema baseadas nas regras:
  ```
  ⚠️ 350 pessoas — ambulância obrigatória (regra do parque)
  ⚠️ Apoio BPA solicitado: Sim
  ```
- Botões: Aprovar / Rejeitar (motivo obrigatório) / Cancelar (pós-aprovação)

### Regras de Eventos por Parque

Sub-seção dentro da página de edição do parque (ou dentro de Espaços), visível para super_admin e gestor.

Interface de listagem + formulário inline para criar/editar regras:
- Tipo de atividade (texto livre ou "Todas")
- Quantidade mínima de pessoas (0 = sem mínimo)
- Quantidade máxima de pessoas (0 = sem máximo)
- Texto da regra (o que aparece para o usuário no app)
- Obrigatória (sempre exibida)

---

## Notas de Implementação

- **Regras pré-cadastradas:** ao criar um novo parque, o sistema não gera regras automaticamente. O super_admin deve cadastrá-las com base nos fluxogramas de cada parque.
- **Tipos de atividade por parque:** entidade própria `ParkActivityType` (park_id + nome, ex: "Corrida", "Trilha", "Piquenique"). O admin cadastra os tipos disponíveis para cada parque; o app lista os tipos do parque selecionado via `GET /parks/:id/activity-types`. As regras referenciam o campo `tipo_atividade` por nome (string), compatível com os tipos cadastrados.
- **Conflito de datas:** o backend não bloqueia automaticamente conflitos de data/espaço em eventos (diferente das reservas). O gestor analisa manualmente — a solicitação é formal, não um slot automático.
