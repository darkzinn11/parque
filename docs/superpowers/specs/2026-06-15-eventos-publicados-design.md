# Eventos Publicados — Design Spec
**Data:** 2026-06-15

## Visão Geral

Sistema para gestores publicarem eventos institucionais no app. O fluxo é separado do sistema de solicitação de evento: o gestor cria o evento publicado no painel admin (opcionalmente vinculando a uma solicitação aprovada), o evento aparece na tela "Eventos" do app, e usuários podem marcar "Tenho interesse" para receber notificações FCM 3 dias antes e no dia do evento.

## Entidades

### Evento (já existe — adicionar campos)
```go
type Evento struct {
    ID             uint      `json:"id" gorm:"primaryKey"`
    Titulo         string    `json:"titulo"`
    CapaURL        string    `json:"capa_url"`
    BannerURL      string    `json:"banner_url"`
    DataInicio     string    `json:"data_inicio"`
    DataFim        string    `json:"data_fim"`
    Local          string    `json:"local"`
    Horario        string    `json:"horario"`
    Conteudo       string    `json:"conteudo" gorm:"type:text"`
    EventRequestID *uint     `json:"event_request_id" gorm:"index"` // NOVO
    CreatedAt      time.Time `json:"created_at"`
    UpdatedAt      time.Time `json:"updated_at"`
}
```

### EventInterest (nova entidade)
```go
type EventInterest struct {
    ID        uint      `json:"id" gorm:"primaryKey"`
    UserID    uint      `json:"user_id" gorm:"not null;uniqueIndex:idx_user_evento"`
    EventoID  uint      `json:"evento_id" gorm:"not null;uniqueIndex:idx_user_evento"`
    CreatedAt time.Time `json:"created_at"`
}
```

## Contratos de API

### Endpoints Públicos
```
GET  /eventos              → lista todos (ORDER BY data_inicio ASC)
GET  /eventos/:id          → detalhe + campo meu_interesse: bool (se logado)
POST /eventos/:id/interesse   → registra interesse (auth obrigatório)
DELETE /eventos/:id/interesse → remove interesse (auth obrigatório)
```

### Endpoints Admin
```
GET    /admin/eventos           → lista todos os eventos
POST   /admin/eventos           → criar evento
PUT    /admin/eventos/:id        → editar evento
DELETE /admin/eventos/:id        → deletar evento
POST   /admin/eventos/upload    → upload de banner (multipart, retorna URL)
```

## Flutter

### AppEvent — campos adicionados
```dart
final String? horario;
final bool? meuInteresse;
```

### GoEventRepository — mudanças
- `fetchAll()`: GET /eventos (remover fallback /atividades)
- `fetchById(id)`: GET /eventos/:id
- `toggleInteresse(id, bool)`: POST/DELETE /eventos/:id/interesse

### EventoDetailScreen — adições
- Linha de horário (`Icons.schedule_outlined`)
- Botão "Tenho interesse" / "Interesse registrado" no final
- Estado gerenciado localmente a partir de `ev.meuInteresse`
- Requer login para registrar interesse

### EventosListScreen
- Sem mudanças estruturais — só confirmar endpoint correto

## Admin Panel (PAINEL-PARK)

### Nova página: EventosPublicados
- Tabela: título, data início, local, horário, ações
- Modal criar/editar:
  - Título, local, horário, data início, data fim (opcional)
  - Descrição (textarea)
  - Upload de banner (POST /admin/eventos/upload)
  - Dropdown "Solicitação vinculada" (GET /admin/event-requests?status=Aprovada)
    - Ao selecionar: preenche título, local, data automaticamente
- Confirmação antes de deletar

### Sidebar
- Adicionar "Eventos Publicados" ao lado de "Solicitações de Evento"

## Notificações FCM

### Job (executa 1×/dia)
- Busca eventos com `data_inicio = hoje` → envia "🎉 [titulo] é hoje!"
- Busca eventos com `data_inicio = hoje+3` → envia "🎉 [titulo] acontece em 3 dias!"
- Para cada evento, busca todos os `EventInterest` e dispara FCM individual
- Deeplink no payload: `/eventos/:id`
- Reutiliza `fcmService` já existente no projeto

## Decisões de Design

1. **Aprovação ≠ Publicação**: o gestor aprova a solicitação em fluxo separado. A publicação é um ato editorial independente.
2. **Vínculo opcional**: `event_request_id` é nullable — gestor pode criar eventos do zero (shows, eventos institucionais) sem nenhuma solicitação de origem.
3. **Draft mode**: não há status draft/publicado no `Evento` — tudo que está na tabela é público. O gestor simplesmente não cria enquanto não tiver o banner.
4. **Interesse sem inscrição formal**: `EventInterest` apenas registra para notificações. Não há limite de vagas ou confirmação de presença.
