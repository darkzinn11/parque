# Push Notifications — Estratégia Completa

**Data:** 2026-06-03  
**Status:** spec aprovada — implementação pendente  
**Projetos afetados:** Flutter (PARQUE), Backend Go (PARQUE-BACK), Admin React (PAINEL-PARK)

---

## Contexto

O `FCMService` já existe no backend com graceful degradation. Os gatilhos de Aprovada e Rejeitada já estão implementados. Esta spec completa a estratégia cobrindo o gatilho faltante (cancelamento pelo gestor) e o sistema de broadcast para anúncios de eventos.

**Pré-requisito humano:** criar projeto Firebase e configurar credenciais (ver pendências no CLAUDE.md).

---

## 1. Gatilhos automáticos de reserva

### O que já existe
- `StatusAprovada` → push para o usuário ✅
- `StatusRejeitada` → push com motivo + deeplink para editar ✅

### O que falta

**Cancelada pelo gestor → push para o usuário**

Localização: `reservation_usecase.go` → `notifyStatusChange` → adicionar `case entities.StatusCancelada`.

```
Título: "Reserva cancelada"
Corpo:  "Sua reserva em {espaço} no dia {data} foi cancelada pelo parque."
Data:   type=reservation_status, status=Cancelada, deeplink=/tabs/usuario/minhas-reservas
```

### Decisões explícitas

| Status | Push | Motivo |
|---|---|---|
| Aprovada | ✅ | Usuário precisa saber para comparecer |
| Rejeitada | ✅ | Usuário precisa agir em até 2h |
| Cancelada (gestor) | ✅ | Usuário precisa saber que não pode mais comparecer |
| Expirada | ✗ | Cron roda em background/madrugada — notificação seria ruído |
| Cancelada (usuário) | ✗ | Usuário foi quem cancelou — notificar seria desnecessário |

---

## 2. Broadcast de eventos via FCM Topics

### Estratégia: FCM Topics

O app assina o tópico `"parque-todos"` no boot. O backend envia uma única chamada à API do Firebase para `/topics/parque-todos`. O Firebase faz o fan-out para todos os dispositivos inscritos.

**Por que Topics e não multicast por tokens:**
- Uma chamada independente do volume de usuários
- Firebase gerencia tokens expirados/inválidos automaticamente
- Extensível: novos tópicos por parque ou interesse no futuro sem mudança de arquitetura

### Flutter

Após inicializar o Firebase no `main.dart`, assinar o tópico:

```dart
await FirebaseMessaging.instance.subscribeToTopic('parque-todos');
```

Não requer login. Qualquer instalação do app que abrir uma vez estará inscrita.

### Backend Go

**Nova interface `Broadcaster`** (separada de `Notifier` para não acoplar reservas):

```go
type Broadcaster interface {
    SendToAll(ctx context.Context, title, body string, data map[string]string) error
}
```

**`FCMService` implementa `Broadcaster`:**

```go
func (s *FCMService) SendToAll(ctx, title, body string, data map[string]string) error {
    msg := &messaging.Message{
        Topic: "parque-todos",
        Notification: &messaging.Notification{Title: title, Body: body},
        Data: data,
    }
    _, err := s.client.Send(ctx, msg)
    return err
}
```

**Novo use case `NotificationUseCase`:**

```go
type NotificationUseCase struct {
    broadcaster Broadcaster
}

func (uc *NotificationUseCase) Broadcast(ctx, title, body string) error {
    data := map[string]string{"type": "evento_anuncio"}
    return uc.broadcaster.SendToAll(ctx, title, body, data)
}
```

**Novo endpoint:**

```
POST /admin/notifications/broadcast
Auth: admin JWT
Body: { "title": string, "body": string }
Response 200: { "message": "enviado" }
Response 400: title ou body vazio
Response 500: falha no FCM
```

### Admin Panel React

Nova entrada no sidebar: **"Notificações"** (ícone de sino).

Página com formulário único:

```
[ Título da notificação          ]
[ Mensagem para os usuários      ]
[ Mensagem para os usuários      ]
                    [ Enviar para todos ]
```

- Botão desabilitado enquanto título ou mensagem estiver vazio
- Feedback inline: sucesso (verde) ou erro (vermelho) com mensagem do servidor
- Sem histórico de envios nesta versão (YAGNI)

---

## 3. Evolução futura (fora do escopo desta spec)

- Quando o sistema de reserva de eventos for construído, os gatilhos de status (Aprovada/Rejeitada/Cancelada) seguem o mesmo padrão do `ReservationUseCase` existente.
- O botão "Notificar usuários" pode ser adicionado na página de edição de evento no painel, chamando o mesmo endpoint `/admin/notifications/broadcast` — a infraestrutura já estará pronta.
- Tópicos segmentados por parque (`parque-{id}`) podem ser adicionados sem mudança de arquitetura.
